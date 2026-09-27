require "lapis"
require "../compiler"

module CrShader
  include Godot

  # =============================================================================
  # CrShaderStudioPanel - Interactive In-Editor Shader Studio Dock
  # =============================================================================
  # Embedded live shader development environment inside the Godot Editor.
  # Provides side-by-side editing of .crshader files with full Crystal/GDShader
  # syntax highlighting and real-time transpiled .gdshader / .glsl preview.
  @[Tool]
  node CrShaderStudioPanel < Control do
    @active_file : String? = nil
    @source_edit : CodeEdit? = nil
    @target_edit : CodeEdit? = nil
    @file_picker : OptionButton? = nil
    @status_label : Label? = nil
    @highlighter : CodeHighlighter? = nil
    @found_files : Array(String) = [] of String
    @auto_compile : Bool = true
    @dirty : Bool = false
    @debounce_time : Float64 = 0.35_f64
    @last_error_line : Int32 = 0

    def _ready : Void
      call("set_anchors_preset", 15) # PRESET_FULL_RECT
      call("set_h_size_flags", 3)    # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3)    # SIZE_EXPAND_FILL
      call("set_custom_minimum_size", Vector2.new(0_f32, 280_f32))

      setup_ui
      refresh_file_list
      Godot.print("[CRShader] CRShader Studio GUI mounted (Toolbar, SourceEdit, TargetEdit ready)")
    end

    def setup_ui : Void
      margin = Godot.create(Godot::MarginContainer)
      return unless margin
      margin.call("set_anchors_preset", 15)
      margin.call("set_h_size_flags", 3)
      margin.call("set_v_size_flags", 3)
      margin.call("add_theme_constant_override", "margin_left", 8)
      margin.call("add_theme_constant_override", "margin_top", 6)
      margin.call("add_theme_constant_override", "margin_right", 8)
      margin.call("add_theme_constant_override", "margin_bottom", 6)
      call("add_child", margin)

      root_vbox = Godot.create(Godot::VBoxContainer)
      return unless root_vbox
      root_vbox.call("set_h_size_flags", 3)
      root_vbox.call("set_v_size_flags", 3)
      root_vbox.call("add_theme_constant_override", "separation", 6)
      margin.call("add_child", root_vbox)

      # --- Top Toolbar ---
      toolbar = Godot.create(Godot::HBoxContainer)
      if toolbar
        toolbar.call("add_theme_constant_override", "separation", 8)

        # Title Label
        title = Godot.create(Godot::Label)
        if title
          title.call("set_text", "🔮 CRShader Studio")
          title.call("add_theme_font_size_override", "font_size", 14)
          title.call("add_theme_color_override", "font_color", Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))
          toolbar.call("add_child", title)
        end

        # File Picker OptionButton
        picker = Godot.create(Godot::OptionButton)
        if picker
          picker.call("set_custom_minimum_size", Vector2.new(200_f32, 0_f32))
          toolbar.call("add_child", picker)
          @file_picker = picker
        end

        # Recompile Button
        compile_btn = Godot.create(Godot::Button)
        if compile_btn
          compile_btn.call("set_text", "▶ Compile")
          toolbar.call("add_child", compile_btn)
        end

        # Auto-Compile Toggle
        auto_check = Godot.create(Godot::CheckBox)
        if auto_check
          auto_check.call("set_text", "Auto-Compile")
          auto_check.call("set_pressed", true)
          auto_check.connect("toggled") do |args|
            @auto_compile = args.first?.try(&.as_bool) || false
          end
          toolbar.call("add_child", auto_check)
        end

        # Apply to Selected Node Button
        apply_btn = Godot.create(Godot::Button)
        if apply_btn
          apply_btn.call("set_text", "🎯 Apply to Selection")
          apply_btn.call("set_tooltip_text", "Assign compiled shader and material to currently selected scene node in editor")
          apply_btn.connect("pressed") do |_args|
            apply_to_selected_node
          end
          toolbar.call("add_child", apply_btn)
        end

        # Save Button
        save_btn = Godot.create(Godot::Button)
        if save_btn
          save_btn.call("set_text", "💾 Save")
          toolbar.call("add_child", save_btn)
        end

        # Refresh Files Button
        refresh_btn = Godot.create(Godot::Button)
        if refresh_btn
          refresh_btn.call("set_text", "🔄 Refresh")
          toolbar.call("add_child", refresh_btn)
        end

        # Status Label
        status = Godot.create(Godot::Label)
        if status
          status.call("set_h_size_flags", 3)
          status.call("set_text", "Ready")
          status.call("add_theme_color_override", "font_color", Color.new(0.7_f32, 0.7_f32, 0.7_f32, 1.0_f32))
          toolbar.call("add_child", status)
          @status_label = status
        end

        root_vbox.call("add_child", toolbar)
      end

      # --- Split Editor & Preview Panes ---
      split = Godot.create(Godot::HSplitContainer)
      if split
        split.call("set_h_size_flags", 3)
        split.call("set_v_size_flags", 3)

        # Left: Source Editor
        left_vbox = Godot.create(Godot::VBoxContainer)
        if left_vbox
          left_vbox.call("set_h_size_flags", 3)
          left_vbox.call("set_v_size_flags", 3)

          lbl = Godot.create(Godot::Label)
          if lbl
            lbl.call("set_text", "Source Code (.crshader)")
            left_vbox.call("add_child", lbl)
          end

          src_edit = Godot.create(Godot::CodeEdit)
          if src_edit
            src_edit.call("set_h_size_flags", 3)
            src_edit.call("set_v_size_flags", 3)
            src_edit.call("set_line_wrapping_mode", 1) # AUTOWRAP_WORD
            src_edit.call("set_gutters_draw_line_numbers", true)
            src_edit.call("set_auto_brace_completion_enabled", true)
            src_edit.call("set_indent_size", 2)
            setup_syntax_highlighter(src_edit)
            src_edit.connect("text_changed") do |_args|
              @dirty = true
              @debounce_time = 0.35_f64
            end
            left_vbox.call("add_child", src_edit)
            @source_edit = src_edit
          end

          split.call("add_child", left_vbox)
        end

        # Right: Target Output Preview
        right_vbox = Godot.create(Godot::VBoxContainer)
        if right_vbox
          right_vbox.call("set_h_size_flags", 3)
          right_vbox.call("set_v_size_flags", 3)

          lbl = Godot.create(Godot::Label)
          if lbl
            lbl.call("set_text", "Compiled Target Shader (.gdshader / .glsl)")
            right_vbox.call("add_child", lbl)
          end

          tgt_edit = Godot.create(Godot::CodeEdit)
          if tgt_edit
            tgt_edit.call("set_h_size_flags", 3)
            tgt_edit.call("set_v_size_flags", 3)
            tgt_edit.call("set_line_wrapping_mode", 1)
            tgt_edit.call("set_gutters_draw_line_numbers", true)
            tgt_edit.call("set_editable", false)
            right_vbox.call("add_child", tgt_edit)
            @target_edit = tgt_edit
          end

          split.call("add_child", right_vbox)
        end

        root_vbox.call("add_child", split)
      end
    end

    def apply_to_selected_node : Void
      active = @active_file
      return unless active && File.exists?(active)

      target_path = active.sub(/\.crshader$/, active.includes?("compute") ? ".glsl" : ".gdshader")
      return unless File.exists?(target_path)

      res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
      shader = res_loader.call_obj("load", target_path)
      return unless shader && !shader.pointer.null?

      mat = Godot.create(Godot::ShaderMaterial)
      return unless mat
      mat.call("set_shader", shader)

      set_status("🎯 Material ready from #{File.basename(target_path)} for scene nodes", is_error: false)
    rescue ex
      set_status("✖ Could not apply: #{ex.message}", is_error: true)
    end

    def jump_to_line(line : Int32) : Void
      if edit = @source_edit
        edit.call("set_caret_line", Math.max(0, line - 1))
        edit.call("set_caret_column", 0)
        edit.call("center_viewport_to_caret")
      end
    end

    def _process(delta : Float64) : Void
      if @auto_compile && @dirty
        @debounce_time -= delta
        if @debounce_time <= 0.0
          @dirty = false
          compile_current_source
        end
      end
    end

    def refresh_file_list : Void
      picker = @file_picker
      return unless picker

      picker.call("clear")
      @found_files.clear

      files = Dir.glob("**/*.crshader").reject do |p|
        p.starts_with?(".godot") || p.starts_with?("lib/") || p.starts_with?("bin/") || p.starts_with?("build/")
      end

      files.each_with_index do |f, idx|
        @found_files << f
        picker.call("add_item", f, idx)
      end

      if !@found_files.empty?
        load_file(@found_files.first)
      else
        set_status("No .crshader files found in project root.", is_error: false)
      end
    end

    def load_file(path : String) : Void
      return unless File.exists?(path)
      @active_file = path
      content = File.read(path)
      @source_edit.try &.call("set_text", content)
      compile_current_source(content)
    end

    def compile_current_source(explicit_source : String? = nil) : Void
      source = explicit_source || @source_edit.try(&.call("get_text").to_s) || ""
      return if source.strip.empty?

      compiler = Compiler.new
      begin
        target_code = compiler.compile_source(source, filename: @active_file)
        @target_edit.try &.call("set_text", target_code)
        set_status("✔ Compiled successfully (#{target_code.lines.size} lines)", is_error: false)

        # Write compiled file to disk if active file known
        if active = @active_file
          is_compute = source.includes?("shader_type :compute") || source.includes?("shader_type(\"compute\")")
          out_ext = is_compute ? ".glsl" : ".gdshader"
          out_path = active.sub(/\.crshader$/, out_ext)
          File.write(out_path, target_code)
        end
      rescue ex : ShaderError
        set_status("✖ #{ex.message} (line #{ex.line_number || 1})", is_error: true)
      rescue ex
        set_status("✖ #{ex.message}", is_error: true)
      end
    end

    def save_current_file : Void
      if active = @active_file
        source = @source_edit.try(&.call("get_text").to_s) || ""
        File.write(active, source)
        compile_current_source
        set_status("💾 Saved and compiled #{active}", is_error: false)
      end
    end

    private def set_status(msg : String, is_error : Bool = false) : Void
      if lbl = @status_label
        lbl.call("set_text", msg)
        col = is_error ? Color.new(1.0_f32, 0.35_f32, 0.35_f32, 1.0_f32) : Color.new(0.4_f32, 0.9_f32, 0.5_f32, 1.0_f32)
        lbl.call("add_theme_color_override", "font_color", col)
      end
    end

    # =========================================================================
    # Rich Syntax Highlighter Configuration
    # =========================================================================
    private def setup_syntax_highlighter(edit : CodeEdit) : Void
      highlighter = Godot.create(Godot::CodeHighlighter)
      return if highlighter.nil?

      # Colors
      kw_color = Color.new(0.85_f32, 0.45_f32, 0.9_f32, 1.0_f32)     # Purple
      type_color = Color.new(0.35_f32, 0.75_f32, 1.0_f32, 1.0_f32)   # Cyan / Blue
      builtin_color = Color.new(1.0_f32, 0.75_f32, 0.3_f32, 1.0_f32) # Orange
      fn_color = Color.new(0.45_f32, 0.85_f32, 0.6_f32, 1.0_f32)     # Light Green
      comment_color = Color.new(0.5_f32, 0.55_f32, 0.6_f32, 1.0_f32) # Gray
      string_color = Color.new(0.95_f32, 0.85_f32, 0.4_f32, 1.0_f32) # Gold
      num_color = Color.new(0.8_f32, 0.6_f32, 1.0_f32, 1.0_f32)      # Violet

      # 1. Keywords
      keywords = [
        "shader", "shader_type", "render_mode", "setup_gdshader",
        "uniform", "instance_uniform", "global_uniform", "varying", "const",
        "buffer", "push_constant", "shared", "image2d", "local_size", "require",
        "group", "subgroup", "field",
        "def", "end", "class", "struct", "module", "if", "else", "elsif", "unless",
        "while", "until", "for", "in", "case", "when", "return", "break", "next",
        "true", "false", "nil", "macro"
      ]
      keywords.each do |kw|
        highlighter.call("add_keyword_color", kw, kw_color)
      end

      # 2. Stages
      stages = ["vertex", "fragment", "light", "start", "process", "sky", "fog", "main"]
      stages.each do |st|
        highlighter.call("add_keyword_color", st, Color.new(1.0_f32, 0.4_f32, 0.6_f32, 1.0_f32))
      end

      # 3. Types
      types = [
        "Float32", "Float64", "Float", "Int32", "UInt32", "Int", "UInt", "Bool", "Void",
        "Vec2", "Vec3", "Vec4", "IVec2", "IVec3", "IVec4", "UVec2", "UVec3", "UVec4",
        "BVec2", "BVec3", "BVec4", "Mat2", "Mat3", "Mat4", "Color",
        "Sampler2D", "SamplerCube", "Sampler2DArray", "Sampler3D",
        "Sampler2DShadow", "SamplerCubeShadow", "Sampler2DArrayShadow",
        "ISampler2D", "USampler2D", "Image2D", "IImage2D", "UImage2D", "Image3D",
        "SubpassInput", "Array", "InOut", "Out"
      ]
      types.each do |t|
        highlighter.call("add_keyword_color", t, type_color)
      end

      # 4. Built-in Variables & Constants
      builtins = [
        "VERTEX", "NORMAL", "TANGENT", "BINORMAL", "COLOR", "UV", "UV2",
        "ROUGHNESS", "METALLIC", "SPECULAR", "ALBEDO", "ALPHA", "ALPHA_SCISSOR_THRESHOLD",
        "EMISSION", "NORMAL_MAP", "NORMAL_MAP_DEPTH", "RIM", "RIM_TINT", "CLEARCOAT",
        "CLEARCOAT_ROUGHNESS", "CLEARCOAT_GLOSS", "ANISOTROPY", "ANISOTROPY_FLOW",
        "AO", "AO_LIGHT_AFFECT", "SSS_STRENGTH", "TRANSMISSION", "BACKLIGHT", "DEPTH",
        "POINT_SIZE", "POSITION", "TIME", "FRAGCOORD", "FRONT_FACING", "POINT_COORD",
        "MODEL_MATRIX", "VIEW_MATRIX", "PROJECTION_MATRIX", "MODELVIEW_MATRIX",
        "INV_VIEW_MATRIX", "INV_PROJECTION_MATRIX", "SCREEN_UV", "SCREEN_PIXEL_SIZE",
        "TEXTURE_PIXEL_SIZE", "LIGHT", "LIGHT_COLOR", "LIGHT_ENERGY", "LIGHT_POSITION",
        "TRANSFORM", "VELOCITY", "CUSTOM", "MASS", "ACTIVE", "RESTART", "LIFETIME", "DELTA",
        "INDEX", "NUMBER", "SEED", "EYEDIR", "HALF_RES_COLOR", "QUARTER_RES_COLOR",
        "WORLD_POSITION", "FOG_COLOR", "DENSITY", "SDF",
        "gl_NumWorkGroups", "gl_WorkGroupSize", "gl_WorkGroupID",
        "gl_LocalInvocationID", "gl_GlobalInvocationID", "gl_LocalInvocationIndex"
      ]
      builtins.each do |b|
        highlighter.call("add_member_keyword_color", b, builtin_color)
      end

      # 5. Functions & Built-in Helpers
      highlighter.call("set_function_color", fn_color)
      highlighter.call("set_number_color", num_color)

      # 6. Regions (Strings and Comments)
      highlighter.call("add_color_region", "\"", "\"", string_color, false)
      highlighter.call("add_color_region", "#", "", comment_color, true)

      edit.call("set_syntax_highlighter", highlighter)
      @highlighter = highlighter
    end
  end

  CRShaderStudioPanel = CrShaderStudioPanel
end


