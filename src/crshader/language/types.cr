# ==============================================================================
# CrShader Language: Data Types & Samplers Reference
# ==============================================================================

module CrShader
  module Language
    # Shading language vector, matrix, sampler, color, and qualifier types.
    #
    # Provides fully typed Crystal representations for shader primitive types with
    # swizzle accessors, arithmetic operators, texture sampling methods, and parameter qualifiers.
    module Types
      # 2-component single-precision floating-point vector (`vec2`).
      struct Vec2
        property x : Float32
        property y : Float32

        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32)
        end

        def self.new(x : Number, y : Number)
          new(x.to_f32, y.to_f32)
        end

        def +(other : Vec2) : Vec2; self; end
        def -(other : Vec2) : Vec2; self; end
        def *(other : Vec2 | Float32) : Vec2; self; end
        def /(other : Vec2 | Float32) : Vec2; self; end
        def - : Vec2; self; end

        # Component swizzles
        def r : Float32; @x; end
        def g : Float32; @y; end
        def s : Float32; @x; end
        def t : Float32; @y; end
        def xy : Vec2; self; end
        def yx : Vec2; Vec2.new(@y, @x); end
        def xx : Vec2; Vec2.new(@x, @x); end
        def yy : Vec2; Vec2.new(@y, @y); end
      end

      # 3-component single-precision floating-point vector (`vec3`).
      struct Vec3
        property x : Float32
        property y : Float32
        property z : Float32

        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32)
        end

        def initialize(v2 : Vec2, @z : Float32 = 0.0_f32)
          @x = v2.x
          @y = v2.y
        end

        def self.new(x : Number, y : Number, z : Number)
          new(x.to_f32, y.to_f32, z.to_f32)
        end

        def +(other : Vec3) : Vec3; self; end
        def -(other : Vec3) : Vec3; self; end
        def *(other : Vec3 | Float32) : Vec3; self; end
        def /(other : Vec3 | Float32) : Vec3; self; end
        def - : Vec3; self; end

        # Component swizzles
        def r : Float32; @x; end
        def g : Float32; @y; end
        def b : Float32; @z; end
        def xy : Vec2; Vec2.new(@x, @y); end
        def xz : Vec2; Vec2.new(@x, @z); end
        def yz : Vec2; Vec2.new(@y, @z); end
        def rgb : Vec3; self; end
        def bgr : Vec3; Vec3.new(@z, @y, @x); end
        def zyx : Vec3; Vec3.new(@z, @y, @x); end
        def yzx : Vec3; Vec3.new(@y, @z, @x); end
      end

      # 4-component single-precision floating-point vector (`vec4`).
      struct Vec4
        property x : Float32
        property y : Float32
        property z : Float32
        property w : Float32

        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32, @w : Float32 = 1.0_f32)
        end

        def initialize(v3 : Vec3, @w : Float32 = 1.0_f32)
          @x = v3.x; @y = v3.y; @z = v3.z
        end

        def self.new(x : Number, y : Number, z : Number, w : Number = 1.0)
          new(x.to_f32, y.to_f32, z.to_f32, w.to_f32)
        end

        def +(other : Vec4) : Vec4; self; end
        def -(other : Vec4) : Vec4; self; end
        def *(other : Vec4 | Float32) : Vec4; self; end
        def /(other : Vec4 | Float32) : Vec4; self; end
        def - : Vec4; self; end

        # Component swizzles
        def r : Float32; @x; end
        def g : Float32; @y; end
        def b : Float32; @z; end
        def a : Float32; @w; end
        def xy : Vec2; Vec2.new(@x, @y); end
        def zw : Vec2; Vec2.new(@z, @w); end
        def xyz : Vec3; Vec3.new(@x, @y, @z); end
        def rgb : Vec3; Vec3.new(@x, @y, @z); end
        def rgba : Vec4; self; end
      end

      # 4-component RGBA color struct.
      struct Color
        property r : Float32
        property g : Float32
        property b : Float32
        property a : Float32

        def initialize(@r : Float32 = 1.0_f32, @g : Float32 = 1.0_f32, @b : Float32 = 1.0_f32, @a : Float32 = 1.0_f32)
        end

        def self.new(r : Number, g : Number, b : Number, a : Number = 1.0)
          new(r.to_f32, g.to_f32, b.to_f32, a.to_f32)
        end

        def rgb : Vec3; Vec3.new(@r, @g, @b); end
        def rgba : Vec4; Vec4.new(@r, @g, @b, @a); end
      end

      # 2x2 column-major matrix (`mat2`).
      struct Mat2
        def initialize(col0 : Vec2, col1 : Vec2)
        end
      end

      # 3x3 column-major matrix (`mat3`).
      struct Mat3
        def initialize(col0 : Vec3, col1 : Vec3, col2 : Vec3)
        end
        def *(v : Vec3) : Vec3; v; end
        def *(m : Mat3) : Mat3; self; end
      end

      # 4x4 column-major matrix (`mat4`).
      struct Mat4
        def initialize(col0 : Vec4, col1 : Vec4, col2 : Vec4, col3 : Vec4)
        end
        def *(v : Vec4) : Vec4; v; end
        def *(m : Mat4) : Mat4; self; end
        def [](col : Int32) : Vec4; Vec4.new; end
      end

      # 2-component 32-bit signed integer vector (`ivec2`).
      struct IVec2
        property x : Int32
        property y : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0); end
        def +(other : IVec2) : IVec2; self; end
        def -(other : IVec2) : IVec2; self; end
      end

      # 3-component 32-bit signed integer vector (`ivec3`).
      struct IVec3
        property x : Int32
        property y : Int32
        property z : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0); end
      end

      # 4-component 32-bit signed integer vector (`ivec4`).
      struct IVec4
        property x : Int32
        property y : Int32
        property z : Int32
        property w : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0, @w : Int32 = 0); end
      end

      # 2-component 32-bit unsigned integer vector (`uvec2`).
      struct UVec2
        property x : UInt32
        property y : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32); end
      end

      # 3-component 32-bit unsigned integer vector (`uvec3`).
      struct UVec3
        property x : UInt32
        property y : UInt32
        property z : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32); end
      end

      # 4-component 32-bit unsigned integer vector (`uvec4`).
      struct UVec4
        property x : UInt32
        property y : UInt32
        property z : UInt32
        property w : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32, @w : UInt32 = 0_u32); end
      end

      # 2D texture sampler reference (`sampler2D`).
      class Sampler2D
        # Samples the texture at normalized coordinates `uv`, returning an RGBA vector.
        def sample(uv : Vec2) : Vec4; Vec4.new; end
        # Samples the texture at explicit mipmap level of detail `lod`.
        def sample_lod(uv : Vec2, lod : Float32) : Vec4; Vec4.new; end
        # Fetches texel at integer pixel coordinates without bilinear filtering.
        def fetch(coord : IVec2, lod : Int32 = 0) : Vec4; Vec4.new; end
        # Returns dimensions of the texture at mipmap level `lod` as `ivec2(width, height)`.
        def size(lod : Int32 = 0) : IVec2; IVec2.new; end
      end

      # Cubemap texture sampler reference (`samplerCube`).
      class SamplerCube
        # Samples the cubemap in direction `dir`.
        def sample(dir : Vec3) : Vec4; Vec4.new; end
        # Samples the cubemap at explicit mipmap level `lod`.
        def sample_lod(dir : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      # 2D texture array sampler reference (`sampler2DArray`).
      class Sampler2DArray
        def sample(uv : Vec3) : Vec4; Vec4.new; end
        def sample_lod(uv : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      # 3D volumetric texture sampler reference (`sampler3D`).
      class Sampler3D
        def sample(uvw : Vec3) : Vec4; Vec4.new; end
        def sample_lod(uvw : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      # In-out parameter qualifier wrapper (`inout`).
      struct InOut(T)
        getter value : T
        def initialize(@value : T); end
      end

      # Output-only parameter qualifier wrapper (`out`).
      struct Out(T)
        getter value : T
        def initialize(@value : T); end
      end
    end
  end
end
