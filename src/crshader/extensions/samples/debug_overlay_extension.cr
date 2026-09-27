require "../extension"

module CrShader
  # Sample built-in extension demonstrating custom shader directives and AST transforms.
  # Adds a `debug_overlay :normals` directive that injects a debug visualization uniform
  # and snippet into the fragment stage without touching compiler internals.
  class DebugOverlayExtension < Extension
    getter name : String = "debug_overlay"
    property enabled : Bool = false
    property mode : String = "normals"

    def handle_directive(directive_name : String, call : Crystal::Call, parser : DslParser) : Bool
      return false unless directive_name == "debug_overlay"

      @enabled = true
      if arg = call.args.first?
        @mode = case arg
                when Crystal::SymbolLiteral, Crystal::StringLiteral then arg.value
                when Crystal::Var then arg.name
                else "normals"
                end
      end
      true
    end

    def transform_program(program : ShaderProgram) : Nil
      return unless @enabled

      # Inject debug uniform if not present
      has_debug_uniform = program.uniforms.any? { |u| u.name == "debug_overlay_enabled" }
      unless has_debug_uniform
        program.uniforms << UniformDecl.new(
          name: "debug_overlay_enabled",
          type_name: "Bool",
          default_value: Crystal::Parser.new("false").parse,
          group: "Debug"
        )
      end
    end
  end
end
