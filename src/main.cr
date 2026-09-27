require "lapis"
require "./crshader/compiler"
require "./crshader_resource"
require "./resource_format"
require "./highlighter"
require "./crshader/editor/shader_studio"
require "./crshader/editor/variable_array_control"

# =============================================================================
# CRShaderPlugin - Full-featured Godot EditorPlugin in pure Crystal
# =============================================================================
# Powered by sol-vin/lapis. The only GDScript file is `addons/crshader/plugin.gd`
# which contains `extends CrShaderPlugin`.
#
# When enabled in the Godot Editor (Project Settings -> Plugins):
# 1. Registers ResourceFormatLoaderCRShader and ResourceFormatSaverCRShader for
#    transparent in-memory loading of .crshader files into CRShader (type of Shader).
# 2. Automatically applies syntax highlighting directly in the Godot script editor
#    whenever a .crshader file is opened or edited.
# 3. Exposes inspector tool buttons on CRShader (Export to .gdshader, Export to .glsl,
#    Recompile Shader) for on-demand export without polluting the project file structure.
# 4. Optional CRShader Studio in the bottom panel for split-screen preview.
@[Tool]
node CrShaderPlugin < EditorPlugin do
  # Cache of watched files and their modification timestamps
  property file_timestamps : Hash(String, Time) = {} of String => Time
  property check_interval : Float64 = 0.5
  property time_since_last_check : Float64 = 0.0
  @studio_panel : CrShader::CrShaderStudioPanel? = nil

  def _enter_tree : Void
    Godot.print("==================================================================")
    Godot.print("  [CRShader] Crystal GDExtension EditorPlugin initialized!")
    Godot.print("==================================================================")

    # 1. Register transparent in-memory resource loader and saver
    CrShader::ResourceFormatLoaderCRShader.ensure_registered
    CrShader::ResourceFormatSaverCRShader.ensure_registered

    # 2. Hook syntax highlighting directly into Godot's script editor
    setup_editor_highlighter_hook

    # 3. Mount interactive CRShader Studio into Godot Editor bottom panel
    panel = Godot.create(CrShader::CrShaderStudioPanel)
    if panel
      call("add_control_to_bottom_panel", panel, "CRShader Studio")
      @studio_panel = panel
    end
  end


  def _exit_tree : Void
    CrShader::ResourceFormatLoaderCRShader.unregister
    CrShader::ResourceFormatSaverCRShader.unregister

    if panel = @studio_panel
      call("remove_control_from_bottom_panel", panel)
      panel.call("queue_free")
      @studio_panel = nil
    end
    Godot.print("  [CRShader] Crystal GDExtension EditorPlugin deactivated.")
  end

  # Continuous in-editor monitoring for live shader hot-reloading
  def _process(delta : Float64) : Void
    @time_since_last_check += delta
    return if @time_since_last_check < @check_interval

    @time_since_last_check = 0.0
    apply_editor_highlighter_if_needed
  end

  # Connects to Godot ScriptEditor to dynamically highlight .crshader files
  def setup_editor_highlighter_hook : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    se = ed_iface.get_script_editor
    return if se.pointer.null?

    apply_editor_highlighter_if_needed
    se.connect("editor_script_changed") do |_args|
      apply_editor_highlighter_if_needed
    end
  rescue ex
    Godot.print("[CRShader] Note: setup_editor_highlighter_hook: #{ex.message}")
  end

  # Applies syntax highlighting to the currently active .crshader editor tab
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
            edit = Godot::CodeEdit.new(base_ed.pointer)
            CrShader::Highlighter.apply_to_code_edit(edit)
          end
        end
      end
    end
  rescue
  end
end

CRShaderPlugin = CrShaderPlugin

