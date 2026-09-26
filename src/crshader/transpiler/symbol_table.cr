require "compiler/crystal/syntax"
require "../ast/types"

module CrShader
  class SymbolTable
    property target : ShaderTarget
    property global_symbols : Hash(String, String) = {} of String => String
    property current_scope_vars : Hash(String, String) = {} of String => String
    property declared_vars_in_scope : Set(String) = Set(String).new
    property referenced_functions : Set(String) = Set(String).new
    property function_return_types : Hash(String, String) = {} of String => String

    def register_function(name : String, return_type : String)
      @function_return_types[name] = return_type
    end

    # GDShader built-in variables that are already declared by Godot
    GDSHADER_BUILTINS = {
      "VERTEX"                  => "vec3",
      "POSITION"                => "vec4",
      "NORMAL"                  => "vec3",
      "TANGENT"                 => "vec3",
      "BINORMAL"                => "vec3",
      "UV"                      => "vec2",
      "UV2"                     => "vec2",
      "COLOR"                   => "vec4",
      "POINT_SIZE"              => "float",
      "ROUGHNESS"               => "float",
      "METALLIC"                => "float",
      "SPECULAR"                => "float",
      "ALBEDO"                  => "vec3",
      "ALPHA"                   => "float",
      "ALPHA_SCISSOR_THRESHOLD" => "float",
      "ALPHA_HASH_SCALE"        => "float",
      "EMISSION"                => "vec3",
      "NORMAL_MAP"              => "vec3",
      "NORMAL_MAP_DEPTH"        => "float",
      "RIM"                     => "float",
      "RIM_TINT"                => "float",
      "CLEARCOAT"               => "float",
      "CLEARCOAT_ROUGHNESS"     => "float",
      "CLEARCOAT_GLOSS"         => "float",
      "ANISOTROPY"              => "float",
      "ANISOTROPY_FLOW"         => "vec2",
      "AO"                      => "float",
      "AO_LIGHT_AFFECT"         => "float",
      "SSS_STRENGTH"            => "float",
      "TRANSMISSION"            => "vec3",
      "BACKLIGHT"               => "vec3",
      "TIME"                    => "float",
      "FRAGCOORD"               => "vec4",
      "FRONT_FACING"            => "bool",
      "POINT_COORD"             => "vec2",
      "MODEL_MATRIX"            => "mat4",
      "VIEW_MATRIX"             => "mat4",
      "PROJECTION_MATRIX"       => "mat4",
      "MODELVIEW_MATRIX"        => "mat4",
      "MODELVIEW_NORMAL_MATRIX" => "mat3",
      "INV_VIEW_MATRIX"         => "mat4",
      "INV_PROJECTION_MATRIX"   => "mat4",
      "NODE_POSITION_WORLD"     => "vec3",
      "CAMERA_POSITION_WORLD"   => "vec3",
      "CAMERA_DIRECTION_WORLD"  => "vec3",
      "SCREEN_UV"               => "vec2",
      "SCREEN_PIXEL_SIZE"       => "vec2",
      "TEXTURE_PIXEL_SIZE"      => "vec2",
      "VIEW"                    => "vec3",
      "EYE_OFFSET"              => "vec3",
      "DEPTH"                   => "float",
      "LIGHT"                   => "vec3",
      "LIGHT_COLOR"             => "vec3",
      "LIGHT_ENERGY"            => "float",
      "LIGHT_POSITION"          => "vec3",
      "LIGHT_DIRECTION"         => "vec3",
      "ATTENUATION"             => "float",
      "DIFFUSE_LIGHT"           => "vec3",
      "SPECULAR_LIGHT"          => "vec3",
      "SHADOW_MODULATE"         => "vec4",
      "SHADOW_VERTEX"           => "vec2",
      "LIGHT_VERTEX"            => "vec2",
      "AT_LIGHT_PASS"           => "bool",
      "INSTANCE_ID"             => "int",
      "INSTANCE_CUSTOM"         => "vec4",
      "BONE_INDICES"            => "uvec4",
      "BONE_WEIGHTS"            => "vec4",
      "OUTPUT_IS_SRGB"          => "bool",
      "VIEW_INDEX"              => "int",
      "VIEWPORT_SIZE"           => "vec2",
      # Particles
      "TRANSFORM"               => "mat4",
      "VELOCITY"                => "vec3",
      "CUSTOM"                  => "vec4",
      "MASS"                    => "float",
      "ACTIVE"                  => "bool",
      "RESTART"                 => "bool",
      "LIFETIME"                => "float",
      "DELTA"                   => "float",
      "INDEX"                   => "uint",
      "NUMBER"                  => "uint",
      "EMISSION_TRANSFORM"      => "mat4",
      "SEED"                    => "uint",
      # Sky
      "EYEDIR"                  => "vec3",
      "SKY_COORDS"              => "vec2",
      "HALF_RES_COLOR"          => "vec4",
      "QUARTER_RES_COLOR"       => "vec4",
      "LIGHT0_DIRECTION"        => "vec3",
      "LIGHT0_COLOR"            => "vec3",
      "LIGHT0_ENERGY"           => "float",
      "LIGHT0_ENABLED"          => "bool",
      # Fog
      "WORLD_POSITION"          => "vec3",
      "FOG_COLOR"               => "vec4",
      "DENSITY"                 => "float",
      "SDF"                     => "float",
      "SDF_NORMAL"              => "vec3",
    }

    # Common friendly lowercase aliases mapping to Godot uppercase builtins
    GDSHADER_ALIASES = {
      "albedo"    => "ALBEDO",
      "alpha"     => "ALPHA",
      "color"     => "COLOR",
      "normal"    => "NORMAL",
      "roughness" => "ROUGHNESS",
      "metallic"  => "METALLIC",
      "specular"  => "SPECULAR",
      "emission"  => "EMISSION",
      "time"      => "TIME",
      "vertex"    => "VERTEX",
      "position"  => "POSITION",
      "uv"        => "UV",
      "uv2"       => "UV2",
      "velocity"  => "VELOCITY",
      "transform" => "TRANSFORM",
      "delta"     => "DELTA",
      "view"      => "VIEW",
      "depth"     => "DEPTH",
    }

    # GLSL Compute built-ins
    GLSL_BUILTINS = {
      "gl_NumWorkGroups"        => "uvec3",
      "gl_WorkGroupSize"        => "uvec3",
      "gl_WorkGroupID"          => "uvec3",
      "gl_LocalInvocationID"    => "uvec3",
      "gl_GlobalInvocationID"   => "uvec3",
      "gl_LocalInvocationIndex" => "uint",
    }

    property shader_type : ShaderType = ShaderType::Spatial

    def initialize(@target : ShaderTarget = ShaderTarget::GDShader, @shader_type : ShaderType = ShaderType::Spatial)
    end

    def register_global(name : String, type_name : String)
      @global_symbols[name] = TypeInfo.resolve(type_name, @target)
    end

    def is_builtin?(name : String) : Bool
      clean = name.sub(/^builtin_/, "")
      if name.starts_with?("builtin_")
        return true
      end

      if @target == ShaderTarget::GDShader
        # Only uppercase names or explicitly prefixed built-ins are treated as built-ins
        GDSHADER_BUILTINS.has_key?(clean) && (clean == clean.upcase)
      else
        GLSL_BUILTINS.has_key?(clean)
      end
    end

    def resolve_builtin_name(name : String) : String
      clean = name.sub(/^builtin_/, "")
      if @target == ShaderTarget::GDShader
        # Explicit builtin assignment (e.g. ALBEDO = ...)
        if name.starts_with?("builtin_")
          return clean.upcase
        end

        # Declared uniform or local variable retains its exact identifier
        if @global_symbols.has_key?(clean) || @current_scope_vars.has_key?(clean)
          return clean
        end

        if GDSHADER_BUILTINS.has_key?(clean)
          clean
        elsif alias_name = GDSHADER_ALIASES[clean.downcase]?
          alias_name
        else
          clean
        end
      else
        clean
      end
    end

    property scope_stack : Array(Set(String)) = [Set(String).new]

    def enter_scope
      @scope_stack.push(Set(String).new)
    end

    def exit_scope
      @scope_stack.pop if @scope_stack.size > 1
    end

    def enter_function
      @scope_stack.clear
      @scope_stack.push(Set(String).new)
      @current_scope_vars.clear
      @declared_vars_in_scope.clear
    end

    def exit_function
      @scope_stack.clear
      @scope_stack.push(Set(String).new)
      @current_scope_vars.clear
      @declared_vars_in_scope.clear
    end

    def register_param(name : String, type_name : String)
      resolved = TypeInfo.resolve(type_name, @target)
      @current_scope_vars[name] = resolved
      @scope_stack.first.add(name)
    end

    def variable_declared?(name : String) : Bool
      @scope_stack.any?(&.includes?(name)) ||
        @global_symbols.has_key?(name) ||
        is_builtin?(name)
    end

    def mark_variable_declared(name : String, type_name : String)
      @current_scope_vars[name] = type_name
      @scope_stack.last.add(name)
    end

    def lookup_type(name : String) : String?
      @current_scope_vars[name]? ||
        @global_symbols[name]? ||
        (if @target == ShaderTarget::GDShader
           GDSHADER_BUILTINS[name]? || (if alias_name = GDSHADER_ALIASES[name]?
                                         GDSHADER_BUILTINS[alias_name]?
                                       end)
         else
           GLSL_BUILTINS[name]?
         end)
    end

    def is_array?(node : Crystal::ASTNode) : Bool
      case node
      when Crystal::Var
        lookup_type(node.name).try(&.includes?("[")) || false
      when Crystal::Call
        if node.obj.nil? && node.args.empty?
          lookup_type(node.name).try(&.includes?("[")) || false
        else
          infer_type(node).includes?("[")
        end
      when Crystal::ArrayLiteral
        true
      else
        infer_type(node).includes?("[")
      end
    end

    # Heuristic type inferencer from AST value
    def infer_type(node : Crystal::ASTNode) : String
      case node
      when Crystal::If
        infer_type(node.then)
      when Crystal::Expressions
        if last = node.expressions.last?
          infer_type(last)
        else
          "float"
        end
      when Crystal::ArrayLiteral
        if first = node.elements.first?
          elem = infer_type(first)
          "#{elem}[#{node.elements.size}]"
        else
          "float[0]"
        end
      when Crystal::NumberLiteral
        node.kind == :f32 || node.kind == :f64 || node.value.includes?('.') ? "float" : "int"
      when Crystal::BoolLiteral
        "bool"
      when Crystal::StringLiteral
        "string"
      when Crystal::Var
        lookup_type(node.name) || "float"
      when Crystal::Path
        name = node.names.last
        clean = name.sub(/^builtin_/, "")
        lookup_type(name) || lookup_type(clean) || "float"
      when Crystal::Call
        infer_call_type(node)
      when Crystal::And, Crystal::Or
        "bool"
      else
        "float"
      end
    end

    private def infer_call_type(node : Crystal::Call) : String
      if node.args.empty? && node.obj.nil?
        clean = node.name.sub(/^builtin_/, "")
        if t = lookup_type(node.name) || lookup_type(clean)
          return t
        end
      end

      if ret = @function_return_types[node.name]?
        return ret
      end

      if ["sample", "sample_lod", "fetch"].includes?(node.name)
        return "vec4"
      end
      if node.name == "size"
        return "ivec2"
      end
      if node.name == "[]" && (obj = node.obj)
        parent_type = infer_type(obj)
        if parent_type.includes?('[')
          return parent_type.split('[').first
        elsif parent_type.starts_with?("vec")
          return "float"
        elsif parent_type.starts_with?("ivec")
          return "int"
        elsif parent_type.starts_with?("uvec")
          return "uint"
        elsif parent_type.starts_with?("bvec")
          return "bool"
        elsif parent_type == "mat2"
          return "vec2"
        elsif parent_type == "mat3"
          return "vec3"
        elsif parent_type == "mat4"
          return "vec4"
        else
          return "float"
        end
      end
      if ["+", "-", "*", "/"].includes?(node.name) && (obj = node.obj) && node.args.size == 1
        left_type = infer_type(obj)
        right_type = infer_type(node.args[0])
        if left_type.starts_with?("vec") && right_type == "float"
          return left_type
        elsif right_type.starts_with?("vec") && left_type == "float"
          return right_type
        else
          return left_type
        end
      end

      if node.name == "new" && (obj = node.obj)
        type_str = obj.to_s
        return TypeInfo.resolve(type_str, @target)
      end

      # Built-in constructor helpers
      case node.name
      when "vec2" then "vec2"
      when "vec3" then "vec3"
      when "vec4" then "vec4"
      when "color" then @target == ShaderTarget::GDShader ? "vec4" : "vec4"
      when "mat2" then "mat2"
      when "mat3" then "mat3"
      when "mat4" then "mat4"
      when "ivec2" then "ivec2"
      when "ivec3" then "ivec3"
      when "ivec4" then "ivec4"
      when "uvec2" then "uvec2"
      when "uvec3" then "uvec3"
      when "uvec4" then "uvec4"
      when "int", "to_i", "to_i32" then "int"
      when "uint", "to_u", "to_u32" then "uint"
      when "float", "to_f", "to_f32" then "float"
      when "bool", "to_b", "to_bool" then "bool"
      when "length", "distance", "dot" then "float"
      when "cross" then "vec3"
      when "normalize", "reflect", "refract", "clamp", "mix", "step", "smoothstep", "lerp", "saturate"
        if first_arg = node.args.first?
          infer_type(first_arg)
        else
          "float"
        end
      when "sin", "cos", "tan", "pow", "exp", "sqrt", "abs", "floor", "ceil", "fract", "frac", "rand", "round", "trunc"
        if first_arg = node.args.first?
          infer_type(first_arg)
        else
          "float"
        end
      else
        # Check swizzle on receiver: e.g. v.xy, v.xz, v.rgb, v.rgba
        if (obj = node.obj) && node.args.empty?
          sname = node.name
          if (sname.each_char.all? { |ch| "xyzw".includes?(ch) } ||
              sname.each_char.all? { |ch| "rgba".includes?(ch) } ||
              sname.each_char.all? { |ch| "stpq".includes?(ch) }) && sname.size <= 4
            case sname.size
            when 1 then return "float"
            when 2 then return "vec2"
            when 3 then return "vec3"
            when 4 then return "vec4"
            end
          end
        end

        # Check receiver type if method call
        if obj = node.obj
          infer_type(obj)
        else
          "float"
        end
      end
    end
  end
end
