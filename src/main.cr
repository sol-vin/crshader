require "lapis"
require "./crshader/compiler"
require "./crshader/editor/shader_studio"

# =============================================================================
# CrShaderPlugin - Full-featured Godot EditorPlugin in pure Crystal
# =============================================================================
# Powered by sol-vin/lapis. The only GDScript file is `addons/crshader/plugin.gd`
# which contains `extends CrShaderPlugin`.
#
# When enabled in the Godot Editor (Project Settings -> Plugins),
# CrShaderPlugin manages, monitors, and automatically compiles .crshader files
# into .gdshader (for spatial/2d/particles) and .glsl (for compute) directly
# inside the Godot Editor process without needing external CLI calls!
#
# Also provides CrShader Studio in the bottom panel with live syntax highlighting
# and split-screen compilation preview.
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
    Godot.print("  [CRShader] Scanning project and compiling .crshader files...")
    Godot.print("==================================================================")
    compile_all_crshaders

    # Mount interactive CrShader Studio into Godot Editor bottom panel
    panel = Godot.create(CrShader::CrShaderStudioPanel)
    if panel
      call("add_control_to_bottom_panel", panel, "CrShader Studio")
      @studio_panel = panel
    end
  end

  def _exit_tree : Void
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
    check_for_modified_files
  end

  # Scans project and compiles all .crshader files
  def compile_all_crshaders : Void
    compiler = CrShader::Compiler.new
    count = 0

    Dir.glob("**/*.crshader").each do |path|
      next if should_ignore_path?(path)

      if File.exists?(path)
        @file_timestamps[path] = File.info(path).modification_time
        if compile_shader(compiler, path)
          count += 1
        end
      end
    end

    Godot.print("  [CRShader] Initial compilation complete: #{count} shader(s) up to date.")
  end

  # Checks if any .crshader files were modified and recompiles them
  def check_for_modified_files : Void
    compiler = CrShader::Compiler.new

    Dir.glob("**/*.crshader").each do |path|
      next if should_ignore_path?(path)

      if File.exists?(path)
        current_time = File.info(path).modification_time
        last_time = @file_timestamps[path]?

        if last_time.nil? || current_time > last_time
          @file_timestamps[path] = current_time
          compile_shader(compiler, path)
        end
      end
    end
  end

  # Compiles a single .crshader file into .gdshader or .glsl
  def compile_shader(compiler : CrShader::Compiler, path : String) : Bool
    content = File.read(path)
    is_compute = content.includes?("shader_type :compute") || content.includes?("shader_type(\"compute\")")
    out_ext = is_compute ? ".glsl" : ".gdshader"
    out_path = path.sub(/\.crshader$/, out_ext)

    begin
      compiler.compile_file(path, out_path)
      Godot.print("  [CRShader] Recompiled #{path} -> #{out_path}")
      true
    rescue ex : CrShader::ShaderError
      Godot.print("  [CRShader:Error] #{ex.formatted_message(content.lines)}")
      false
    rescue ex
      Godot.print("  [CRShader:Error] #{path}: #{ex.message}")
      false
    end
  end

  private def should_ignore_path?(path : String) : Bool
    path.starts_with?(".godot") ||
      path.starts_with?("lib/") ||
      path.starts_with?("bin/") ||
      path.starts_with?("build/")
  end
end
