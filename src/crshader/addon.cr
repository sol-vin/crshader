require "lapis"
require "./compiler"
require "../crshader_resource"
require "../resource_format"
require "../highlighter"
require "./compositor/compositor_effect_base"
require "./editor/shader_studio"
require "./editor/shader_editor_integration"
require "./editor/variable_array_control"

# =============================================================================
# CRShaderPlugin - Godot 4.8 EditorPlugin & Shader Editor Tab Integration
# =============================================================================
# Can be compiled either standalone (`addons/crshader/bin/game.dll`) or directly
# into a host Lapis project (`require "crshader/addon"` in `src/main.cr`).
@[Tool]
node CrShaderPlugin < EditorPlugin do
  property check_interval : Float64 = 0.35
  property time_since_last_check : Float64 = 0.0
  @host_editor_plugin : Godot::Object? = nil

  def set_host_editor_plugin(plugin : Godot::Object?) : Void
    @host_editor_plugin = plugin
  end

  def effective_editor_plugin : Godot::Object
    if hp = @host_editor_plugin
      return hp if !hp.pointer.null? && Godot::Bridge.is_object_valid(hp.pointer)
    end
    self
  end

  def _enter_tree : Void
    Godot.print("==================================================================")
    Godot.print("  [CRShader] Crystal GDExtension EditorPlugin initialized!")
    Godot.print("==================================================================")

    CrShader::ResourceFormatLoaderCRShader.ensure_registered
    CrShader::ResourceFormatSaverCRShader.ensure_registered

    setup_editor_highlighter_hook
    set_process(true)
  end

  def _exit_tree : Void
    CrShader::ShaderEditorIntegration.cleanup!
    CrShader::ResourceFormatLoaderCRShader.unregister
    CrShader::ResourceFormatSaverCRShader.unregister
    Godot.print("  [CRShader] Crystal GDExtension EditorPlugin deactivated.")
  end

  def _process(delta : Float64) : Void
    @time_since_last_check += delta
    return if @time_since_last_check < @check_interval

    @time_since_last_check = 0.0
    apply_editor_highlighter_if_needed
    CrShader::ShaderEditorIntegration.sync_shader_tabs!
  end

  # Invoked by `addons/crshader/plugin.gd` (`_handles`) and GDExtension `_handles` virtual.
  def handles_object(object : Godot::Object?) : Bool
    return false unless object && !object.pointer.null? && Godot::Bridge.is_object_valid(object.pointer)
    if inst = Godot::Bridge.find_alive_instance(object.pointer)
      return true if inst.is_a?(CrShader::CRShader)
    end
    cls = object.get_class rescue ""
    return true if cls == "CRShader"
    if object.is_class("Resource")
      rpath = object.call_str("get_path") rescue ""
      return true if rpath.downcase.ends_with?(".crshader")
    end
    false
  rescue
    false
  end

  # Invoked by `addons/crshader/plugin.gd` (`_edit`) and GDExtension `_edit` virtual.
  def edit_object(object : Godot::Object?) : Void
    return unless object && !object.pointer.null? && Godot::Bridge.is_object_valid(object.pointer)
    if inst = Godot::Bridge.find_alive_instance(object.pointer)
      if inst.is_a?(CrShader::CRShader)
        CrShader::ShaderEditorIntegration.open_shader(inst, effective_editor_plugin)
        return
      end
    end
    if object.is_class("Resource")
      rpath = object.call_str("get_path") rescue ""
      if rpath.downcase.ends_with?(".crshader")
        CrShader::ShaderEditorIntegration.open_shader(rpath, effective_editor_plugin)
      end
    end
  rescue ex
    Godot.printerr("[CRShader] edit_object error: #{ex.message}")
  end

  def make_shader_editor_visible(visible : Bool) : Void
    if visible
      CrShader::ShaderEditorIntegration.reveal_shader_editor_dock!(effective_editor_plugin)
    end
  end

  def save_open_shaders : Void
    CrShader::ShaderEditorIntegration.save_all_open_shaders!
  end

  def self._godot_has_virtual_method(method_name : String) : Bool
    case method_name
    when "_handles", "handles",
         "_edit", "edit",
         "_make_visible", "make_visible",
         "_save_external_data", "save_external_data",
         "_apply_changes", "apply_changes"
      true
    else
      false
    end
  end

  def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
    case method_name
    when "_handles", "handles"
      return if ret.null?
      obj_ptr = (!args.null? && !args[0].null?) ? args[0].as(Void**).value : Pointer(Void).null
      handled = obj_ptr.null? ? false : handles_object(Godot::Object.new(obj_ptr))
      ret.as(UInt8*).value = handled ? 1_u8 : 0_u8
    when "_edit", "edit"
      obj_ptr = (!args.null? && !args[0].null?) ? args[0].as(Void**).value : Pointer(Void).null
      edit_object(Godot::Object.new(obj_ptr)) unless obj_ptr.null?
    when "_make_visible", "make_visible"
      vis = !args.null? && !args[0].null? && (args[0].as(UInt8*).value != 0_u8)
      make_shader_editor_visible(vis)
    when "_save_external_data", "save_external_data", "_apply_changes", "apply_changes"
      save_open_shaders
    else
      super
    end
  end

  # Connects to Godot ScriptEditor to dynamically highlight .crshader files if opened as text
  def setup_editor_highlighter_hook : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    se = ed_iface.get_script_editor
    return if se.pointer.null?

    apply_editor_highlighter_if_needed
    se.connect("editor_script_changed") do |_args|
      apply_editor_highlighter_if_needed
    end
  rescue
  end

  def apply_editor_highlighter_if_needed : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    se = ed_iface.get_script_editor
    return if se.pointer.null?

    curr_script = se.get_current_script
    if curr_script && !curr_script.pointer.null?
      path = curr_script.call_str("get_path")
      path = curr_script.call_str("get_resource_path") if path.empty?
      if path.downcase.ends_with?(".crshader")
        curr_ed = se.call_obj("get_current_editor")
        if curr_ed && !curr_ed.pointer.null?
          base_ed = curr_ed.call_obj("get_base_editor")
          if base_ed && !base_ed.pointer.null?
            existing_hl = base_ed.call_obj("get_syntax_highlighter") rescue nil
            existing_cls = (existing_hl && !existing_hl.pointer.null?) ? (existing_hl.get_class rescue "") : ""
            if existing_cls != "CrShaderSyntaxHighlighter"
              edit = Godot::CodeEdit.new(base_ed.pointer)
              CrShader::Highlighter.apply_to_code_edit(edit)
            end
          end
        end
      end
    end
  rescue
  end
end

CRShaderPlugin = CrShaderPlugin
