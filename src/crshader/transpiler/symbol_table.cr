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
    property known_structs : Set(String) = Set(String).new
    property struct_fields : Hash(String, String) = {} of String => String

    def register_function(name : String, return_type : String)
      @function_return_types[name] = return_type
    end

    def register_struct(name : String, fields : Array(Tuple(String, String)))
      @known_structs.add(name)
      @function_return_types[name] = name
      fields.each do |fname, ftype|
        @struct_fields["#{name}.#{fname}"] = TypeInfo.resolve(ftype, @target)
      end
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
      "PI"                      => "float",
      "TAU"                     => "float",
      "E"                       => "float",
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
      "LIGHT_IS_DIRECTIONAL"    => "bool",
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
      "TRANSFORM"           => "mat4",
      "VELOCITY"            => "vec3",
      "CUSTOM"              => "vec4",
      "MASS"                => "float",
      "ACTIVE"              => "bool",
      "RESTART"             => "bool",
      "LIFETIME"            => "float",
      "DELTA"               => "float",
      "INDEX"               => "uint",
      "NUMBER"              => "uint",
      "EMISSION_TRANSFORM"  => "mat4",
      "RANDOM_SEED"         => "uint",
      "SEED"                => "uint",
      "FLAG_EMIT_POSITION"  => "bool",
      "FLAG_EMIT_ROT_SCALE" => "bool",
      "FLAG_EMIT_VELOCITY"  => "bool",
      "FLAG_EMIT_COLOR"     => "bool",
      "FLAG_EMIT_CUSTOM"    => "bool",
      "USERDATA1"           => "vec4",
      "USERDATA2"           => "vec4",
      "USERDATA3"           => "vec4",
      "USERDATA4"           => "vec4",
      "USERDATA5"           => "vec4",
      "USERDATA6"           => "vec4",
      "COLLISION_NORMAL"    => "vec3",
      "COLLISION_DEPTH"     => "float",
      "ATTRACTOR_FORCE"     => "vec3",

      # CanvasItem
      "TEXTURE"                    => "sampler2D",
      "CANVAS_MATRIX"              => "mat4",
      "SCREEN_MATRIX"              => "mat4",
      "SPECULAR_SHININESS"         => "float",
      "SPECULAR_SHININESS_TEXTURE" => "sampler2D",
      "NORMAL_TEXTURE"             => "sampler2D",

      # Spatial 4.x
      "MAIN_CAM_INV_VIEW_MATRIX" => "mat4",
      "FOG"                      => "vec4",
      "RADIANCE"                 => "vec4",
      "IRRADIANCE"               => "vec4",
      "SSS_TRANSMITTANCE_COLOR"  => "vec4",
      "SSS_TRANSMITTANCE_DEPTH"  => "float",
      "SSS_TRANSMITTANCE_BOOST"  => "float",
      "CUSTOM0"                  => "vec4",
      "CUSTOM1"                  => "vec4",
      "CUSTOM2"                  => "vec4",
      "CUSTOM3"                  => "vec4",

      # Sky
      "EYEDIR"            => "vec3",
      "SKY_COORDS"        => "vec2",
      "HALF_RES_COLOR"    => "vec4",
      "QUARTER_RES_COLOR" => "vec4",
      "LIGHT0_DIRECTION"  => "vec3",
      "LIGHT0_COLOR"      => "vec3",
      "LIGHT0_ENERGY"     => "float",
      "LIGHT0_ENABLED"    => "bool",
      "LIGHT1_DIRECTION"  => "vec3",
      "LIGHT1_COLOR"      => "vec3",
      "LIGHT1_ENERGY"     => "float",
      "LIGHT1_ENABLED"    => "bool",
      "LIGHT2_DIRECTION"  => "vec3",
      "LIGHT2_COLOR"      => "vec3",
      "LIGHT2_ENERGY"     => "float",
      "LIGHT2_ENABLED"    => "bool",
      "LIGHT3_DIRECTION"  => "vec3",
      "LIGHT3_COLOR"      => "vec3",
      "LIGHT3_ENERGY"     => "float",
      "LIGHT3_ENABLED"    => "bool",

      # Fog
      "WORLD_POSITION"  => "vec3",
      "OBJECT_POSITION" => "vec3",
      "FOG_COLOR"       => "vec4",
      "LOOKUP_COLOR"    => "vec4",
      "DENSITY"         => "float",
      "SDF"             => "float",
      "SDF_NORMAL"      => "vec3",
    }

    # Common friendly lowercase aliases mapping to Godot uppercase builtins
    GDSHADER_ALIASES = {
      "albedo"         => "ALBEDO",
      "alpha"          => "ALPHA",
      "color"          => "COLOR",
      "normal"         => "NORMAL",
      "roughness"      => "ROUGHNESS",
      "metallic"       => "METALLIC",
      "specular"       => "SPECULAR",
      "emission"       => "EMISSION",
      "time"           => "TIME",
      "vertex"         => "VERTEX",
      "position"       => "POSITION",
      "uv"             => "UV",
      "uv2"            => "UV2",
      "velocity"       => "VELOCITY",
      "transform"      => "TRANSFORM",
      "delta"          => "DELTA",
      "view"           => "VIEW",
      "depth"          => "DEPTH",
      "texture"        => "TEXTURE",
      "eyedir"         => "EYEDIR",
      "screen_uv"      => "SCREEN_UV",
      "fragcoord"      => "FRAGCOORD",
      "point_size"     => "POINT_SIZE",
      "fog"            => "FOG",
      "density"        => "DENSITY",
      "world_position" => "WORLD_POSITION",
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

      if @target.gdshader_like?
        # Only uppercase names or explicitly prefixed built-ins are treated as built-ins
        GDSHADER_BUILTINS.has_key?(clean) && (clean == clean.upcase)
      else
        GLSL_BUILTINS.has_key?(clean) || (@global_symbols.has_key?(clean) && clean == clean.upcase)
      end
    end

    def resolve_builtin_name(name : String) : String
      clean = name.sub(/^builtin_/, "")
      if @target.gdshader_like?
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
        (if @target.gdshader_like?
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
        case node.kind
        when .f32?, .f64?
          "float"
        when .u8?, .u16?, .u32?, .u64?, .u128?
          "uint"
        else
          node.value.includes?('.') ? "float" : "int"
        end
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
        if obj = node.obj
          ot = infer_type(obj)
          return "ivec4" if ot.starts_with?("isampler") || ot.starts_with?("iimage")
          return "uvec4" if ot.starts_with?("usampler") || ot.starts_with?("uimage")
          return "float" if ot.ends_with?("Shadow")
        end
        return "vec4"
      end
      if node.name == "size"
        if obj = node.obj
          return "int" if is_array?(obj)
          ot = infer_type(obj)
          return "ivec3" if ot.includes?("3D") || ot.includes?("Array")
        end
        return "ivec2"
      end
      if node.name == "to_bits_u32" && (obj = node.obj)
        return map_bitcast_type(infer_type(obj), "uint", "uvec")
      end
      if node.name == "to_bits_i32" && (obj = node.obj)
        return map_bitcast_type(infer_type(obj), "int", "ivec")
      end
      if node.name == "from_bits_f32" && (obj = node.obj)
        return map_bitcast_type(infer_type(obj), "float", "vec")
      end
      if ["==", "!=", "<", "<=", ">", ">="].includes?(node.name) && (obj = node.obj) && node.args.size == 1
        return "bool"
      end
      if ["&&", "||", "any?", "any", "all?", "all"].includes?(node.name)
        return "bool"
      end
      if ["isnan?", "isnan", "isinf?", "isinf"].includes?(node.name)
        t = (node.obj || node.args.first?).try { |n| infer_type(n) } || "float"
        return map_bitcast_type(t, "bool", "bvec")
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
      if ["-", "+", "~"].includes?(node.name) && (obj = node.obj) && node.args.empty?
        return infer_type(obj)
      end
      if ["+", "-", "*", "/", "%", "&", "|", "^", "<<", ">>"].includes?(node.name) && (obj = node.obj) && node.args.size == 1
        left_type = infer_type(obj)
        right_type = infer_type(node.args[0])
        if node.name == "*"
          return "vec4" if (left_type == "mat4" && right_type == "vec4") || (left_type == "vec4" && right_type == "mat4")
          return "vec3" if (left_type == "mat3" && right_type == "vec3") || (left_type == "vec3" && right_type == "mat3")
          return "vec2" if (left_type == "mat2" && right_type == "vec2") || (left_type == "vec2" && right_type == "mat2")
        end
        if (left_type.starts_with?("vec") || left_type.starts_with?("ivec") || left_type.starts_with?("uvec")) && ["float", "int", "uint"].includes?(right_type)
          return left_type
        elsif (right_type.starts_with?("vec") || right_type.starts_with?("ivec") || right_type.starts_with?("uvec")) && ["float", "int", "uint"].includes?(left_type)
          return right_type
        elsif left_type == "uint" || right_type == "uint"
          return "uint" if ["int", "uint"].includes?(left_type) && ["int", "uint"].includes?(right_type)
          return left_type
        else
          return left_type
        end
      end

      if node.name == "new" && (obj = node.obj)
        type_str = obj.to_s
        return TypeInfo.resolve(type_str, @target)
      end

      # Built-in constructor helpers & intrinsics
      case node.name
      when "vec2"                                                  then "vec2"
      when "vec3"                                                  then "vec3"
      when "vec4"                                                  then "vec4"
      when "bvec2"                                                 then "bvec2"
      when "bvec3"                                                 then "bvec3"
      when "bvec4"                                                 then "bvec4"
      when "color"                                                 then "vec4"
      when "mat2"                                                  then "mat2"
      when "mat3"                                                  then "mat3"
      when "mat4"                                                  then "mat4"
      when "ivec2"                                                 then "ivec2"
      when "ivec3"                                                 then "ivec3"
      when "ivec4"                                                 then "ivec4"
      when "uvec2"                                                 then "uvec2"
      when "uvec3"                                                 then "uvec3"
      when "uvec4"                                                 then "uvec4"
      when "int", "to_i", "to_i32"                                 then "int"
      when "uint", "to_u", "to_u32"                                then "uint"
      when "float", "to_f", "to_f32"                               then "float"
      when "bool", "to_b", "to_bool"                               then "bool"
      when "length", "distance", "dot", "determinant", "luminance" then "float"
      when "remap"
        "float"
      when "tile", "scroll", "offset", "rotate", "pixelate", "polar", "wave"
        "vec2"
      when "blend", "posterize", "contrast", "saturate_color", "hue_shift", "one_minus"
        if recv = node.obj
          infer_type(recv)
        else
          "vec3"
        end
      when "cross" then "vec3"
      when "texture", "textureLod", "texture_lod", "textureProj", "textureGrad", "texelFetch", "texel_fetch", "imageLoad", "image_load"
        if first_arg = node.args.first?
          st = infer_type(first_arg)
          return "ivec4" if st.starts_with?("isampler") || st.starts_with?("iimage")
          return "uvec4" if st.starts_with?("usampler") || st.starts_with?("uimage")
          return "float" if st.ends_with?("Shadow")
        end
        "vec4"
      when "textureSize", "texture_size", "imageSize", "image_size"
        if first_arg = node.args.first?
          st = infer_type(first_arg)
          return "ivec3" if st.includes?("3D") || st.includes?("Array")
        end
        "ivec2"
      when "floatBitsToUint", "float_bits_to_uint"
        map_bitcast_type(node.args.first?.try { |a| infer_type(a) } || "float", "uint", "uvec")
      when "floatBitsToInt", "float_bits_to_int"
        map_bitcast_type(node.args.first?.try { |a| infer_type(a) } || "float", "int", "ivec")
      when "uintBitsToFloat", "uint_bits_to_float", "intBitsToFloat", "int_bits_to_float"
        map_bitcast_type(node.args.first?.try { |a| infer_type(a) } || "uint", "float", "vec")
      when "normalize", "reflect", "refract", "faceforward", "clamp", "mix", "step", "smoothstep", "lerp", "saturate",
           "min", "max", "mod", "fmod", "sign", "dFdx", "dfdx", "dFdy", "dfdy", "fwidth", "roundEven", "round_even",
           "inverse", "transpose"
        if recv = node.obj || node.args.first?
          infer_type(recv)
        else
          "float"
        end
      when "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
           "pow", "exp", "exp2", "log", "log2", "sqrt", "inversesqrt", "rsqrt",
           "abs", "floor", "ceil", "fract", "frac", "rand", "round", "trunc", "radians", "degrees"
        if recv = node.obj || node.args.first?
          infer_type(recv)
        else
          "float"
        end
      else
        # 1. Check struct field access first (handles struct fields even if named x/r/a/s)
        if (obj = node.obj) && node.args.empty?
          recv_type = infer_type(obj)
          if @known_structs.includes?(recv_type)
            if st_field_type = @struct_fields["#{recv_type}.#{node.name}"]?
              return st_field_type
            end
          end
        end

        # 2. Check swizzle on vector receiver: e.g. v.xy, v.xz, v.rgb, v.rgba
        if (obj = node.obj) && node.args.empty?
          sname = node.name
          if (sname.each_char.all? { |ch| "xyzw".includes?(ch) } ||
             sname.each_char.all? { |ch| "rgba".includes?(ch) } ||
             sname.each_char.all? { |ch| "stpq".includes?(ch) }) && sname.size <= 4
            recv_type = infer_type(obj)
            is_uvec = recv_type.starts_with?("uvec") || recv_type == "uint"
            is_ivec = recv_type.starts_with?("ivec") || recv_type == "int"
            is_bvec = recv_type.starts_with?("bvec") || recv_type == "bool"
            case sname.size
            when 1 then return is_uvec ? "uint" : (is_ivec ? "int" : (is_bvec ? "bool" : "float"))
            when 2 then return is_uvec ? "uvec2" : (is_ivec ? "ivec2" : (is_bvec ? "bvec2" : "vec2"))
            when 3 then return is_uvec ? "uvec3" : (is_ivec ? "ivec3" : (is_bvec ? "bvec3" : "vec3"))
            when 4 then return is_uvec ? "uvec4" : (is_ivec ? "ivec4" : (is_bvec ? "bvec4" : "vec4"))
            end
          end
        end

        # 3. Check buffer / push_constant member field lookup (e.g. particle_buffer.positions or sim_params.gravity)
        if (obj = node.obj) && node.args.empty?
          obj_str = case obj
                    when Crystal::Var  then obj.name
                    when Crystal::Call then obj.obj.nil? && obj.args.empty? ? obj.name : nil
                    else                    nil
                    end
          if obj_str
            if field_type = lookup_type("#{obj_str}.#{node.name}")
              return field_type
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

    private def map_bitcast_type(src_type : String, scalar_target : String, vec_prefix : String) : String
      if src_type.ends_with?("2")
        "#{vec_prefix}2"
      elsif src_type.ends_with?("3")
        "#{vec_prefix}3"
      elsif src_type.ends_with?("4")
        "#{vec_prefix}4"
      else
        scalar_target
      end
    end
  end
end
