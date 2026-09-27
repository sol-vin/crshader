require "compiler/crystal/syntax"
require "./ast/types"
require "./ast/shader_ast"
require "./parser/dsl_parser"
require "./parser/error_formatter"
require "./validator/semantic_validator"
require "./extensions/registry"
require "./std/registry"
require "./optimizer/tree_shaker"
require "./optimizer/name_optimizer"
require "./transpiler/gdshader/emitter"
require "./transpiler/glsl/emitter"

module CrShader
  class Compiler
    property target_override : ShaderTarget? = nil
    property verbose : Bool = false
    property optimize_names : Bool = false
    property skip_validation : Bool = false
    getter last_program : ShaderProgram? = nil

    def initialize(
      @target_override : ShaderTarget? = nil,
      @verbose : Bool = false,
      @optimize_names : Bool = false,
      @skip_validation : Bool = false
    )
    end

    def compile_file(input_path : String, output_path : String? = nil) : String
      unless File.exists?(input_path)
        raise ShaderError.new("Input file not found: #{input_path}")
      end

      source = File.read(input_path)
      compiled = compile_source(source, filename: input_path)

      if output_path
        # Ensure parent directory exists
        parent_dir = File.dirname(output_path)
        Dir.mkdir_p(parent_dir) unless Dir.exists?(parent_dir)
        File.write(output_path, compiled)
      end

      compiled
    end

    def compile_source(source : String, filename : String? = nil) : String
      parser = DslParser.new(filename: filename)
      program = parser.parse(source)
      @last_program = program

      # Extension AST transformations
      Extensions.transform_program(program)

      # Semantic validation pass (early error detection)
      unless @skip_validation
        validator = Validator::SemanticValidator.new(program, filename: filename, source_lines: parser.source_lines)
        Extensions.validate(program, validator.context)
        validator.validate!
      end

      # Determine target
      target = @target_override || program.target
      program.target = target

      # Handle setup_gdshader helper defaults
      if program.setup_gdshader && target == ShaderTarget::GDShader
        apply_setup_gdshader_defaults(program)
      end

      # Set up tree shaker for stdlib and helper functions
      tree_shaker = TreeShaker.new

      # Load standard libraries if required
      program.requires.each do |req_name|
        defs = Std.load_module(req_name)
        defs.each do |d|
          tree_shaker.add_library_def(d)
        end
      end

      # Always include basic math helpers like rand() in pool
      Std.load_module("math").each do |d|
        tree_shaker.add_library_def(d)
      end

      # Also add any non-stage user functions to pool
      program.functions.each do |name, d|
        unless ["vertex", "fragment", "light", "main"].includes?(name)
          tree_shaker.add_library_def(d)
        end
      end

      # Get only alive helper functions
      alive_helpers = tree_shaker.process(program)

      # Optimize local variable names if requested
      if @optimize_names
        name_optimizer = Optimizer::NameOptimizer.new(program)
        name_optimizer.optimize_program(program)
      end

      # Emit target shader code
      io = IO::Memory.new
      case target
      when ShaderTarget::GDShader
        emitter = GDShaderEmitter.new(io, program)
        emitter.emit(alive_helpers)
      when ShaderTarget::GLSL
        emitter = GLSLEmitter.new(io, program)
        emitter.emit(alive_helpers)
      end

      io.to_s
    end

    private def apply_setup_gdshader_defaults(program : ShaderProgram)
      # If no shader_type set, default to spatial
      # setup_gdshader ensures common standard uniforms exist if not declared
      has_albedo = program.uniforms.any? { |u| u.name == "albedo" || u.name == "color" }
      unless has_albedo
        program.uniforms << UniformDecl.new(
          name: "albedo",
          type_name: "Color",
          default_value: Crystal::Parser.new("Color.new(1.0, 1.0, 1.0, 1.0)").parse,
          hints: ["source_color"]
        )
      end
    end
  end
end
