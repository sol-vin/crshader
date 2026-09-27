require "./extension"

module CrShader
  class ExtensionRegistry
    getter extensions : Array(Extension) = [] of Extension

    def register(ext : Extension) : Extension
      # Replace if an extension with same name exists
      @extensions.reject! { |e| e.name == ext.name }
      @extensions << ext
      ext
    end

    def unregister(name : String) : Bool
      before = @extensions.size
      @extensions.reject! { |e| e.name == name }
      @extensions.size < before
    end

    def clear : Void
      @extensions.clear
    end

    def handle_directive(directive_name : String, call : Crystal::Call, parser : DslParser) : Bool
      @extensions.any? { |ext| ext.handle_directive(directive_name, call, parser) }
    end

    def transform_program(program : ShaderProgram) : Nil
      @extensions.each(&.transform_program(program))
    end

    def validate(program : ShaderProgram, context : Validator::ValidationContext) : Nil
      @extensions.each(&.validate(program, context))
    end
  end

  # Global singleton registry
  Extensions = ExtensionRegistry.new
end
