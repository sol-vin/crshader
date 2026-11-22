require "lapis"
require "../compiler"
require "../../crshader_resource"
require "../../highlighter"

module CrShader
  include Godot

  # =============================================================================
  # CrShaderTabEditor - Native .crshader Editor Pane inside Godot's Shader Editor
  # =============================================================================
  # Mounted directly inside Godot 4's built-in "Shader Editor" TabContainer slot
  # whenever a `.crshader` resource is opened from the FileSystem dock, Inspector,
  # or the Shader Editor's "CRShader" menu.
  @[Tool]
  node CrShaderTabEditor < VBoxContainer do
    property file_path : String = ""
    property disk_path : String = ""
    property auto_compile : Bool = true
    property split_preview_visible : Bool = true
    property release_strip : Bool = false

    @crshader_res : CrShader::CRShader? = nil
    @source_edit : Godot::CodeEdit? = nil
    @preview_edit : Godot::CodeEdit? = nil
    @preview_box : Godot::VBoxContainer? = nil
    @target_badge : Godot::Label? = nil
    @status_label : Godot::Label? = nil
    @dirty : Bool = false
    @debounce_sec : Float64 = 0.0_f64
    @last_error_line : Int32 = -1
    @suppress_text_signal : Bool = false
    @ui_built : Bool = false

    def _ready : Void
      ensure_ui_built!
      set_process(true)
    end

    def ensure_ui_built! : Void
      return if @ui_built
      @ui_built = true

      call("set_anchors_preset", 15_i64) # PRESET_FULL_RECT
      call("set_h_size_flags", 3_i64)    # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3_i64)    # SIZE_EXPAND_FILL
      call("add_theme_constant_override", "separation", 4_i64)

      # --- Compact Top Toolbar ---
      toolbar = Godot.create(Godot::HBoxContainer)
      if toolbar && !toolbar.pointer.null?
        toolbar.call("add_theme_constant_override", "separation", 8_i64)

        badge = Godot.create(Godot::Label)
        if badge && !badge.pointer.null?
          badge.call("set_text", "🔮 CRShader [Auto]")
          badge.call("add_theme_color_override", "font_color", Color.new(0.58_f32, 0.84_f32, 1.0_f32, 1.0_f32))
          toolbar.call("add_child", badge)
          @target_badge = badge
        end

        compile_btn = Godot.create(Godot::Button)
        if compile_btn && !compile_btn.pointer.null?
          compile_btn.call("set_text", "▶ Compile & Sync")
          compile_btn.call("set_tooltip_text", "Transpile .crshader and sync all declared emit_target outputs to disk")
          compile_btn.connect("pressed") do |_args|
            save_and_sync!
          end
          toolbar.call("add_child", compile_btn)
        end

        save_btn = Godot.create(Godot::Button)
        if save_btn && !save_btn.pointer.null?
          save_btn.call("set_text", "💾 Save")
          save_btn.call("set_tooltip_text", "Save .crshader source and compiled targets (Ctrl+S)")
          save_btn.connect("pressed") do |_args|
            save_and_sync!
          end
          toolbar.call("add_child", save_btn)
        end

        auto_chk = Godot.create(Godot::CheckBox)
        if auto_chk && !auto_chk.pointer.null?
          auto_chk.call("set_text", "Auto-Preview")
          auto_chk.call("set_pressed", @auto_compile)
          auto_chk.connect("toggled") do |args|
            @auto_compile = args.first?.try(&.as_bool) || false
            compile_preview(sync_disk: false) if @auto_compile
          end
          toolbar.call("add_child", auto_chk)
        end

        split_chk = Godot.create(Godot::CheckBox)
        if split_chk && !split_chk.pointer.null?
          split_chk.call("set_text", "Split Preview")
          split_chk.call("set_pressed", @split_preview_visible)
          split_chk.connect("toggled") do |args|
            @split_preview_visible = args.first?.try(&.as_bool) || false
            if pbox = @preview_box
              pbox.call("set_visible", @split_preview_visible) if !pbox.pointer.null?
            end
          end
          toolbar.call("add_child", split_chk)
        end

        trait_opt = Godot.create(Godot::OptionButton)
        if trait_opt && !trait_opt.pointer.null?
          trait_opt.call("add_item", "🧩 Insert Trait...", 0_i64)
          trait_list = Std.trait_names
          trait_list.each_with_index do |tname, idx|
            trait_opt.call("add_item", tname, (idx + 1).to_i64)
          end
          trait_opt.connect("item_selected") do |args|
            idx = (args.first?.try(&.as_i) || 0).to_i32
            if idx > 0 && idx <= trait_list.size
              insert_trait_line(trait_list[idx - 1])
              trait_opt.call("select", 0_i64)
            end
          end
          toolbar.call("add_child", trait_opt)
        end

        status = Godot.create(Godot::Label)
        if status && !status.pointer.null?
          status.call("set_h_size_flags", 3_i64)
          status.call("set_clip_text", true)
          status.call("set_text", "Ready")
          status.call("add_theme_color_override", "font_color", Color.new(0.7_f32, 0.75_f32, 0.8_f32, 1.0_f32))
          toolbar.call("add_child", status)
          @status_label = status
        end

        call("add_child", toolbar)
      end

      # --- Split Source & Live Transpiled Target Panes ---
      split = Godot.create(Godot::HSplitContainer)
      if split && !split.pointer.null?
        split.call("set_h_size_flags", 3_i64)
        split.call("set_v_size_flags", 3_i64)

        src_edit = Godot.create(Godot::CodeEdit)
        if src_edit && !src_edit.pointer.null?
          src_edit.call("set_h_size_flags", 3_i64)
          src_edit.call("set_v_size_flags", 3_i64)
          src_edit.call("set_gutters_draw_line_numbers", true)
          src_edit.call("set_line_folding_enabled", true)
          src_edit.call("set_gutters_draw_fold_gutter", true)
          src_edit.call("set_auto_brace_completion_enabled", true)
          src_edit.call("set_auto_indent_enabled", true)
          src_edit.call("set_indent_use_spaces", true)
          src_edit.call("set_indent_size", 2_i64)
          Highlighter.apply_to_code_edit(src_edit)

          src_edit.connect("text_changed") do |_args|
            unless @suppress_text_signal
              @dirty = true
              @debounce_sec = 0.25_f64
              if res = @crshader_res
                res.crshader_source = get_source_text
              end
            end
          end

          src_edit.connect("gui_input") do |args|
            if ev_var = args.first?
              ev_obj = ev_var.raw.as?(Godot::Object)
              if ev_obj && !ev_obj.pointer.null? && (ev_obj.get_class rescue "") == "InputEventKey"
                pressed = ev_obj.call_bool("is_pressed") rescue false
                echo = ev_obj.call_bool("is_echo") rescue false
                ctrl = ev_obj.call_bool("is_ctrl_pressed") rescue false
                keycode = ev_obj.call_i64("get_keycode") rescue 0_i64
                if pressed && !echo && ctrl && keycode == 83_i64 # KEY_S
                  save_and_sync!
                  src_edit.call("accept_event") rescue nil
                end
              end
            end
          end

          split.call("add_child", src_edit)
          @source_edit = src_edit
        end

        pbox = Godot.create(Godot::VBoxContainer)
        if pbox && !pbox.pointer.null?
          pbox.call("set_h_size_flags", 3_i64)
          pbox.call("set_v_size_flags", 3_i64)
          pbox.call("set_visible", @split_preview_visible)

          plbl = Godot.create(Godot::Label)
          if plbl && !plbl.pointer.null?
            plbl.call("set_text", "Compiled Target Preview (.gdshader / .gdshaderinc / .glsl)")
            plbl.call("add_theme_color_override", "font_color", Color.new(0.62_f32, 0.68_f32, 0.75_f32, 1.0_f32))
            pbox.call("add_child", plbl)
          end

          prev_edit = Godot.create(Godot::CodeEdit)
          if prev_edit && !prev_edit.pointer.null?
            prev_edit.call("set_h_size_flags", 3_i64)
            prev_edit.call("set_v_size_flags", 3_i64)
            prev_edit.call("set_gutters_draw_line_numbers", true)
            prev_edit.call("set_editable", false)
            Highlighter.apply_to_code_edit(prev_edit)
            pbox.call("add_child", prev_edit)
            @preview_edit = prev_edit
          end

          split.call("add_child", pbox)
          @preview_box = pbox
        end

        call("add_child", split)
      end
    end

    def _process(delta : Float64) : Void
      if @auto_compile && @dirty
        @debounce_sec -= delta
        if @debounce_sec <= 0.0
          @dirty = false
          compile_preview(sync_disk: false)
        end
      end
    end

    def bind_resource(res : CrShader::CRShader) : Void
      ensure_ui_built!
      @crshader_res = res
      if !res.file_path.empty?
        load_crshader_file(res.file_path, fallback_source: res.crshader_source)
      elsif !res.crshader_source.empty?
        set_source_text(res.crshader_source)
        compile_preview(sync_disk: false)
      end
    end

    def load_crshader_file(path : String, fallback_source : String = "") : Bool
      ensure_ui_built!
      @file_path = path
      resolved = ResourceFormatLoaderCRShader.resolve_file_path(path)
      if resolved.empty? && !Godot::ProjectSettings.singleton_ptr.null? && path.starts_with?("res://")
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        resolved = ps.call_str("globalize_path", path).gsub('\\', '/')
      end
      @disk_path = resolved
      src = (!resolved.empty? && File.file?(resolved)) ? File.read(resolved) : fallback_source
      set_source_text(src)
      if ed = @source_edit
        ed.call("tag_saved_version") rescue nil
      end
      compile_preview(sync_disk: false)
    end

    def get_source_text : String
      if ed = @source_edit
        return ed.call_str("get_text") if !ed.pointer.null?
      end
      ""
    end

    def set_source_text(text : String) : Void
      ensure_ui_built!
      if ed = @source_edit
        if !ed.pointer.null?
          @suppress_text_signal = true
          begin
            ed.call("set_text", text)
          ensure
            @suppress_text_signal = false
          end
        end
      end
    end

    def get_preview_text : String
      if ed = @preview_edit
        return ed.call_str("get_text") if !ed.pointer.null?
      end
      ""
    end

    def insert_trait_line(trait_name : String) : Void
      if ed = @source_edit
        return if ed.pointer.null?
        line_idx = ed.call_i64("get_caret_line")
        ed.call("insert_line_at", line_idx, "use_trait \"std/traits/#{trait_name}\"")
        @dirty = true
        @debounce_sec = 0.1_f64
      end
    end

    private def clear_error_highlight! : Void
      if @last_error_line >= 0
        if ed = @source_edit
          if !ed.pointer.null?
            line_cnt = (ed.call_i64("get_line_count") rescue 0_i64).to_i32
            if @last_error_line < line_cnt
              ed.call("set_line_background_color", @last_error_line.to_i64, Color.new(0_f32, 0_f32, 0_f32, 0_f32)) rescue nil
            end
          end
        end
        @last_error_line = -1
      end
    end

    private def highlight_error_line!(line_1based : Int32) : Void
      clear_error_highlight!
      if ed = @source_edit
        return if ed.pointer.null?
        line_cnt = (ed.call_i64("get_line_count") rescue 0_i64).to_i32
        return if line_cnt <= 0
        idx = (line_1based - 1).clamp(0, line_cnt - 1)
        ed.call("set_line_background_color", idx.to_i64, Color.new(0.55_f32, 0.12_f32, 0.15_f32, 0.45_f32)) rescue nil
        @last_error_line = idx
      end
    end

    def compile_preview(sync_disk : Bool = false) : Bool
      ensure_ui_built!
      src = get_source_text
      return false if src.strip.empty?

      eff_file = !@disk_path.empty? ? @disk_path : (@file_path.empty? ? nil : @file_path)
      compiler = Compiler.new(strip_debug_inspects: @release_strip)

      begin
        t0 = Time.instant
        outputs = compiler.compile_emit_targets(src, filename: eff_file, write_disk: sync_disk)
        elapsed_ms = (Time.instant - t0).total_milliseconds

        clear_error_highlight!

        preview_str = if outputs.size == 1
                        outputs[0][2]
                      else
                        String.build do |io|
                          outputs.each_with_index do |(out_p, _tgt, code), idx|
                            io << "\n" if idx > 0
                            io << "// =====================================================================\n"
                            io << "// Target #{idx + 1}/#{outputs.size}: #{File.basename(out_p)}\n"
                            io << "// =====================================================================\n"
                            io << code
                          end
                        end
                      end

        if prev = @preview_edit
          prev.call("set_text", preview_str) if !prev.pointer.null?
        end

        primary_target = outputs.first?.try(&.[1]) || ShaderTarget::GDShader
        badge_name = File.basename(@file_path.empty? ? "untitled.crshader" : @file_path)
        target_label = case primary_target
                       when ShaderTarget::GLSL        then "Compute -> .glsl"
                       when ShaderTarget::GDShaderInc then "Include -> .gdshaderinc"
                       else                                "Shader -> .gdshader"
                       end
        if outputs.size > 1
          target_label = "#{target_label} (#{outputs.size} outputs)"
        end
        if b = @target_badge
          b.call("set_text", "🔮 #{badge_name} [#{target_label}]") if !b.pointer.null?
        end

        if res = @crshader_res
          res.crshader_source = src
          if sync_disk
            res.compile_and_sync_targets!(write_disk: true)
          elsif primary_target == ShaderTarget::GDShader && !res.pointer.null?
            res.set_code(outputs[0][2])
          end
        end

        total_lines = outputs.sum { |o| o[2].lines.size }
        action = sync_disk ? "Synced #{outputs.size} target(s)" : "Compiled"
        set_status("✔ #{action} (#{total_lines} lines in #{elapsed_ms.round(2)}ms)", is_error: false)
        true
      rescue ex : ShaderError
        line_no = ex.line_number || 1
        highlight_error_line!(line_no)
        set_status("✖ Line #{line_no}: #{ex.message}", is_error: true)
        false
      rescue ex
        set_status("✖ #{ex.message}", is_error: true)
        false
      end
    end

    def save_and_sync! : Bool
      src = get_source_text
      if !@disk_path.empty?
        pdir = File.dirname(@disk_path)
        Dir.mkdir_p(pdir) unless Dir.exists?(pdir)
        File.write(@disk_path, src)
      end
      ok = compile_preview(sync_disk: true)
      if ok
        if ed = @source_edit
          ed.call("tag_saved_version") rescue nil
        end
        trigger_editor_filesystem_scan!
        fname = @file_path.empty? ? File.basename(@disk_path) : @file_path
        set_status("💾 Saved #{fname} & synced compiled shader target(s)", is_error: false)
      end
      ok
    rescue ex
      set_status("✖ Save failed: #{ex.message}", is_error: true)
      false
    end

    private def trigger_editor_filesystem_scan! : Void
      return if Godot::EditorInterface.singleton_ptr.null?
      ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      fs = ei.call_obj("get_resource_filesystem") rescue nil
      if fs && !fs.pointer.null?
        fs.call("scan_sources") rescue (fs.call("scan") rescue nil)
      end
    rescue
    end

    private def set_status(msg : String, is_error : Bool) : Void
      if lbl = @status_label
        return if lbl.pointer.null?
        lbl.call("set_text", msg)
        col = is_error ? Color.new(1.0_f32, 0.38_f32, 0.38_f32, 1.0_f32) : Color.new(0.45_f32, 0.92_f32, 0.58_f32, 1.0_f32)
        lbl.call("add_theme_color_override", "font_color", col)
      end
    end
  end

  # =============================================================================
  # ShaderEditorIntegration - Hooks CrShader Directly into Godot's "Shader Editor"
  # =============================================================================
  module ShaderEditorIntegration
    extend self

    @@shader_dock : Godot::Control? = nil
    @@shader_list : Godot::ItemList? = nil
    @@shader_tabs : Godot::TabContainer? = nil
    @@top_menu_bar : Godot::HBoxContainer? = nil
    @@crshader_menu_btn : Godot::MenuButton? = nil
    @@edit_source_btn : Godot::Button? = nil
    @@menu_files : Array(String) = [] of String
    @@tab_editors : Hash(String, CrShaderTabEditor) = {} of String => CrShaderTabEditor
    @@current_companion_crshader : String = ""

    def active_editors : Hash(String, CrShaderTabEditor)
      @@tab_editors.reject! { |_k, v| v.pointer.null? || !Bridge.is_object_valid(v.pointer) }
      @@tab_editors
    end

    def valid_ctrl?(ctrl : Godot::Object?) : Bool
      !ctrl.nil? && !ctrl.not_nil!.pointer.null? && Bridge.is_object_valid(ctrl.not_nil!.pointer)
    end

    # Discovers all project `.crshader` files as `res://` paths.
    def discover_project_crshaders(project_root : String? = nil) : Array(String)
      root = project_root
      if root.nil? || root.empty?
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          gp = ps.call_str("globalize_path", "res://").gsub('\\', '/').rstrip('/')
          root = gp unless gp.empty?
        end
      end
      clean_root = (root.nil? || root.empty? ? Dir.current : root.not_nil!).gsub('\\', '/').rstrip('/')

      results = [] of String
      Dir.glob("#{clean_root}/**/*.crshader").sort!.each do |full|
        norm = full.gsub('\\', '/')
        next if norm.includes?("/.godot/") || norm.includes?("/lib/") || norm.includes?("/bin/")
        rel = norm.downcase.starts_with?("#{clean_root.downcase}/") ? norm[(clean_root.size + 1)..] : norm
        results << "res://#{rel}"
      end
      results
    rescue
      [] of String
    end

    # Maps any generated `.gdshader` / `.gdshaderinc` / `.glsl` path back to its authoring `.crshader` path!
    def find_companion_crshader(compiled_res_path : String) : String?
      return nil if compiled_res_path.empty?
      return compiled_res_path if compiled_res_path.downcase.ends_with?(".crshader")

      # 1. Scan `.crshader` files in the same directory for an explicit `emit_target` / `output_target` declaration first
      #    (handles multi-target files like `outline.crshader` -> `pattern_replace.gdshader` AND stem collisions like `outline.glsl` -> `outline_compositor.crshader`!)
      target_base = File.basename(compiled_res_path)
      dir_res = File.dirname(compiled_res_path)
      dir_disk = ResourceFormatLoaderCRShader.resolve_file_path(dir_res).gsub('\\', '/')
      if dir_disk.empty? && !Godot::ProjectSettings.singleton_ptr.null? && dir_res.starts_with?("res://")
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        dir_disk = ps.call_str("globalize_path", dir_res).gsub('\\', '/')
      end
      if !dir_disk.empty? && Dir.exists?(dir_disk)
        escaped_base = Regex.escape(target_base)
        emit_regex = /\b(?:emit_target|output_target)\s+"(?:[^"]*\/)?#{escaped_base}"/
        Dir.glob("#{dir_disk}/*.crshader").sort!.each do |cr_file|
          content = File.read(cr_file) rescue ""
          if content.matches?(emit_regex)
            return "#{dir_res}/#{File.basename(cr_file)}"
          end
        end
      end

      # 2. Direct stem sibling fallback when no explicit `emit_target` claimed the file (e.g. water.gdshader -> water.crshader)
      stem_candidate = compiled_res_path.sub(/\.(gdshaderinc|gdshader|glsl)$/i, ".crshader")
      if stem_candidate != compiled_res_path
        disk_cand = ResourceFormatLoaderCRShader.resolve_file_path(stem_candidate)
        return stem_candidate unless disk_cand.empty?
      end
      nil
    rescue
      nil
    end

    # Locates Godot 4.8's built-in "Shader Editor" dock (`EditorDock` / `WindowWrapper`),
    # its left-hand `ItemList`, top menu `HBoxContainer`, and right-hand `TabContainer`.
    def locate_godot_shader_editor! : Bool
      if valid_ctrl?(@@shader_dock) && valid_ctrl?(@@shader_tabs) && valid_ctrl?(@@shader_list)
        return true
      end
      return false if Godot::EditorInterface.singleton_ptr.null?

      ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      base = ei.get_base_control rescue nil
      return false unless valid_ctrl?(base)

      dock_ctrl = find_shader_dock_recursive(base.not_nil!, 0)
      return false unless valid_ctrl?(dock_ctrl)

      @@shader_dock = Godot::Control.new(dock_ctrl.not_nil!.pointer)
      find_shader_editor_internals(@@shader_dock.not_nil!, 0)
      ensure_toolbar_controls!
      valid_ctrl?(@@shader_tabs)
    rescue
      false
    end

    private def find_shader_dock_recursive(node : Godot::Node, depth : Int32) : Godot::Node?
      return nil if depth > 14 || node.pointer.null?
      cls = node.get_class rescue ""
      name = node.call_str("get_name") rescue ""

      if cls == "EditorDock" || node.is_class("EditorDock")
        title = node.call_str("get_title") rescue ""
        lkey = node.call_str("get_layout_key") rescue ""
        if title == "Shader Editor" || title == "Shader" || lkey.includes?("Shader") || name.includes?("Shader")
          return node
        end
      end

      if cls.includes?("ShaderEditor") && cls != "ShaderEditorPlugin"
        return node
      end

      if (name == "Shader Editor" || name == "ShaderEditor") && node.is_class("Control")
        return node
      end

      cnt = (node.call_i64("get_child_count") rescue 0_i64).to_i32
      cnt.times do |i|
        child = node.call_obj("get_child", i.to_i64) rescue nil
        next unless child && !child.pointer.null?
        if found = find_shader_dock_recursive(Godot::Node.new(child.pointer), depth + 1)
          return found
        end
      end
      nil
    end

    private def find_shader_editor_internals(node : Godot::Node, depth : Int32) : Void
      return if depth > 10 || node.pointer.null?
      cls = node.get_class rescue ""

      if cls == "ItemList" && !valid_ctrl?(@@shader_list)
        @@shader_list = Godot::ItemList.new(node.pointer)
        # Parent of ItemList is the left VBoxContainer; its first HBoxContainer child is the File/Menu bar
        if parent = (node.call_obj("get_parent") rescue nil)
          if !parent.pointer.null?
            pcnt = (parent.call_i64("get_child_count") rescue 0_i64).to_i32
            pcnt.times do |pi|
              sib = parent.call_obj("get_child", pi.to_i64) rescue nil
              if sib && !sib.pointer.null? && (sib.get_class rescue "") == "HBoxContainer"
                @@top_menu_bar = Godot::HBoxContainer.new(sib.pointer)
                break
              end
            end
          end
        end
      elsif cls == "TabContainer" && !valid_ctrl?(@@shader_tabs)
        @@shader_tabs = Godot::TabContainer.new(node.pointer)
      end

      cnt = (node.call_i64("get_child_count") rescue 0_i64).to_i32
      cnt.times do |i|
        child = node.call_obj("get_child", i.to_i64) rescue nil
        next unless child && !child.pointer.null?
        find_shader_editor_internals(Godot::Node.new(child.pointer), depth + 1)
      end
    end

    # Injects the `🔮 CRShader` menu and contextual `Edit .crshader Source` button into Godot's Shader Editor bar.
    def ensure_toolbar_controls! : Void
      bar = @@top_menu_bar
      return unless valid_ctrl?(bar)

      unless valid_ctrl?(@@crshader_menu_btn)
        mbtn = Godot.create(Godot::MenuButton)
        if mbtn && !mbtn.pointer.null?
          mbtn.call("set_name", "CRShaderMenuButton")
          mbtn.call("set_text", "🔮 CRShader")
          mbtn.call("set_tooltip_text", "Open, create, or compile .crshader files right inside the Shader Editor")
          if popup = (mbtn.call_obj("get_popup") rescue nil)
            if !popup.pointer.null?
              popup.connect("about_to_popup") do |_args|
                populate_crshader_popup!(Godot::PopupMenu.new(popup.pointer))
              end
              popup.connect("id_pressed") do |args|
                id = (args.first?.try(&.as_i) || -1).to_i32
                handle_crshader_menu_id(id)
              end
            end
          end
          bar.not_nil!.call("add_child", mbtn)
          @@crshader_menu_btn = mbtn
        end
      end

      unless valid_ctrl?(@@edit_source_btn)
        ebtn = Godot.create(Godot::Button)
        if ebtn && !ebtn.pointer.null?
          ebtn.call("set_name", "CRShaderEditSourceButton")
          ebtn.call("set_text", "🔮 Edit .crshader")
          ebtn.call("set_visible", false)
          ebtn.connect("pressed") do |_args|
            target = @@current_companion_crshader
            open_shader(target) unless target.empty?
          end
          bar.not_nil!.call("add_child", ebtn)
          @@edit_source_btn = ebtn
        end
      end
    rescue
    end

    private def populate_crshader_popup!(popup : Godot::PopupMenu) : Void
      popup.call("clear")
      @@menu_files = discover_project_crshaders
      if @@menu_files.empty?
        popup.call("add_item", "(No .crshader files found)", 9999_i64)
        popup.call("set_item_disabled", 0_i64, true)
      else
        @@menu_files.each_with_index do |res_path, idx|
          label = res_path.sub(/^res:\/\//, "")
          popup.call("add_item", "📄 #{label}", idx.to_i64)
        end
      end
      popup.call("add_separator", "", 9000_i64)
      popup.call("add_item", "▶ Compile & Sync All Project .crshader Files", 9001_i64)
    rescue
    end

    private def handle_crshader_menu_id(id : Int32) : Void
      if id >= 0 && id < @@menu_files.size
        open_shader(@@menu_files[id])
      elsif id == 9001
        compile_all_project_crshaders!
      end
    end

    def compile_all_project_crshaders!(project_root : String? = nil) : Int32
      count = 0
      compiler = Compiler.new
      discover_project_crshaders(project_root).each do |res_p|
        disk_p = ResourceFormatLoaderCRShader.resolve_file_path(res_p)
        next if disk_p.empty? || !File.file?(disk_p)
        outputs = compiler.compile_emit_targets(File.read(disk_p), filename: disk_p, write_disk: true)
        count += outputs.size
      end
      Godot.print("[CRShader] Compiled and synced #{count} shader output(s) across project.")
      count
    rescue ex
      Godot.printerr("[CRShader] Bulk compile error: #{ex.message}")
      0
    end

    # Raises and focuses Godot's built-in "Shader Editor" bottom dock.
    def reveal_shader_editor_dock!(host_plugin : Godot::Object? = nil) : Void
      locate_godot_shader_editor!
      if valid_ctrl?(@@shader_dock)
        dock = @@shader_dock.not_nil!
        if dock.is_class("EditorDock")
          ed_dock = Godot::EditorDock.new(dock.pointer)
          ed_dock.open rescue nil
          ed_dock.make_visible rescue nil
          return
        end
        if hp = host_plugin
          if !hp.pointer.null? && Bridge.is_object_valid(hp.pointer)
            hp.call("make_bottom_panel_item_visible", dock) rescue nil
          end
        end
        dock.call("show") rescue nil
      end
    rescue
    end

    # Opens a `.crshader` file (or `CRShader` resource) directly inside Godot's "Shader Editor" tab
    # and returns its mounted `CrShaderTabEditor`.
    def open_shader(
      path_or_res : String | CrShader::CRShader,
      host_plugin : Godot::Object? = nil,
    ) : CrShaderTabEditor?
      res_obj : CrShader::CRShader? = nil
      res_path = ""

      if path_or_res.is_a?(CrShader::CRShader)
        res_obj = path_or_res
        res_path = path_or_res.file_path
        if res_path.empty? && !path_or_res.pointer.null?
          res_path = path_or_res.call_str("get_path") rescue ""
        end
      else
        res_path = path_or_res
        if !Godot::ResourceLoader.singleton_ptr.null? && res_path.ends_with?(".crshader")
          rl = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
          loaded = rl.call_obj("load", res_path) rescue nil
          if loaded && !loaded.pointer.null?
            if inst = Bridge.find_alive_instance(loaded.pointer)
              res_obj = inst if inst.is_a?(CrShader::CRShader)
            end
          end
        end
      end

      # Ask Godot's EditorInterface to edit the CRShader resource so ShaderEditorPlugin registers it in Shader Editor
      if res_obj && !res_obj.not_nil!.pointer.null? && !Godot::EditorInterface.singleton_ptr.null?
        ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        ei.call("edit_resource", res_obj.not_nil!) rescue nil
      end

      reveal_shader_editor_dock!(host_plugin)
      sync_shader_tabs!

      if existing = active_editors[res_path]?
        focus_crshader_in_list!(res_path)
        return existing
      end

      # Fallback when ShaderEditorPlugin did not create a slot (e.g. headless spec or standalone):
      editor = Godot.create(CrShader::CrShaderTabEditor)
      return nil unless editor && !editor.pointer.null?
      editor.ensure_ui_built!
      if r = res_obj
        editor.bind_resource(r)
      elsif !res_path.empty?
        editor.load_crshader_file(res_path)
      end

      if valid_ctrl?(@@shader_tabs)
        tabs = @@shader_tabs.not_nil!
        tab_title = File.basename(res_path.empty? ? "untitled.crshader" : res_path)
        editor.call("set_name", tab_title)
        tabs.call("add_child", editor)
        new_idx = (tabs.call_i64("get_child_count") rescue 1_i64) - 1_i64
        tabs.call("set_current_tab", new_idx) rescue nil
        if valid_ctrl?(@@shader_list)
          list = @@shader_list.not_nil!
          item_idx = (list.call_i64("add_item", tab_title) rescue -1_i64)
          if item_idx >= 0
            list.call("set_item_tooltip", item_idx, res_path) rescue nil
            list.call("select", item_idx) rescue nil
          end
        end
      end

      @@tab_editors[res_path] = editor unless res_path.empty?
      editor
    end

    private def focus_crshader_in_list!(res_path : String) : Void
      return unless valid_ctrl?(@@shader_list) && valid_ctrl?(@@shader_tabs)
      list = @@shader_list.not_nil!
      tabs = @@shader_tabs.not_nil!
      bname = File.basename(res_path)
      cnt = (list.call_i64("get_item_count") rescue 0_i64).to_i32
      cnt.times do |i|
        txt = (list.call_str("get_item_text", i.to_i64) rescue "").gsub("(*)", "").strip
        tip = list.call_str("get_item_tooltip", i.to_i64) rescue ""
        if tip == res_path || txt == bname
          list.call("select", i.to_i64) rescue nil
          tabs.call("set_current_tab", i.to_i64) rescue nil
          break
        end
      end
    rescue
    end

    # Inspects Godot's `Shader Editor` open tabs and upgrades any `.crshader` `TextShaderEditor` slot
    # in-place with `CrShaderTabEditor`, plus updates the contextual `Edit .crshader` button!
    def sync_shader_tabs! : Void
      return unless locate_godot_shader_editor!
      return unless valid_ctrl?(@@shader_list) && valid_ctrl?(@@shader_tabs)

      list = @@shader_list.not_nil!
      tabs = @@shader_tabs.not_nil!
      item_cnt = (list.call_i64("get_item_count") rescue 0_i64).to_i32
      tab_cnt = (tabs.call_i64("get_child_count") rescue 0_i64).to_i32
      n = Math.min(item_cnt, tab_cnt)

      n.times do |i|
        tip = list.call_str("get_item_tooltip", i.to_i64) rescue ""
        txt = (list.call_str("get_item_text", i.to_i64) rescue "").gsub("(*)", "").strip
        cand_path = !tip.empty? ? tip : txt
        next unless cand_path.downcase.ends_with?(".crshader")

        slot = tabs.call_obj("get_child", i.to_i64) rescue nil
        next unless slot && !slot.pointer.null?

        # If this slot is already our CrShaderTabEditor or already hosts one, keep it synced
        if (slot.get_class rescue "") == "CrShaderTabEditor"
          next
        end
        existing_child = slot.call_obj("find_child", "CrShaderTabEditorHost", false, false) rescue nil
        next if existing_child && !existing_child.pointer.null?

        # Hide Godot's internal TextShaderEditor children so raw GDShader validation never runs on .crshader text!
        scnt = (slot.call_i64("get_child_count") rescue 0_i64).to_i32
        scnt.times do |si|
          sub = slot.call_obj("get_child", si.to_i64) rescue nil
          if sub && !sub.pointer.null? && sub.is_class("CanvasItem")
            sub.call("set_visible", false) rescue nil
          end
        end

        host = Godot.create(CrShader::CrShaderTabEditor)
        if host && !host.pointer.null?
          host.call("set_name", "CrShaderTabEditorHost")
          host.ensure_ui_built!
          res_full = cand_path.starts_with?("res://") ? cand_path : (discover_project_crshaders.find(&.ends_with?("/#{txt}")) || cand_path)
          host.load_crshader_file(res_full)
          slot.call("add_child", host)
          @@tab_editors[res_full] = host
        end
      end

      # Update contextual "🔮 Edit <name>.crshader" button for generated .gdshader/.gdshaderinc files
      if valid_ctrl?(@@edit_source_btn)
        ebtn = @@edit_source_btn.not_nil!
        curr_tab = (tabs.call_i64("get_current_tab") rescue -1_i64).to_i32
        companion : String? = nil
        if curr_tab >= 0 && curr_tab < item_cnt
          curr_tip = list.call_str("get_item_tooltip", curr_tab.to_i64) rescue ""
          if !curr_tip.empty? && !curr_tip.downcase.ends_with?(".crshader")
            companion = find_companion_crshader(curr_tip)
          end
        end
        if comp = companion
          @@current_companion_crshader = comp
          ebtn.call("set_text", "🔮 Edit #{File.basename(comp)}")
          ebtn.call("set_tooltip_text", "Open authoring CrShader source (#{comp}) in the Shader Editor")
          ebtn.call("set_visible", true)
        else
          @@current_companion_crshader = ""
          ebtn.call("set_visible", false)
        end
      end
    rescue
    end

    def save_all_open_shaders! : Void
      active_editors.each_value do |ed|
        ed.save_and_sync!
      end
    rescue
    end

    def cleanup! : Void
      if valid_ctrl?(@@crshader_menu_btn)
        @@crshader_menu_btn.not_nil!.call("queue_free") rescue nil
      end
      if valid_ctrl?(@@edit_source_btn)
        @@edit_source_btn.not_nil!.call("queue_free") rescue nil
      end
      active_editors.each_value do |ed|
        parent = ed.call_obj("get_parent") rescue nil
        if parent && !parent.pointer.null?
          if (parent.get_class rescue "") != "TabContainer"
            scnt = (parent.call_i64("get_child_count") rescue 0_i64).to_i32
            scnt.times do |si|
              sub = parent.call_obj("get_child", si.to_i64) rescue nil
              if sub && !sub.pointer.null? && sub.pointer != ed.pointer && sub.is_class("CanvasItem")
                sub.call("set_visible", true) rescue nil
              end
            end
          end
          ed.call("queue_free") rescue nil
        else
          ed.destroy rescue nil
        end
      end
      @@tab_editors.clear
      @@crshader_menu_btn = nil
      @@edit_source_btn = nil
      @@shader_dock = nil
      @@shader_list = nil
      @@shader_tabs = nil
      @@top_menu_bar = nil
    rescue
    end
  end
end
