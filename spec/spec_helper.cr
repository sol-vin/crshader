require "spec"
require "../src/crshader/compiler"

module CrShader
  def self.compile(source : String, target : ShaderTarget = ShaderTarget::GDShader) : String
    compiler = Compiler.new(target_override: target)
    compiler.compile_source(source)
  end
end
