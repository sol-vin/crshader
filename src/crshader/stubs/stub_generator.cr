module CrShader
  # Generates standalone Crystal language stubs with mirrored documentation from Godot Engine
  # for IDE autocompletion, typechecking, and static API documentation generation via `lapis docs`.
  class StubGenerator
    def self.generate : String
      String.build do |io|
        io.puts <<-HEADER
# ==============================================================================
# CrShader Language Stubs & Godot Shading API Reference
# ==============================================================================
# This file provides typed Crystal language stubs and mirrored documentation from
# the Godot Engine 4.8 Shading Reference. It enables full IDE autocompletion,
# inline documentation tooltips, and static HTML manual generation via `lapis docs`.
#
# Generated automatically by `crshader stubs`. Do not edit directly.
# ==============================================================================

module CrShader
  module Language
    module PreProcessors
      def shader_type(mode : Symbol) : Nil; end
      def render_mode(*modes : Symbol) : Nil; end
      def setup_gdshader : Nil; end
      def local_size(x : Int32 = 8, y : Int32 = 8, z : Int32 = 1) : Nil; end
      macro uniform(declaration, **options); end
      macro instance_uniform(declaration, **options); end
      macro global_uniform(declaration, **options); end
      macro varying(declaration, **options); end
      macro const(declaration); end
      macro constant(declaration); end
      macro buffer(name, **options, &block); end
      macro push_constant(name, **options, &block); end
      macro shared(declaration); end
      macro image2d(name, **options); end
      def group(name : String) : Nil; end
      def subgroup(name : String) : Nil; end
      macro require(path); end
      macro include(path); end
    end

    module Stages
      def vertex(&block) : Nil; end
      def fragment(&block) : Nil; end
      def light(&block) : Nil; end
      def start(&block) : Nil; end
      def process(&block) : Nil; end
      def sky(&block) : Nil; end
      def fog(&block) : Nil; end
      def main(&block) : Nil; end
    end

    module Types
      struct Vec2
        property x : Float32, y : Float32
        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32); end
        def +(other : Vec2) : Vec2; self; end
        def -(other : Vec2) : Vec2; self; end
        def *(other : Vec2 | Float32) : Vec2; self; end
        def /(other : Vec2 | Float32) : Vec2; self; end
        def - : Vec2; self; end
        def r : Float32; @x; end; def g : Float32; @y; end
        def xy : Vec2; self; end
      end

      struct Vec3
        property x : Float32, y : Float32, z : Float32
        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32); end
        def initialize(v2 : Vec2, @z : Float32 = 0.0_f32); @x = v2.x; @y = v2.y; end
        def +(other : Vec3) : Vec3; self; end
        def -(other : Vec3) : Vec3; self; end
        def *(other : Vec3 | Float32) : Vec3; self; end
        def /(other : Vec3 | Float32) : Vec3; self; end
        def - : Vec3; self; end
        def r : Float32; @x; end; def g : Float32; @y; end; def b : Float32; @z; end
        def xy : Vec2; Vec2.new(@x, @y); end
        def rgb : Vec3; self; end
      end

      struct Vec4
        property x : Float32, y : Float32, z : Float32, w : Float32
        def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32, @w : Float32 = 1.0_f32); end
        def initialize(v3 : Vec3, @w : Float32 = 1.0_f32); @x = v3.x; @y = v3.y; @z = v3.z; end
        def +(other : Vec4) : Vec4; self; end
        def -(other : Vec4) : Vec4; self; end
        def *(other : Vec4 | Float32) : Vec4; self; end
        def /(other : Vec4 | Float32) : Vec4; self; end
        def - : Vec4; self; end
        def r : Float32; @x; end; def g : Float32; @y; end; def b : Float32; @z; end; def a : Float32; @w; end
        def xy : Vec2; Vec2.new(@x, @y); end
        def xyz : Vec3; Vec3.new(@x, @y, @z); end
        def rgb : Vec3; Vec3.new(@x, @y, @z); end
        def rgba : Vec4; self; end
      end

      struct Color
        property r : Float32, g : Float32, b : Float32, a : Float32
        def initialize(@r : Float32 = 1.0_f32, @g : Float32 = 1.0_f32, @b : Float32 = 1.0_f32, @a : Float32 = 1.0_f32); end
        def rgb : Vec3; Vec3.new(@r, @g, @b); end
        def rgba : Vec4; Vec4.new(@r, @g, @b, @a); end
      end

      struct Mat2
        def initialize(col0 : Vec2, col1 : Vec2); end
      end

      struct Mat3
        def initialize(col0 : Vec3, col1 : Vec3, col2 : Vec3); end
        def *(v : Vec3) : Vec3; v; end
      end

      struct Mat4
        def initialize(col0 : Vec4, col1 : Vec4, col2 : Vec4, col3 : Vec4); end
        def *(v : Vec4) : Vec4; v; end
        def [](col : Int32) : Vec4; Vec4.new; end
      end

      struct IVec2
        property x : Int32, y : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0); end
      end

      struct IVec3
        property x : Int32, y : Int32, z : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0); end
      end

      struct IVec4
        property x : Int32, y : Int32, z : Int32, w : Int32
        def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0, @w : Int32 = 0); end
      end

      struct UVec2
        property x : UInt32, y : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32); end
      end

      struct UVec3
        property x : UInt32, y : UInt32, z : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32); end
      end

      struct UVec4
        property x : UInt32, y : UInt32, z : UInt32, w : UInt32
        def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32, @w : UInt32 = 0_u32); end
      end

      class Sampler2D
        def sample(uv : Vec2) : Vec4; Vec4.new; end
        def sample_lod(uv : Vec2, lod : Float32) : Vec4; Vec4.new; end
        def fetch(coord : IVec2, lod : Int32 = 0) : Vec4; Vec4.new; end
        def size(lod : Int32 = 0) : IVec2; IVec2.new; end
      end

      class SamplerCube
        def sample(dir : Vec3) : Vec4; Vec4.new; end
        def sample_lod(dir : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      class Sampler2DArray
        def sample(uv : Vec3) : Vec4; Vec4.new; end
        def sample_lod(uv : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      class Sampler3D
        def sample(uvw : Vec3) : Vec4; Vec4.new; end
        def sample_lod(uvw : Vec3, lod : Float32) : Vec4; Vec4.new; end
      end

      struct InOut(T); getter value : T; def initialize(@value : T); end; end
      struct Out(T); getter value : T; def initialize(@value : T); end; end
    end

    module Builtins
      module CanvasItem
        VERTEX = Types::Vec2.new
        UV = Types::Vec2.new
        COLOR = Types::Vec4.new
        SCREEN_UV = Types::Vec2.new
        POINT_COORD = Types::Vec2.new
        TEXTURE_PIXEL_SIZE = Types::Vec2.new
        SCREEN_PIXEL_SIZE = Types::Vec2.new
        FRAGCOORD = Types::Vec4.new
        TIME = 0.0_f32
      end

      module Spatial
        VERTEX = Types::Vec3.new
        NORMAL = Types::Vec3.new
        TANGENT = Types::Vec3.new
        BINORMAL = Types::Vec3.new
        UV = Types::Vec2.new
        UV2 = Types::Vec2.new
        ALBEDO = Types::Vec3.new
        ALPHA = 1.0_f32
        ROUGHNESS = 1.0_f32
        METALLIC = 0.0_f32
        SPECULAR = 0.5_f32
        EMISSION = Types::Vec3.new
        NORMAL_MAP = Types::Vec3.new
        NORMAL_MAP_DEPTH = 1.0_f32
        RIM = 0.0_f32
        CLEARCOAT = 0.0_f32
        AO = 1.0_f32
        MODEL_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        PROJECTION_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        INV_VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        TIME = 0.0_f32
      end

      module Particles
        TRANSFORM = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
        VELOCITY = Types::Vec3.new
        CUSTOM = Types::Vec4.new
        COLOR = Types::Vec4.new
        MASS = 1.0_f32
        ACTIVE = true
        RESTART = false
        LIFETIME = 1.0_f32
        DELTA = 0.016666_f32
        INDEX = 0_u32
        NUMBER = 100_u32
        SEED = 0_u32
      end

      module Sky
        EYEDIR = Types::Vec3.new
        SKY_COORDS = Types::Vec2.new
        HALF_RES_COLOR = Types::Vec4.new
        QUARTER_RES_COLOR = Types::Vec4.new
        LIGHT0_DIRECTION = Types::Vec3.new
        LIGHT0_COLOR = Types::Vec3.new
        LIGHT0_ENERGY = 1.0_f32
        LIGHT0_ENABLED = true
        COLOR = Types::Vec3.new
      end

      module Fog
        WORLD_POSITION = Types::Vec3.new
        FOG_COLOR = Types::Vec4.new
        DENSITY = 0.0_f32
        SDF = 0.0_f32
        SDF_NORMAL = Types::Vec3.new
      end

      module Compute
        gl_GlobalInvocationID = Types::UVec3.new
        gl_LocalInvocationID = Types::UVec3.new
        gl_WorkGroupID = Types::UVec3.new
        gl_NumWorkGroups = Types::UVec3.new
        gl_LocalInvocationIndex = 0_u32
      end
    end

    module Functions
      def radians(deg : Float32) : Float32; deg * 0.0174532925_f32; end
      def degrees(rad : Float32) : Float32; rad * 57.2957795_f32; end
      def sin(x : Float32) : Float32; 0.0_f32; end
      def cos(x : Float32) : Float32; 1.0_f32; end
      def tan(x : Float32) : Float32; 0.0_f32; end
      def asin(x : Float32) : Float32; 0.0_f32; end
      def acos(x : Float32) : Float32; 0.0_f32; end
      def atan(y : Float32, x : Float32) : Float32; 0.0_f32; end
      def pow(x : Float32, y : Float32) : Float32; 1.0_f32; end
      def exp(x : Float32) : Float32; 1.0_f32; end
      def log(x : Float32) : Float32; 0.0_f32; end
      def sqrt(x : Float32) : Float32; 1.0_f32; end
      def inversesqrt(x : Float32) : Float32; 1.0_f32; end
      def abs(x : Float32) : Float32; x >= 0 ? x : -x; end
      def sign(x : Float32) : Float32; x > 0 ? 1.0_f32 : (x < 0 ? -1.0_f32 : 0.0_f32); end
      def floor(x : Float32) : Float32; 0.0_f32; end
      def ceil(x : Float32) : Float32; 0.0_f32; end
      def fract(x : Float32) : Float32; 0.0_f32; end
      def mod(x : Float32, y : Float32) : Float32; 0.0_f32; end
      def min(a : Float32, b : Float32) : Float32; a < b ? a : b; end
      def max(a : Float32, b : Float32) : Float32; a > b ? a : b; end
      def clamp(x : Float32, min_val : Float32, max_val : Float32) : Float32; x < min_val ? min_val : (x > max_val ? max_val : x); end
      def mix(x : Float32, y : Float32, a : Float32) : Float32; x * (1.0_f32 - a) + y * a; end
      def mix(x : Types::Vec3, y : Types::Vec3, a : Float32) : Types::Vec3; x; end
      def step(edge : Float32, x : Float32) : Float32; x < edge ? 0.0_f32 : 1.0_f32; end
      def smoothstep(edge0 : Float32, edge1 : Float32, x : Float32) : Float32; 0.0_f32; end

      def length(v : Types::Vec2 | Types::Vec3 | Types::Vec4) : Float32; 1.0_f32; end
      def distance(p0 : Types::Vec2 | Types::Vec3, p1 : Types::Vec2 | Types::Vec3) : Float32; 0.0_f32; end
      def dot(a : Types::Vec2, b : Types::Vec2) : Float32; 0.0_f32; end
      def dot(a : Types::Vec3, b : Types::Vec3) : Float32; 0.0_f32; end
      def dot(a : Types::Vec4, b : Types::Vec4) : Float32; 0.0_f32; end
      def cross(a : Types::Vec3, b : Types::Vec3) : Types::Vec3; Types::Vec3.new; end
      def normalize(v : Types::Vec2) : Types::Vec2; v; end
      def normalize(v : Types::Vec3) : Types::Vec3; v; end
      def normalize(v : Types::Vec4) : Types::Vec4; v; end
      def reflect(i : Types::Vec3, n : Types::Vec3) : Types::Vec3; i; end

      def texture(sampler : Types::Sampler2D, uv : Types::Vec2) : Types::Vec4; Types::Vec4.new; end
      def textureLod(sampler : Types::Sampler2D, uv : Types::Vec2, lod : Float32) : Types::Vec4; Types::Vec4.new; end
      def textureSize(sampler : Types::Sampler2D, lod : Int32 = 0) : Types::IVec2; Types::IVec2.new; end
      def texelFetch(sampler : Types::Sampler2D, coord : Types::IVec2, lod : Int32 = 0) : Types::Vec4; Types::Vec4.new; end

      def imageLoad(image : Symbol | String, coord : Types::IVec2) : Types::Vec4; Types::Vec4.new; end
      def imageStore(image : Symbol | String, coord : Types::IVec2, color : Types::Vec4) : Nil; end
      def imageSize(image : Symbol | String) : Types::IVec2; Types::IVec2.new; end

      def linear_depth(depth : Float32, inv_proj : Types::Mat4) : Float32; 1.0_f32; end
      def luminance(col : Types::Vec3) : Float32; dot(col, Types::Vec3.new(0.2126_f32, 0.7152_f32, 0.0722_f32)); end
      def fresnel(power : Float32, normal : Types::Vec3, view : Types::Vec3) : Float32; 0.0_f32; end
      def hash11(p : Float32) : Float32; 0.5_f32; end
      def value_noise(p : Types::Vec2) : Float32; 0.5_f32; end

      def vec2(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32) : Types::Vec2; Types::Vec2.new(x, y); end
      def vec3(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32) : Types::Vec3; Types::Vec3.new(x, y, z); end
      def vec4(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(x, y, z, w); end
      def vec4(v3 : Types::Vec3, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(v3, w); end
      def ivec2(x : Int32 = 0, y : Int32 = 0) : Types::IVec2; Types::IVec2.new(x, y); end
      def ivec3(x : Int32 = 0, y : Int32 = 0, z : Int32 = 0) : Types::IVec3; Types::IVec3.new(x, y, z); end
      def ivec4(x : Int32 = 0, y : Int32 = 0, z : Int32 = 0, w : Int32 = 0) : Types::IVec4; Types::IVec4.new(x, y, z, w); end
      def uvec2(x : UInt32 = 0_u32, y : UInt32 = 0_u32) : Types::UVec2; Types::UVec2.new(x, y); end
      def uvec3(x : UInt32 = 0_u32, y : UInt32 = 0_u32, z : UInt32 = 0_u32) : Types::UVec3; Types::UVec3.new(x, y, z); end
      def uvec4(x : UInt32 = 0_u32, y : UInt32 = 0_u32, z : UInt32 = 0_u32, w : UInt32 = 0_u32) : Types::UVec4; Types::UVec4.new(x, y, z, w); end
      def mat2(col0 : Types::Vec2, col1 : Types::Vec2) : Types::Mat2; Types::Mat2.new(col0, col1); end
      def mat3(col0 : Types::Vec3, col1 : Types::Vec3, col2 : Types::Vec3) : Types::Mat3; Types::Mat3.new(col0, col1, col2); end
      def mat4(col0 : Types::Vec4, col1 : Types::Vec4, col2 : Types::Vec4, col3 : Types::Vec4) : Types::Mat4; Types::Mat4.new(col0, col1, col2, col3); end
    end
  end

  # Backward compatibility modules
  module DSL
    include Language::PreProcessors
  end

  module Types
    include Language::Types
  end

  module Builtins
    include Language::Builtins
  end

  module Functions
    include Language::Functions
  end

  module Stages
    include Language::Stages
  end

  include Language::PreProcessors
  include Language::Functions
  include Language::Types
  include Language::Stages
end

CRShader = CrShader
Language = CrShader::Language
HEADER
      end
    end

    def self.write_to_file(path : String) : Nil
      File.write(path, generate)
    end
  end
end
