require "lapis"
require "./crshader/compiler"

module CrShader
  include Godot

  # =============================================================================
  # CRShader - First-Class Shading Language Resource for Godot
  # =============================================================================
  # Inherits natively from Godot::Shader. Holds Crystal-based .crshader source
  # and compiles transparently in-memory into Godot's native shader bytecode.
  #
  # Can be assigned directly to ShaderMaterial, CanvasItem, MeshInstance3D, etc.
  # Does not pollute the project file structure with loose .gdshader files.
  @[Tool]
  node CRShader < Shader do
    @[Export]
    property crshader_source : String = ""

    @[Export]
    property shader_target : String = "gdshader"

    property file_path : String = ""

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def set_crshader_source(source : String) : Void
      @crshader_source = source
      recompile
    end

    def recompile : Bool
      return false if @crshader_source.strip.empty?
      begin
        target = @shader_target == "glsl" ? CrShader::ShaderTarget::GLSL : CrShader::ShaderTarget::GDShader
        compiler = CrShader::Compiler.new(target_override: target)
        transpiled = compiler.compile_source(@crshader_source, filename: @file_path)
        set_code(transpiled)
        true
      rescue ex
        Godot.printerr("[CRShader] Compilation error in #{@file_path}: #{ex.message}")
        false
      end
    end

    # Tool button: Exports compiled GDShader to disk on-demand
    @[ExportToolButton("Export to .gdshader")]
    def export_gdshader : Void
      export_to_format("gdshader")
    end

    # Tool button: Exports compiled GLSL compute shader to disk on-demand
    @[ExportToolButton("Export to .glsl")]
    def export_glsl : Void
      export_to_format("glsl")
    end

    # Tool button: Recompiles shader in-memory
    @[ExportToolButton("Recompile Shader")]
    def trigger_recompile : Void
      if recompile
        Godot.print("[CRShader] Successfully recompiled shader in-memory.")
      end
    end

    private def export_to_format(format : String) : Void
      target = format == "glsl" ? CrShader::ShaderTarget::GLSL : CrShader::ShaderTarget::GDShader
      compiler = CrShader::Compiler.new(target_override: target)
      transpiled = compiler.compile_source(@crshader_source, filename: @file_path)

      base_path = @file_path.empty? ? "res://exported_shader" : @file_path.sub(/\.crshader$/, "")
      out_ext = format == "glsl" ? ".glsl" : ".gdshader"
      out_path = "#{base_path}#{out_ext}"

      global_path = out_path
      if !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        gp = ps.call_str("globalize_path", out_path).gsub('\\', '/')
        global_path = gp unless gp.empty?
      end

      File.write(global_path, transpiled)
      Godot.print("[CRShader] Exported #{format.upcase} to #{out_path}")
    rescue ex
      Godot.printerr("[CRShader] Export #{format} failed: #{ex.message}")
    end
  end
end
