require "lapis"
require "../compiler"
require "../../crshader_resource"
require "../../resource_format"

module CrShader
  include Godot

  # =============================================================================
  # ShaderCreateDialogIntegration - Native CRShader Type & Templates in Ctrl+N
  # =============================================================================
  # Hooks every `ShaderCreateDialog` in Godot 4.8 (Shader Editor `Ctrl+N` /
  # `File -> New Shader...`, FileSystem `Create New -> Shader...`, and Inspector
  # `ShaderMaterial -> New Shader...`) using crash-safe proxy controls so C++
  # `ShaderCreateDialog` internal type indices (`0..2`) are never out-of-bounds.
  module ShaderCreateDialogIntegration
    extend self

    class DialogHook
      property dialog : Godot::ConfirmationDialog
      property grid : Godot::GridContainer
      property orig_type_ob : Godot::OptionButton
      property orig_mode_ob : Godot::OptionButton
      property orig_tmpl_ob : Godot::OptionButton
      property orig_builtin_cb : Godot::CheckBox
      property orig_path_hbox : Godot::HBoxContainer
      property orig_path_le : Godot::LineEdit
      property orig_browse_btn : Godot::Button
      property orig_val_panel : Godot::Control
      property orig_ok_btn : Godot::Button

      property proxy_type_ob : Godot::OptionButton
      property proxy_mode_ob : Godot::OptionButton
      property proxy_tmpl_ob : Godot::OptionButton
      property proxy_path_hbox : Godot::HBoxContainer
      property proxy_path_le : Godot::LineEdit
      property proxy_browse_btn : Godot::Button
      property proxy_val_panel : Godot::PanelContainer
      property proxy_val_lbl1 : Godot::Label
      property proxy_val_lbl2 : Godot::Label
      property proxy_ok_btn : Godot::Button
      property proxy_file_dlg : Godot::EditorFileDialog? = nil

      property crshader_active : Bool = false
      property crshader_item_index : Int32 = 3
      property current_mode : Templates::Mode = Templates::Mode::Spatial
      property current_templates : Array(Templates::Entry) = [] of Templates::Entry
      property suppress_signals : Bool = false

      def initialize(
        @dialog,
        @grid,
        @orig_type_ob,
        @orig_mode_ob,
        @orig_tmpl_ob,
        @orig_builtin_cb,
        @orig_path_hbox,
        @orig_path_le,
        @orig_browse_btn,
        @orig_val_panel,
        @orig_ok_btn,
        @proxy_type_ob,
        @proxy_mode_ob,
        @proxy_tmpl_ob,
        @proxy_path_hbox,
        @proxy_path_le,
        @proxy_browse_btn,
        @proxy_val_panel,
        @proxy_val_lbl1,
        @proxy_val_lbl2,
        @proxy_ok_btn,
      )
      end

      def valid? : Bool
        !@dialog.pointer.null? && Bridge.is_object_valid(@dialog.pointer) &&
          !@proxy_type_ob.pointer.null? && Bridge.is_object_valid(@proxy_type_ob.pointer)
      end
    end

    @@hooks : Hash(UInt64, DialogHook) = {} of UInt64 => DialogHook
    @@initial_docks_hooked : Bool = false
    @@inspector_signal_hooked : Bool = false
    @@last_selected_was_crshader : Bool = false
    @@force_crshader_next_open : Bool = false
    @@force_template_id_next_open : String? = nil

    def last_selected_was_crshader? : Bool
      @@last_selected_was_crshader
    end

    def last_selected_was_crshader=(val : Bool) : Bool
      @@last_selected_was_crshader = val
    end

    def active_hooks : Array(DialogHook)
      @@hooks.reject! { |_k, h| !h.valid? }
      @@hooks.values
    end

    # Hooks `ShaderCreateDialog` instances across the Shader Editor, FileSystem dock, and Scene dock
    # in O(1) steady-state time (zero full-tree walks and zero per-tick allocations once hooked).
    def sync_dialogs!(force_rescan : Bool = false) : Int32
      if !force_rescan && @@initial_docks_hooked && !@@hooks.empty?
        return @@hooks.size if @@hooks.each_value.all?(&.valid?)
      end

      return 0 if Godot::EditorInterface.singleton_ptr.null?
      ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      base = ei.get_base_control rescue nil
      return 0 if base.nil? || base.not_nil!.pointer.null?

      dialogs = [] of Godot::Node

      # 1. Shader Editor dock -> @DocumentEditorContainer -> @ShaderCreateDialog (depth <= 2)
      s_dock = ShaderEditorIntegration.shader_dock
      has_shader_dock = !s_dock.nil? && !s_dock.not_nil!.pointer.null? && Bridge.is_object_valid(s_dock.not_nil!.pointer)
      if has_shader_dock
        collect_shader_create_dialogs(s_dock.not_nil!, dialogs, 0, max_depth: 2)
      end

      # 2. FileSystem dock -> @ShaderCreateDialog (direct child, depth <= 1)
      if fs_dock = (ei.get_file_system_dock rescue nil)
        if !fs_dock.pointer.null?
          collect_shader_create_dialogs(fs_dock, dialogs, 0, max_depth: 1)
        end
      end

      # 3. Scene dock -> @ShaderCreateDialog (direct child, depth <= 1)
      if scene_dock = (base.not_nil!.call_obj("find_child", "Scene", true, false) rescue nil)
        if !scene_dock.pointer.null?
          collect_shader_create_dialogs(Godot::Node.new(scene_dock.pointer), dialogs, 0, max_depth: 1)
        end
      end

      # 4. Event-driven Inspector hook (runs only when edited object changes, never polled)
      unless @@inspector_signal_hooked
        if inspector = (ei.get_inspector rescue nil)
          if !inspector.pointer.null?
            @@inspector_signal_hooked = true
            inspector.connect("edited_object_changed") do |_args|
              insp_dialogs = [] of Godot::Node
              collect_shader_create_dialogs(inspector, insp_dialogs, 0, max_depth: 4)
              hook_collected_dialogs!(insp_dialogs)
            end
          end
        end
      end

      hook_collected_dialogs!(dialogs)
      @@initial_docks_hooked = true if has_shader_dock && !@@hooks.empty?
      @@hooks.size
    rescue
      0
    end

    private def hook_collected_dialogs!(dialogs : Array(Godot::Node)) : Void
      dialogs.each do |dlg_node|
        addr = dlg_node.pointer.address
        if existing = @@hooks[addr]?
          next if existing.valid?
          @@hooks.delete(addr)
        end
        if hook = install_hook(Godot::ConfirmationDialog.new(dlg_node.pointer))
          @@hooks[addr] = hook
        end
      end
    end

    # Triggers Godot's Shader Editor "New Shader..." (`Ctrl+N`) dialog pre-selected to `CRShader`.
    def prompt_new_crshader!(
      template_id : String? = nil,
      host_plugin : Godot::Object? = nil,
    ) : Bool
      ShaderEditorIntegration.reveal_shader_editor_dock!(host_plugin)
      sync_dialogs!(force_rescan: true)

      @@force_crshader_next_open = true
      @@force_template_id_next_open = template_id

      # Prefer triggering the Shader Editor's own File -> New Shader... (id=2) so its native
      # directory resolution and `shader_created` signal wiring run identically to pressing Ctrl+N.
      if ShaderEditorIntegration.trigger_native_new_shader_menu!
        return true
      end

      # Fallback: open the first hooked ShaderCreateDialog directly
      if hook = active_hooks.first?
        hook.dialog.call("config", "res://new_shader", false, true, "", 0_i64) rescue nil
        refresh_hook_on_open!(hook)
        hook.dialog.call("popup_centered") rescue nil
        return true
      end

      @@force_crshader_next_open = false
      @@force_template_id_next_open = nil
      false
    rescue
      false
    end

    PRUNED_SUBTREE_CLASSES = Set{
      "PopupMenu", "EditorFileDialog", "ConfirmationDialog", "AcceptDialog",
      "CreateDialog", "ScriptCreateDialog", "Tree", "ItemList", "TabContainer",
      "CodeEdit", "TextEdit", "DocumentList", "DocumentOutline", "FindReplaceBar",
      "ProjectSettingsEditor",
    }

    private def collect_shader_create_dialogs(
      node : Godot::Node,
      results : Array(Godot::Node),
      depth : Int32,
      max_depth : Int32 = 2,
    ) : Void
      return if depth > max_depth || node.pointer.null?
      cls = node.get_class rescue ""
      if cls == "ShaderCreateDialog"
        results << node
        return
      end
      return if depth > 0 && PRUNED_SUBTREE_CLASSES.includes?(cls)
      return if depth >= max_depth

      cnt = (node.call_i64("get_child_count", true) rescue (node.call_i64("get_child_count") rescue 0_i64)).to_i32
      cnt.times do |i|
        child = (node.call_obj("get_child", i.to_i64, true) rescue (node.call_obj("get_child", i.to_i64) rescue nil))
        next unless child && !child.pointer.null?
        collect_shader_create_dialogs(Godot::Node.new(child.pointer), results, depth + 1, max_depth)
      end
    end

    private def find_first_by_class(node : Godot::Node, target_cls : String, depth : Int32 = 0) : Godot::Node?
      return nil if depth > 10 || node.pointer.null?
      return node if (node.get_class rescue "") == target_cls
      cnt = (node.call_i64("get_child_count", true) rescue (node.call_i64("get_child_count") rescue 0_i64)).to_i32
      cnt.times do |i|
        child = (node.call_obj("get_child", i.to_i64, true) rescue (node.call_obj("get_child", i.to_i64) rescue nil))
        next unless child && !child.pointer.null?
        if found = find_first_by_class(Godot::Node.new(child.pointer), target_cls, depth + 1)
          return found
        end
      end
      nil
    end

    private def find_by_name_internal(node : Godot::Node, target_name : String, depth : Int32 = 0) : Godot::Node?
      return nil if depth > 10 || node.pointer.null?
      return node if (node.call_str("get_name") rescue "") == target_name
      cnt = (node.call_i64("get_child_count", true) rescue (node.call_i64("get_child_count") rescue 0_i64)).to_i32
      cnt.times do |i|
        child = (node.call_obj("get_child", i.to_i64, true) rescue (node.call_obj("get_child", i.to_i64) rescue nil))
        next unless child && !child.pointer.null?
        if found = find_by_name_internal(Godot::Node.new(child.pointer), target_name, depth + 1)
          return found
        end
      end
      nil
    end

    private def install_hook(scd : Godot::ConfirmationDialog) : DialogHook?
      # Cleanup any stale proxy nodes left over from hot-reloads before inspecting indices
      cleanup_stale_proxies!(scd)

      grid_node = find_first_by_class(scd, "GridContainer")
      return nil unless grid_node && !grid_node.pointer.null?
      grid = Godot::GridContainer.new(grid_node.pointer)

      # Standard Godot 4.8 ShaderCreateDialog GridContainer layout:
      # [0] Label("Type:"), [1] OptionButton(type), [2] Label("Mode:"), [3] OptionButton(mode),
      # [4] Label("Template:"), [5] OptionButton(template), [6] Label("Built-in Shader:"),
      # [7] CheckBox(builtin), [8] Label("Path:"), [9] HBoxContainer(LineEdit, BrowseButton)
      gcnt = (grid.call_i64("get_child_count") rescue 0_i64).to_i32
      return nil if gcnt < 10

      c1 = grid.call_obj("get_child", 1_i64) rescue nil
      c3 = grid.call_obj("get_child", 3_i64) rescue nil
      c5 = grid.call_obj("get_child", 5_i64) rescue nil
      c7 = grid.call_obj("get_child", 7_i64) rescue nil
      c9 = grid.call_obj("get_child", 9_i64) rescue nil
      return nil unless c1 && c3 && c5 && c7 && c9
      return nil unless (c1.get_class rescue "") == "OptionButton" &&
                        (c3.get_class rescue "") == "OptionButton" &&
                        (c5.get_class rescue "") == "OptionButton" &&
                        (c7.get_class rescue "") == "CheckBox" &&
                        (c9.get_class rescue "") == "HBoxContainer"

      orig_type_ob = Godot::OptionButton.new(c1.pointer)
      orig_mode_ob = Godot::OptionButton.new(c3.pointer)
      orig_tmpl_ob = Godot::OptionButton.new(c5.pointer)
      orig_builtin_cb = Godot::CheckBox.new(c7.pointer)
      orig_path_hbox = Godot::HBoxContainer.new(c9.pointer)

      le_obj = orig_path_hbox.call_obj("get_child", 0_i64) rescue nil
      br_obj = orig_path_hbox.call_obj("get_child", 1_i64) rescue nil
      return nil unless le_obj && br_obj && (le_obj.get_class rescue "") == "LineEdit"
      orig_path_le = Godot::LineEdit.new(le_obj.pointer)
      orig_browse_btn = Godot::Button.new(br_obj.pointer)

      val_node = find_first_by_class(scd, "EditorValidationPanel")
      return nil unless val_node && !val_node.pointer.null?
      orig_val_panel = Godot::Control.new(val_node.pointer)

      ok_obj = scd.call_obj("get_ok_button") rescue nil
      return nil unless ok_obj && !ok_obj.pointer.null?
      orig_ok_btn = Godot::Button.new(ok_obj.pointer)

      # --- Build Crash-Safe Proxy Controls ---
      proxy_type_ob = Godot.create(Godot::OptionButton)
      proxy_mode_ob = Godot.create(Godot::OptionButton)
      proxy_tmpl_ob = Godot.create(Godot::OptionButton)
      proxy_path_hbox = Godot.create(Godot::HBoxContainer)
      proxy_path_le = Godot.create(Godot::LineEdit)
      proxy_browse_btn = Godot.create(Godot::Button)
      proxy_val_panel = Godot.create(Godot::PanelContainer)
      proxy_val_vbox = Godot.create(Godot::VBoxContainer)
      proxy_val_lbl1 = Godot.create(Godot::Label)
      proxy_val_lbl2 = Godot.create(Godot::Label)
      proxy_ok_btn = Godot.create(Godot::Button)

      return nil unless proxy_type_ob && proxy_mode_ob && proxy_tmpl_ob &&
                        proxy_path_hbox && proxy_path_le && proxy_browse_btn &&
                        proxy_val_panel && proxy_val_vbox && proxy_val_lbl1 && proxy_val_lbl2 && proxy_ok_btn

      proxy_type_ob.call("set_name", "CRShaderProxyTypeOption")
      proxy_type_ob.call("set_h_size_flags", 3_i64)
      proxy_type_ob.call("set_visible", false)

      proxy_mode_ob.call("set_name", "CRShaderProxyModeOption")
      proxy_mode_ob.call("set_h_size_flags", 3_i64)
      proxy_mode_ob.call("set_visible", false)
      Templates.modes.each_with_index do |m, idx|
        proxy_mode_ob.call("add_item", m.display_name, idx.to_i64)
      end

      proxy_tmpl_ob.call("set_name", "CRShaderProxyTemplateOption")
      proxy_tmpl_ob.call("set_h_size_flags", 3_i64)
      proxy_tmpl_ob.call("set_visible", false)

      proxy_path_hbox.call("set_name", "CRShaderProxyPathHBox")
      proxy_path_hbox.call("set_h_size_flags", 3_i64)
      proxy_path_hbox.call("set_visible", false)
      proxy_path_le.call("set_h_size_flags", 3_i64)
      if bicon = (orig_browse_btn.call_obj("get_button_icon") rescue nil)
        proxy_browse_btn.call("set_button_icon", bicon) if !bicon.pointer.null?
      else
        proxy_browse_btn.call("set_text", "...")
      end
      proxy_browse_btn.call("set_tooltip_text", "Select target .crshader path")
      proxy_path_hbox.call("add_child", proxy_path_le)
      proxy_path_hbox.call("add_child", proxy_browse_btn)

      # Insert proxy controls into GridContainer right next to their counterparts.
      # (`orig_type_ob` stays visible until `refresh_hook_on_open!` confirms `config()` populated its items.)
      grid.call("add_child", proxy_type_ob)
      grid.call("move_child", proxy_type_ob, (orig_type_ob.call_i64("get_index") rescue 1_i64) + 1_i64)

      grid.call("add_child", proxy_mode_ob)
      grid.call("move_child", proxy_mode_ob, (orig_mode_ob.call_i64("get_index") rescue 4_i64) + 1_i64)

      grid.call("add_child", proxy_tmpl_ob)
      grid.call("move_child", proxy_tmpl_ob, (orig_tmpl_ob.call_i64("get_index") rescue 7_i64) + 1_i64)

      grid.call("add_child", proxy_path_hbox)
      grid.call("move_child", proxy_path_hbox, (orig_path_hbox.call_i64("get_index") rescue 12_i64) + 1_i64)

      # Validation panel matching EditorValidationPanel styling
      proxy_val_panel.call("set_name", "CRShaderProxyValidationPanel")
      proxy_val_panel.call("set_visible", false)
      proxy_val_panel.call("set_custom_minimum_size", Vector2.new(0_f32, 54_f32))
      if sb = (orig_val_panel.call_obj("get_theme_stylebox", "panel") rescue nil)
        if !sb.pointer.null?
          proxy_val_panel.call("add_theme_stylebox_override", "panel", sb) rescue nil
        end
      end
      proxy_val_panel.call("add_child", proxy_val_vbox)
      proxy_val_vbox.call("add_child", proxy_val_lbl1)
      proxy_val_vbox.call("add_child", proxy_val_lbl2)
      if val_parent = (orig_val_panel.call_obj("get_parent") rescue nil)
        if !val_parent.pointer.null?
          val_parent.call("add_child", proxy_val_panel)
          val_parent.call("move_child", proxy_val_panel, (orig_val_panel.call_i64("get_index") rescue 2_i64) + 1_i64)
        end
      end

      # Proxy Create button right next to native OK button
      proxy_ok_btn.call("set_name", "CRShaderProxyOkButton")
      proxy_ok_btn.call("set_text", (orig_ok_btn.call_str("get_text") rescue "Create"))
      proxy_ok_btn.call("set_visible", false)
      if ok_parent = (orig_ok_btn.call_obj("get_parent") rescue nil)
        if !ok_parent.pointer.null?
          ok_parent.call("add_child", proxy_ok_btn)
          ok_parent.call("move_child", proxy_ok_btn, (orig_ok_btn.call_i64("get_index") rescue 1_i64) + 1_i64)
        end
      end

      hook = DialogHook.new(
        dialog: scd,
        grid: grid,
        orig_type_ob: orig_type_ob,
        orig_mode_ob: orig_mode_ob,
        orig_tmpl_ob: orig_tmpl_ob,
        orig_builtin_cb: orig_builtin_cb,
        orig_path_hbox: orig_path_hbox,
        orig_path_le: orig_path_le,
        orig_browse_btn: orig_browse_btn,
        orig_val_panel: orig_val_panel,
        orig_ok_btn: orig_ok_btn,
        proxy_type_ob: proxy_type_ob,
        proxy_mode_ob: proxy_mode_ob,
        proxy_tmpl_ob: proxy_tmpl_ob,
        proxy_path_hbox: proxy_path_hbox,
        proxy_path_le: proxy_path_le,
        proxy_browse_btn: proxy_browse_btn,
        proxy_val_panel: proxy_val_panel,
        proxy_val_lbl1: proxy_val_lbl1,
        proxy_val_lbl2: proxy_val_lbl2,
        proxy_ok_btn: proxy_ok_btn
      )

      wire_hook_signals!(hook)
      if (scd.call_bool("is_visible") rescue false)
        refresh_hook_on_open!(hook)
      end
      hook
    rescue ex
      Godot.printerr("[CRShader] Failed to hook ShaderCreateDialog: #{ex.message}")
      nil
    end

    private def wire_hook_signals!(hook : DialogHook) : Void
      hook.dialog.connect("about_to_popup") do |_args|
        refresh_hook_on_open!(hook)
      end

      hook.dialog.connect("visibility_changed") do |_args|
        if (hook.dialog.call_bool("is_visible") rescue false)
          refresh_hook_on_open!(hook)
        end
      end

      hook.proxy_type_ob.connect("item_selected") do |args|
        next if hook.suppress_signals
        idx = (args.first?.try(&.as_i) || 0).to_i32
        on_proxy_type_selected!(hook, idx)
      end

      hook.proxy_mode_ob.connect("item_selected") do |args|
        next if hook.suppress_signals
        idx = (args.first?.try(&.as_i) || 0).to_i32
        modes = Templates.modes
        if idx >= 0 && idx < modes.size
          hook.current_mode = modes[idx]
          populate_templates_for_mode!(hook, hook.current_mode)
          update_crshader_validation!(hook)
        end
      end

      hook.proxy_tmpl_ob.connect("item_selected") do |_args|
        next if hook.suppress_signals
        update_template_tooltip!(hook)
        update_crshader_validation!(hook)
      end

      hook.proxy_path_le.connect("text_changed") do |_args|
        next if hook.suppress_signals
        update_crshader_validation!(hook)
      end

      hook.proxy_path_le.connect("text_submitted") do |_args|
        if hook.crshader_active && !(hook.proxy_ok_btn.call_bool("is_disabled") rescue true)
          execute_create_crshader!(hook)
        end
      end

      hook.proxy_browse_btn.connect("pressed") do |_args|
        open_crshader_file_dialog!(hook)
      end

      hook.proxy_ok_btn.connect("pressed") do |_args|
        execute_create_crshader!(hook)
      end

      # Auto-switch into CRShader mode if the user manually types `.crshader` in native Shader mode!
      hook.orig_path_le.connect("text_changed") do |args|
        next if hook.suppress_signals || hook.crshader_active
        typed = args.first?.try(&.as_s) || (hook.orig_path_le.call_str("get_text") rescue "")
        if typed.strip.downcase.ends_with?(".crshader")
          hook.proxy_path_le.call("set_text", typed.strip)
          hook.suppress_signals = true
          hook.proxy_type_ob.call("select", hook.crshader_item_index.to_i64)
          hook.suppress_signals = false
          activate_crshader_mode!(hook, sync_path_from_orig: false)
        end
      end
    end

    # Synchronizes `proxy_type_ob` with Godot's native `orig_type_ob` whenever the dialog opens.
    def refresh_hook_on_open!(hook : DialogHook) : Void
      return unless hook.valid?
      orig_cnt = (hook.orig_type_ob.call_i64("get_item_count") rescue 0_i64).to_i32
      return if orig_cnt <= 0

      hook.suppress_signals = true
      begin
        hook.orig_type_ob.call("set_visible", false)
        hook.proxy_type_ob.call("set_visible", true)
        hook.proxy_type_ob.call("clear")
        orig_cnt.times do |i|
          txt = hook.orig_type_ob.call_str("get_item_text", i.to_i64) rescue "Shader"
          icon = hook.orig_type_ob.call_obj("get_item_icon", i.to_i64) rescue nil
          dis = hook.orig_type_ob.call_bool("is_item_disabled", i.to_i64) rescue false
          if icon && !icon.pointer.null?
            hook.proxy_type_ob.call("add_icon_item", icon, txt, i.to_i64)
          else
            hook.proxy_type_ob.call("add_item", txt, i.to_i64)
          end
          hook.proxy_type_ob.call("set_item_disabled", i.to_i64, dis)
        end

        hook.crshader_item_index = orig_cnt
        cr_icon = hook.orig_type_ob.call_obj("get_item_icon", 0_i64) rescue nil
        if cr_icon && !cr_icon.pointer.null?
          hook.proxy_type_ob.call("add_icon_item", cr_icon, "CRShader", orig_cnt.to_i64)
        else
          hook.proxy_type_ob.call("add_item", "CRShader", orig_cnt.to_i64)
        end

        orig_sel = (hook.orig_type_ob.call_i64("get_selected") rescue 0_i64).to_i32
        orig_sel = 0 if orig_sel < 0 || orig_sel >= orig_cnt
        shader_disabled = orig_cnt > 0 ? (hook.orig_type_ob.call_bool("is_item_disabled", 0_i64) rescue false) : false
        orig_path = hook.orig_path_le.call_str("get_text") rescue ""

        forced = @@force_crshader_next_open
        forced_tmpl = @@force_template_id_next_open
        @@force_crshader_next_open = false
        @@force_template_id_next_open = nil

        should_select_crshader = forced ||
                                 orig_path.downcase.ends_with?(".crshader") ||
                                 (!shader_disabled && ShaderEditorIntegration.current_tab_is_crshader?) ||
                                 (!shader_disabled && @@last_selected_was_crshader)

        if should_select_crshader
          hook.proxy_type_ob.call("select", hook.crshader_item_index.to_i64)
          activate_crshader_mode!(
            hook,
            sync_path_from_orig: true,
            auto_uniquify_default: true,
            requested_template_id: forced_tmpl,
            include_only_context: shader_disabled
          )
        else
          hook.proxy_type_ob.call("select", orig_sel.to_i64)
          deactivate_crshader_mode!(hook, native_idx: orig_sel, sync_path_to_orig: false)
        end
      ensure
        hook.suppress_signals = false
      end
    rescue
    end

    def select_crshader_in_hook!(hook : DialogHook, template_id : String? = nil) : Void
      return unless hook.valid?
      hook.suppress_signals = true
      hook.proxy_type_ob.call("select", hook.crshader_item_index.to_i64)
      hook.suppress_signals = false
      @@last_selected_was_crshader = true
      activate_crshader_mode!(hook, sync_path_from_orig: true, auto_uniquify_default: true, requested_template_id: template_id)
    end

    private def on_proxy_type_selected!(hook : DialogHook, idx : Int32) : Void
      if idx == hook.crshader_item_index
        @@last_selected_was_crshader = true
        orig_cnt = hook.crshader_item_index
        shader_disabled = orig_cnt > 0 ? (hook.orig_type_ob.call_bool("is_item_disabled", 0_i64) rescue false) : false
        activate_crshader_mode!(hook, sync_path_from_orig: !hook.crshader_active, include_only_context: shader_disabled)
      elsif idx >= 0 && idx < hook.crshader_item_index
        @@last_selected_was_crshader = false
        deactivate_crshader_mode!(hook, native_idx: idx, sync_path_to_orig: hook.crshader_active)
      end
    end

    private def activate_crshader_mode!(
      hook : DialogHook,
      sync_path_from_orig : Bool = true,
      auto_uniquify_default : Bool = false,
      requested_template_id : String? = nil,
      include_only_context : Bool = false,
    ) : Void
      hook.crshader_active = true

      # Determine initial CRShader Mode
      target_mode = hook.current_mode
      if req_id = requested_template_id
        if found = Templates.find(req_id)
          target_mode = found.mode
        end
      elsif include_only_context
        target_mode = Templates::Mode::ShaderInclude
      else
        orig_m = (hook.orig_mode_ob.call_i64("get_selected") rescue 0_i64).to_i32
        modes = Templates.modes
        if orig_m >= 0 && orig_m < 5
          target_mode = modes[orig_m]
        end
      end

      hook.current_mode = target_mode
      mode_idx = Templates.modes.index(target_mode) || 0
      hook.proxy_mode_ob.call("select", mode_idx.to_i64)
      populate_templates_for_mode!(hook, target_mode, requested_template_id)

      # Sync file path to `.crshader`
      if sync_path_from_orig
        raw_orig = (hook.orig_path_le.call_str("get_text") rescue "").strip
        converted = to_crshader_path(raw_orig, auto_uniquify_default: auto_uniquify_default)
        hook.proxy_path_le.call("set_text", converted)
      elsif (hook.proxy_path_le.call_str("get_text") rescue "").strip.empty?
        hook.proxy_path_le.call("set_text", to_crshader_path("res://new_shader.gdshader", auto_uniquify_default: true))
      end

      # Swap visible controls cleanly
      hook.orig_mode_ob.call("set_visible", false)
      hook.proxy_mode_ob.call("set_visible", true)

      hook.orig_tmpl_ob.call("set_visible", false)
      hook.proxy_tmpl_ob.call("set_visible", true)

      hook.orig_builtin_cb.call("set_pressed", false) rescue nil
      hook.orig_builtin_cb.call("set_disabled", true) rescue nil

      hook.orig_path_hbox.call("set_visible", false)
      hook.proxy_path_hbox.call("set_visible", true)

      hook.orig_val_panel.call("set_visible", false)
      hook.proxy_val_panel.call("set_visible", true)

      # Disable native OK button so C++ AcceptDialog::_ok_pressed / _text_submitted is a strict no-op
      hook.orig_ok_btn.call("set_visible", false)
      hook.orig_ok_btn.call("set_disabled", true)
      hook.proxy_ok_btn.call("set_visible", true)

      update_crshader_validation!(hook)
    end

    private def deactivate_crshader_mode!(
      hook : DialogHook,
      native_idx : Int32,
      sync_path_to_orig : Bool = true,
    ) : Void
      was_cr = hook.crshader_active
      hook.crshader_active = false

      hook.proxy_mode_ob.call("set_visible", false)
      hook.orig_mode_ob.call("set_visible", true)

      hook.proxy_tmpl_ob.call("set_visible", false)
      hook.orig_tmpl_ob.call("set_visible", true)

      hook.proxy_path_hbox.call("set_visible", false)
      hook.orig_path_hbox.call("set_visible", true)

      hook.proxy_val_panel.call("set_visible", false)
      hook.orig_val_panel.call("set_visible", true)

      hook.proxy_ok_btn.call("set_visible", false)
      hook.orig_ok_btn.call("set_visible", true)

      if sync_path_to_orig && was_cr
        cr_p = (hook.proxy_path_le.call_str("get_text") rescue "").strip
        unless cr_p.empty?
          ext = case native_idx
                when 1 then ".gdshaderinc"
                when 2 then ".tres"
                else        ".gdshader"
                end
          nat_p = cr_p.sub(/\.(crshader|gdshader|gdshaderinc|tres|glsl)$/i, "") + ext
          hook.orig_path_le.call("set_text", nat_p)
        end
      end

      if was_cr
        orig_cnt = (hook.orig_type_ob.call_i64("get_item_count") rescue 0_i64).to_i32
        if orig_cnt > 0 && native_idx >= 0 && native_idx < orig_cnt
          m_idx = Templates.modes.index(hook.current_mode) || 0
          orig_m_cnt = (hook.orig_mode_ob.call_i64("get_item_count") rescue 0_i64).to_i32
          if m_idx >= 0 && m_idx < 5 && m_idx < orig_m_cnt && native_idx != 1
            hook.orig_mode_ob.call("select", m_idx.to_i64)
            hook.orig_mode_ob.call("emit_signal", "item_selected", m_idx.to_i64) rescue nil
          end

          hook.orig_type_ob.call("select", native_idx.to_i64)
          hook.orig_type_ob.call("emit_signal", "item_selected", native_idx.to_i64) rescue nil
          cur_orig_p = hook.orig_path_le.call_str("get_text") rescue ""
          hook.orig_path_le.call("emit_signal", "text_changed", cur_orig_p) rescue nil
        end
      end
    end

    private def populate_templates_for_mode!(
      hook : DialogHook,
      mode : Templates::Mode,
      requested_template_id : String? = nil,
    ) : Void
      entries = Templates.for_mode(mode)
      hook.current_templates = entries
      hook.proxy_tmpl_ob.call("clear")

      popup = hook.proxy_tmpl_ob.call_obj("get_popup") rescue nil
      sel_idx = 0
      entries.each_with_index do |entry, idx|
        hook.proxy_tmpl_ob.call("add_item", entry.name, idx.to_i64)
        if popup && !popup.pointer.null?
          popup.call("set_item_tooltip", idx.to_i64, entry.summary) rescue nil
        end
        if req = requested_template_id
          sel_idx = idx if entry.id.downcase == req.downcase || entry.name.downcase == req.downcase
        end
      end

      hook.proxy_tmpl_ob.call("select", sel_idx.to_i64) unless entries.empty?
      update_template_tooltip!(hook)
    end

    private def selected_template(hook : DialogHook) : Templates::Entry
      idx = (hook.proxy_tmpl_ob.call_i64("get_selected") rescue 0_i64).to_i32
      if idx >= 0 && idx < hook.current_templates.size
        hook.current_templates[idx]
      else
        Templates.default_for_mode(hook.current_mode)
      end
    end

    private def update_template_tooltip!(hook : DialogHook) : Void
      tmpl = selected_template(hook)
      hook.proxy_tmpl_ob.call("set_tooltip_text", tmpl.summary) rescue nil
    end

    def to_crshader_path(raw_path : String, auto_uniquify_default : Bool = false) : String
      p = raw_path.strip.gsub('\\', '/')
      p = "res://new_shader.crshader" if p.empty? || p == "res://" || p == "res://."
      unless p.starts_with?("res://") || p.starts_with?("user://")
        p = "res://#{p.lstrip('/')}"
      end
      if p.ends_with?("/")
        p = "#{p}new_shader.crshader"
      else
        p = p.sub(/\.(crshader|gdshader|gdshaderinc|tres|res|glsl)$/i, "") + ".crshader"
      end

      if auto_uniquify_default && File.basename(p).downcase == "new_shader.crshader"
        disk = resolve_global_path(p)
        if !disk.empty? && File.exists?(disk)
          dir = File.dirname(p)
          prefix = dir == "res:" ? "res://" : "#{dir.rstrip('/')}/"
          counter = 2
          while counter < 500
            cand = "#{prefix}new_shader_#{counter}.crshader"
            cand_disk = resolve_global_path(cand)
            if cand_disk.empty? || !File.exists?(cand_disk)
              return cand
            end
            counter += 1
          end
        end
      end

      p
    end

    private def resolve_global_path(res_path : String) : String
      return "" if res_path.empty?
      if !Godot::ProjectSettings.singleton_ptr.null? && (res_path.starts_with?("res://") || res_path.starts_with?("user://"))
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        gp = ps.call_str("globalize_path", res_path).gsub('\\', '/')
        return gp unless gp.empty?
      end
      stripped = res_path.sub(/^(res|user):\/\//, "")
      File.expand_path(stripped).gsub('\\', '/')
    rescue
      ""
    end

    private def update_crshader_validation!(hook : DialogHook) : Void
      raw = (hook.proxy_path_le.call_str("get_text") rescue "").strip.gsub('\\', '/')
      ok_color = Color.new(0.45_f32, 0.94_f32, 0.56_f32, 1.0_f32)
      err_color = Color.new(1.0_f32, 0.47_f32, 0.42_f32, 1.0_f32)

      error_msg : String? = nil
      if raw.empty?
        error_msg = "Path is empty."
      elsif !raw.starts_with?("res://") && !raw.starts_with?("user://")
        error_msg = "Path must start with 'res://' or 'user://'."
      elsif !raw.downcase.ends_with?(".crshader")
        error_msg = "Invalid extension for CRShader ('.crshader' required)."
      else
        bname = File.basename(raw)
        stem = bname.sub(/\.crshader$/i, "").strip
        if stem.empty? || stem.starts_with?(".")
          error_msg = "Filename is empty."
        elsif stem.matches?(/[<>:"|?*]/)
          error_msg = "Filename contains invalid characters."
        else
          disk = resolve_global_path(raw)
          if !disk.empty? && File.exists?(disk)
            error_msg = "File already exists at '#{raw}'."
          end
        end
      end

      if err = error_msg
        hook.proxy_val_lbl1.call("set_text", "•  Invalid CRShader path.")
        hook.proxy_val_lbl1.call("add_theme_color_override", "font_color", err_color)
        hook.proxy_val_lbl2.call("set_text", "•  #{err}")
        hook.proxy_val_lbl2.call("add_theme_color_override", "font_color", err_color)
        hook.proxy_ok_btn.call("set_disabled", true)
      else
        tmpl = selected_template(hook)
        hook.proxy_val_lbl1.call("set_text", "•  CRShader path/name is valid.")
        hook.proxy_val_lbl1.call("add_theme_color_override", "font_color", ok_color)
        hook.proxy_val_lbl2.call("set_text", "•  Will create #{hook.current_mode.display_name} CRShader (#{tmpl.name}).")
        hook.proxy_val_lbl2.call("add_theme_color_override", "font_color", ok_color)
        hook.proxy_ok_btn.call("set_disabled", false)
      end
    end

    private def open_crshader_file_dialog!(hook : DialogHook) : Void
      fd = hook.proxy_file_dlg
      if fd.nil? || fd.not_nil!.pointer.null? || !Bridge.is_object_valid(fd.not_nil!.pointer)
        created = Godot.create(Godot::EditorFileDialog)
        return unless created && !created.pointer.null?
        created.call("set_name", "CRShaderProxyFileDialog")
        created.call("set_file_mode", 4_i64) # FILE_MODE_SAVE_FILE
        created.call("set_access", 0_i64)    # ACCESS_RESOURCES
        created.call("clear_filters")
        created.call("add_filter", "*.crshader ; CRShader")
        created.connect("file_selected") do |args|
          chosen = args.first?.try(&.as_s) || ""
          unless chosen.empty?
            norm = chosen.downcase.ends_with?(".crshader") ? chosen : "#{chosen}.crshader"
            hook.proxy_path_le.call("set_text", norm)
            update_crshader_validation!(hook)
          end
        end
        hook.dialog.call("add_child", created)
        hook.proxy_file_dlg = created
        fd = created
      end

      cur = (hook.proxy_path_le.call_str("get_text") rescue "res://new_shader.crshader").strip
      cur = "res://new_shader.crshader" if cur.empty?
      fd.not_nil!.call("set_current_path", cur) rescue nil
      fd.not_nil!.call("popup_file_dialog") rescue (fd.not_nil!.call("popup_centered_ratio", 0.6_f64) rescue nil)
    end

    # Materializes a new `.crshader` file from the chosen template, registers it with Godot's
    # ResourceLoader & EditorFileSystem, emits `shader_created`, and opens it in the Shader Editor.
    def create_crshader_from_template!(
      res_path : String,
      template : Templates::Entry,
      source_dialog : Godot::ConfirmationDialog? = nil,
    ) : CrShader::CRShader?
      clean_res = res_path.strip.gsub('\\', '/')
      clean_res = "#{clean_res}.crshader" unless clean_res.downcase.ends_with?(".crshader")
      disk_path = resolve_global_path(clean_res)
      return nil if disk_path.empty?

      Dir.mkdir_p(File.dirname(disk_path))
      rendered = template.render(clean_res)
      File.write(disk_path, rendered)

      # Sync sibling target immediately for ShaderInclude (.gdshaderinc) or Compute (.glsl) templates
      if template.mode == Templates::Mode::ShaderInclude || template.mode == Templates::Mode::Compute
        begin
          Compiler.new.compile_emit_targets(rendered, filename: disk_path, write_disk: true)
        rescue
        end
      end

      # Refresh EditorFileSystem so the new file is immediately visible in FileSystem dock
      if !Godot::EditorInterface.singleton_ptr.null?
        ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        if fs = (ei.call_obj("get_resource_filesystem") rescue nil)
          if !fs.pointer.null?
            fs.call("update_file", clean_res) rescue nil
            fs.call("scan_sources") rescue (fs.call("scan") rescue nil)
          end
        end
      end

      ResourceFormatLoaderCRShader.ensure_registered
      ResourceFormatSaverCRShader.ensure_registered

      cr_res : CrShader::CRShader? = nil
      if !Godot::ResourceLoader.singleton_ptr.null?
        rl = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
        loaded = rl.call_obj("load", clean_res, "", 1_i64) rescue nil
        if loaded && !loaded.pointer.null?
          if inst = Bridge.find_alive_instance(loaded.pointer)
            cr_res = inst if inst.is_a?(CrShader::CRShader)
          end
        end
      end

      if cr_res.nil?
        if fallback = Godot.create(CrShader::CRShader)
          fallback.file_path = clean_res
          fallback.set_crshader_source(rendered)
          fallback.call("take_over_path", clean_res) rescue nil
          cr_res = fallback
        end
      end

      if res = cr_res
        if !res.pointer.null? && (res.call_str("get_path") rescue "").empty?
          res.call("take_over_path", clean_res) rescue nil
        end
        res.file_path = clean_res if res.file_path.empty?
        if dlg = source_dialog
          if !dlg.pointer.null? && Bridge.is_object_valid(dlg.pointer)
            dlg.call("hide") rescue nil
            # Emit `shader_created` when creating a Shader-compatible mode so Inspector ShaderMaterial
            # slots and DocumentEditorContainer receive the CRShader resource directly!
            if template.mode != Templates::Mode::ShaderInclude
              dlg.call("emit_signal", "shader_created", res) rescue nil
            end
          end
        end
        ShaderEditorIntegration.open_shader(res)
      end

      Godot.print("[CRShader] Created new #{template.mode.display_name} shader (#{template.name}) -> #{clean_res}")
      cr_res
    rescue ex
      Godot.printerr("[CRShader] Error creating CRShader '#{res_path}': #{ex.message}")
      nil
    end

    private def execute_create_crshader!(hook : DialogHook) : Void
      update_crshader_validation!(hook)
      return if (hook.proxy_ok_btn.call_bool("is_disabled") rescue true)
      res_path = (hook.proxy_path_le.call_str("get_text") rescue "").strip
      tmpl = selected_template(hook)
      @@last_selected_was_crshader = true
      create_crshader_from_template!(res_path, tmpl, source_dialog: hook.dialog)
    end

    private def cleanup_stale_proxies!(scd : Godot::Node) : Void
      [
        "CRShaderProxyTypeOption",
        "CRShaderProxyModeOption",
        "CRShaderProxyTemplateOption",
        "CRShaderProxyPathHBox",
        "CRShaderProxyValidationPanel",
        "CRShaderProxyOkButton",
        "CRShaderProxyFileDialog",
      ].each do |pname|
        while existing = find_by_name_internal(scd, pname)
          break if existing.pointer.null?
          if parent = (existing.call_obj("get_parent") rescue nil)
            parent.call("remove_child", existing) rescue nil unless parent.pointer.null?
          end
          existing.call("free") rescue (existing.call("queue_free") rescue nil)
        end
      end
    rescue
    end

    def cleanup! : Void
      @@hooks.each_value do |hook|
        next unless !hook.dialog.pointer.null? && Bridge.is_object_valid(hook.dialog.pointer)
        hook.orig_type_ob.call("set_visible", true) rescue nil
        hook.orig_mode_ob.call("set_visible", true) rescue nil
        hook.orig_tmpl_ob.call("set_visible", true) rescue nil
        hook.orig_path_hbox.call("set_visible", true) rescue nil
        hook.orig_val_panel.call("set_visible", true) rescue nil
        hook.orig_ok_btn.call("set_visible", true) rescue nil
        hook.orig_ok_btn.call("set_disabled", false) rescue nil
        cleanup_stale_proxies!(hook.dialog)
      end
      @@hooks.clear
      @@initial_docks_hooked = false
      @@inspector_signal_hooked = false
    rescue
    end
  end
end
