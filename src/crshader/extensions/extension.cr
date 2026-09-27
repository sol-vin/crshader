require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  # Forward declarations for validator context
  module Validator
    class ValidationContext; end
  end

  class DslParser; end

  # Abstract Extension base class.
  # Extensions allow modular additions of custom directives, AST transformations,
  # and validation rules without modifying core compiler files.
  abstract class Extension
    abstract def name : String

    # Custom top-level directives (e.g. `post_process`, `bloom_pass`, `pragma`, `debug_overlay`)
    # Return true if the directive was handled by this extension, false otherwise.
    def handle_directive(directive_name : String, call : Crystal::Call, parser : DslParser) : Bool
      false
    end

    # AST transformation pass executed before semantic validation and code generation.
    def transform_program(program : ShaderProgram) : Nil
    end

    # Custom semantic validation rules executed during Validator::SemanticValidator pass.
    def validate(program : ShaderProgram, context : Validator::ValidationContext) : Nil
    end
  end
end
