module CrShader
  enum ShaderTarget
    GDShader
    GLSL

    def self.from_string?(str : String) : ShaderTarget?
      case str.downcase
      when "gdshader", "godot"
        GDShader
      when "glsl", "compute"
        GLSL
      else
        nil
      end
    end
  end

  enum ShaderType
    Spatial
    CanvasItem
    Particles
    Sky
    Fog
    Compute

    def to_gdshader_keyword : String
      case self
      when Spatial    then "spatial"
      when CanvasItem then "canvas_item"
      when Particles  then "particles"
      when Sky        then "sky"
      when Fog        then "fog"
      when Compute    then "compute"
      else "spatial"
      end
    end

    def valid_stages : Array(String)
      case self
      when Spatial    then ["vertex", "fragment", "light"]
      when CanvasItem then ["vertex", "fragment", "light"]
      when Particles  then ["start", "process"]
      when Sky        then ["sky"]
      when Fog        then ["fog"]
      when Compute    then ["main"]
      else                 ["vertex", "fragment", "light"]
      end
    end

    def self.from_string?(str : String) : ShaderType?
      case str.downcase
      when "spatial", "3d"
        Spatial
      when "canvas_item", "canvas", "2d"
        CanvasItem
      when "particles", "particle"
        Particles
      when "sky"
        Sky
      when "fog"
        Fog
      when "compute"
        Compute
      else
        nil
      end
    end
  end

  struct TypeInfo
    getter crystal_name : String
    getter gdshader_type : String
    getter glsl_type : String

    def initialize(@crystal_name : String, @gdshader_type : String, @glsl_type : String)
    end

    PRIMITIVES = {
      "Float32"              => TypeInfo.new("Float32", "float", "float"),
      "Float"                => TypeInfo.new("Float", "float", "float"),
      "Float64"              => TypeInfo.new("Float64", "float", "float"),
      "Int32"                => TypeInfo.new("Int32", "int", "int"),
      "Int"                  => TypeInfo.new("Int", "int", "int"),
      "UInt32"               => TypeInfo.new("UInt32", "uint", "uint"),
      "UInt"                 => TypeInfo.new("UInt", "uint", "uint"),
      "Bool"                 => TypeInfo.new("Bool", "bool", "bool"),
      "Void"                 => TypeInfo.new("Void", "void", "void"),
      "Vec2"                 => TypeInfo.new("Vec2", "vec2", "vec2"),
      "Vec3"                 => TypeInfo.new("Vec3", "vec3", "vec3"),
      "Vec4"                 => TypeInfo.new("Vec4", "vec4", "vec4"),
      "Color"                => TypeInfo.new("Color", "vec4", "vec4"),
      "Mat2"                 => TypeInfo.new("Mat2", "mat2", "mat2"),
      "Mat3"                 => TypeInfo.new("Mat3", "mat3", "mat3"),
      "Mat4"                 => TypeInfo.new("Mat4", "mat4", "mat4"),
      "IVec2"                => TypeInfo.new("IVec2", "ivec2", "ivec2"),
      "IVec3"                => TypeInfo.new("IVec3", "ivec3", "ivec3"),
      "IVec4"                => TypeInfo.new("IVec4", "ivec4", "ivec4"),
      "UVec2"                => TypeInfo.new("UVec2", "uvec2", "uvec2"),
      "UVec3"                => TypeInfo.new("UVec3", "uvec3", "uvec3"),
      "UVec4"                => TypeInfo.new("UVec4", "uvec4", "uvec4"),
      "BVec2"                => TypeInfo.new("BVec2", "bvec2", "bvec2"),
      "BVec3"                => TypeInfo.new("BVec3", "bvec3", "bvec3"),
      "BVec4"                => TypeInfo.new("BVec4", "bvec4", "bvec4"),
      "Sampler2D"            => TypeInfo.new("Sampler2D", "sampler2D", "sampler2D"),
      "SamplerCube"          => TypeInfo.new("SamplerCube", "samplerCube", "samplerCube"),
      "Sampler2DArray"       => TypeInfo.new("Sampler2DArray", "sampler2DArray", "sampler2DArray"),
      "Sampler3D"            => TypeInfo.new("Sampler3D", "sampler3D", "sampler3D"),
      "Sampler2DShadow"      => TypeInfo.new("Sampler2DShadow", "sampler2DShadow", "sampler2DShadow"),
      "SamplerCubeShadow"    => TypeInfo.new("SamplerCubeShadow", "samplerCubeShadow", "samplerCubeShadow"),
      "Sampler2DArrayShadow" => TypeInfo.new("Sampler2DArrayShadow", "sampler2DArrayShadow", "sampler2DArrayShadow"),
      "ISampler2D"           => TypeInfo.new("ISampler2D", "isampler2D", "isampler2D"),
      "USampler2D"           => TypeInfo.new("USampler2D", "usampler2D", "usampler2D"),
      "ISampler3D"           => TypeInfo.new("ISampler3D", "isampler3D", "isampler3D"),
      "USampler3D"           => TypeInfo.new("USampler3D", "usampler3D", "usampler3D"),
      "ISamplerCube"         => TypeInfo.new("ISamplerCube", "isamplerCube", "isamplerCube"),
      "USamplerCube"         => TypeInfo.new("USamplerCube", "usamplerCube", "usamplerCube"),
      "Image2D"              => TypeInfo.new("Image2D", "image2D", "image2D"),
      "IImage2D"             => TypeInfo.new("IImage2D", "iimage2D", "iimage2D"),
      "UImage2D"             => TypeInfo.new("UImage2D", "uimage2D", "uimage2D"),
      "Image3D"              => TypeInfo.new("Image3D", "image3D", "image3D"),
      "SubpassInput"         => TypeInfo.new("SubpassInput", "subpassInput", "subpassInput"),
    }

    def self.resolve(name : String, target : ShaderTarget) : String
      # Handle InOut(T) and Out(T) parameter wrappers
      if name.starts_with?("InOut(") && name.ends_with?(")")
        inner = name[6..-2]
        return "inout #{resolve(inner, target)}"
      elsif name.starts_with?("Out(") && name.ends_with?(")")
        inner = name[4..-2]
        return "out #{resolve(inner, target)}"
      end

      # Handle Array(T, N) or Array(T)
      if name.starts_with?("Array(") && name.ends_with?(")")
        inner = name[6..-2].split(",").map(&.strip)
        elem_type = resolve(inner[0], target)
        if inner.size > 1
          size = inner[1]
          return "#{elem_type}[#{size}]"
        else
          return "#{elem_type}[]"
        end
      end

      if info = PRIMITIVES[name]?
        target == ShaderTarget::GDShader ? info.gdshader_type : info.glsl_type
      else
        # Fallback to direct name or preserve user-defined struct name
        name
      end
    end
  end
end
