require "../ast/types"
require "../ast/shader_ast"
require "../compiler"
require "./registry"
require "../validator/semantic_validator"

module CrShader
  # High-level compilation pipeline coordinating parsing, extension transforms,
  # semantic validation, tree shaking, and code generation.
  class Pipeline
    def self.compile(
      source : String,
      filename : String? = nil,
      target_override : ShaderTarget? = nil,
      optimize_names : Bool = false,
      skip_validation : Bool = false
    ) : String
      compiler = Compiler.new(
        target_override: target_override,
        optimize_names: optimize_names,
        skip_validation: skip_validation
      )
      compiler.compile_source(source, filename: filename)
    end
  end
end
