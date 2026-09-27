require "compiler/crystal/syntax"
require "../ast/shader_ast"

module CrShader
  module Optimizer
    # Optimizes and minifies local variable names inside functions into compact,
    # collision-free identifiers (_v0, _v1, ...) while strictly preserving all
    # outward/inward facing uniforms, varyings, built-ins, and function signatures.
    class NameOptimizer
      # Reserved keywords and built-in identifiers across GDShader & GLSL
      RESERVED_NAMES = Set{
        # Built-in variables
        "VERTEX", "POSITION", "NORMAL", "TANGENT", "BINORMAL",
        "COLOR", "UV", "UV2", "POINT_SIZE", "POINT_COORD",
        "ROUGHNESS", "METALLIC", "SPECULAR", "ALBEDO", "EMISSION",
        "FRAGCOORD", "SCREEN_UV", "TIME", "PI", "TAU",
        "INV_PROJECTION_MATRIX", "PROJECTION_MATRIX", "VIEW_MATRIX",
        "MODEL_MATRIX", "MODELVIEW_MATRIX", "MODEL_NORMAL_MATRIX",
        "TEXTURE", "TEXTURE_PIXEL_SIZE", "OUTPUT_IS_SRGB",
        "NODE_POSITION_WORLD", "CAMERA_POSITION_WORLD",
        "gl_GlobalInvocationID", "gl_LocalInvocationID", "gl_WorkGroupID",
        "gl_NumWorkGroups", "gl_WorkGroupSize",

        # GLSL & GDShader types & keywords
        "float", "int", "uint", "bool", "vec2", "vec3", "vec4",
        "ivec2", "ivec3", "ivec4", "uvec2", "uvec3", "uvec4",
        "bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4",
        "sampler2D", "sampler3D", "isampler2D", "usampler2D",
        "void", "if", "else", "for", "while", "do", "return",
        "break", "continue", "discard", "in", "out", "inout",
        "const", "uniform", "varying", "buffer", "shared",

        # Standard shader math built-ins
        "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
        "pow", "exp", "log", "exp2", "log2", "sqrt", "inversesqrt",
        "abs", "sign", "floor", "trunc", "round", "roundEven", "ceil", "fract",
        "mod", "min", "max", "clamp", "mix", "step", "smoothstep",
        "isnan", "isinf", "floatBitsToInt", "floatBitsToUint", "intBitsToFloat",
        "length", "distance", "dot", "cross", "normalize", "faceforward",
        "reflect", "refract", "matrixCompMult", "outerProduct", "transpose",
        "determinant", "inverse", "texture", "textureLod", "textureProj",
        "texelFetch", "textureSize", "imageLoad", "imageStore", "imageSize"
      }

      getter protected_names : Set(String)

      def initialize(program : ShaderProgram? = nil)
        @protected_names = Set(String).new
        @protected_names.concat(RESERVED_NAMES)

        if p = program
          p.uniforms.each { |u| @protected_names.add(u.name) }
          p.varyings.each { |v| @protected_names.add(v.name) }
          p.constants.each { |c| @protected_names.add(c.name) }
          p.buffers.each do |b|
            @protected_names.add(b.name)
            @protected_names.add(b.instance_name) unless b.instance_name.empty?
          end
          p.images.each { |i| @protected_names.add(i.name) }
          p.functions.each_key { |fn| @protected_names.add(fn) }
        end
      end

      # Optimizes all functions in a ShaderProgram
      def optimize_program(program : ShaderProgram) : ShaderProgram
        # Refresh protected globals from program
        program.uniforms.each { |u| @protected_names.add(u.name) }
        program.varyings.each { |v| @protected_names.add(v.name) }
        program.constants.each { |c| @protected_names.add(c.name) }
        program.buffers.each do |b|
          @protected_names.add(b.name)
          @protected_names.add(b.instance_name) unless b.instance_name.empty?
        end
        program.images.each { |i| @protected_names.add(i.name) }
        program.functions.each_key { |fn| @protected_names.add(fn) }

        program.functions.each do |name, def_node|
          program.functions[name] = optimize_function(def_node)
        end
        program
      end

      # Optimizes local variables within a single function
      def optimize_function(def_node : Crystal::Def) : Crystal::Def
        # Collect local assigned variables in this function
        local_names = collect_local_vars(def_node.body)
        def_node.args.each { |arg| local_names.delete(arg.name) }
        local_names.reject! do |name|
          clean_name = name.sub(/^builtin_/, "")
          name.starts_with?("builtin_") || @protected_names.includes?(name) || @protected_names.includes?(clean_name)
        end

        return def_node if local_names.empty?

        # Generate clean, collision-free identifiers: _v0, _v1, _v2, ...
        # (Guaranteed: single underscore, lowercase letter, no __, no o_123 pattern)
        mapping = {} of String => String
        counter = 0
        local_names.each do |original|
          mapping[original] = "_v#{counter}"
          counter += 1
        end

        transformer = LocalRenameTransformer.new(mapping)
        def_node.body = def_node.body.transform(transformer)
        def_node
      end

      private def collect_local_vars(node : Crystal::ASTNode) : Set(String)
        collector = LocalVarCollector.new
        node.accept(collector)
        collector.locals
      end

      # AST Visitor collecting assigned variable names
      private class LocalVarCollector < Crystal::Visitor
        getter locals : Set(String) = Set(String).new

        def visit(node : Crystal::Assign) : Bool
          if target = node.target
            if target.is_a?(Crystal::Var)
              @locals.add(target.name)
            end
          end
          true
        end

        def visit(node : Crystal::OpAssign) : Bool
          if target = node.target
            if target.is_a?(Crystal::Var)
              @locals.add(target.name)
            end
          end
          true
        end

        def visit(node : Crystal::Call) : Bool
          # Block arguments e.g. (0...4).each do |i|
          if block = node.block
            block.args.each do |arg|
              @locals.add(arg.name)
            end
          end
          true
        end

        def visit(node : Crystal::ASTNode) : Bool
          true
        end
      end

      # AST Transformer renaming local variables
      private class LocalRenameTransformer < Crystal::Transformer
        def initialize(@mapping : Hash(String, String))
        end

        def transform(node : Crystal::Var) : Crystal::ASTNode
          if new_name = @mapping[node.name]?
            Crystal::Var.new(new_name)
          else
            node
          end
        end

        def transform(node : Crystal::Call) : Crystal::ASTNode
          # Transform block arguments
          if block = node.block
            new_args = block.args.map do |arg|
              if new_name = @mapping[arg.name]?
                Crystal::Var.new(new_name)
              else
                arg
              end
            end
            block.args = new_args
          end
          super
        end
      end
    end
  end
end
