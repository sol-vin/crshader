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
  # Top-level domain-specific language (DSL) for authoring Godot shaders in Crystal.
  #
  # CrShader allows you to write Godot shaders using Crystal syntax. It is transpiled
  # at compile-time or in the Godot Editor into clean Godot GDShader or Vulkan GLSL Compute code.
  #
  # ### Basic Example
  # ```crystal
  # shader_type :canvas_item
  # render_mode :unshaded
  #
  # uniform screen_texture : Sampler2D, hint: :screen_texture, filter: :linear
  # uniform intensity : Float32 = 1.0, hint: hint_range(0.0, 5.0)
  #
  # def fragment
  #   col = screen_texture.sample(SCREEN_UV).rgb
  #   gray = luminance(col)
  #   COLOR = vec4(mix(col, vec3(gray, gray, gray), intensity), 1.0)
  # end
  # ```
  module DSL
    # Specifies the shader mode.
    #
    # Supported modes:
    # - `:spatial`: 3D spatial shader rendered on meshes and 3D scenes.
    # - `:canvas_item`: 2D canvas shader rendered on Sprite2D, Control, ColorRect, etc.
    # - `:particles`: GPU particle simulation shader.
    # - `:sky`: Background sky radiance and sun disc shader.
    # - `:fog`: Volumetric fog processing shader.
    # - `:compute`: Vulkan compute shader for GPU compute kernels.
    def shader_type(mode : Symbol) : Nil
    end

    # Specifies one or more render modes that alter how the engine renders the material.
    #
    # ### Common Spatial Render Modes:
    # - `:unshaded`: Disables all light calculations; ALBEDO is emitted directly.
    # - `:cull_disabled`: Disables face culling (renders front and back faces).
    # - `:cull_front`, `:cull_back`: Specifies polygon winding culling mode.
    # - `:blend_mix`, `:blend_add`, `:blend_sub`, `:blend_mul`: Material blending modes.
    # - `:depth_draw_opaque`, `:depth_draw_always`, `:depth_draw_never`: Depth buffer write behavior.
    #
    # ### Common CanvasItem Render Modes:
    # - `:unshaded`: Disables 2D lighting calculations.
    # - `:blend_mix`, `:blend_add`, `:blend_sub`, `:blend_mul`, `:blend_premul_alpha`: 2D blending modes.
    # - `:skip_vertex_transform`: Bypasses engine modelview transformation in vertex stage.
    def render_mode(*modes : Symbol) : Nil
    end

    # Declares a uniform variable exposed in the Godot Inspector and material properties.
    #
    # ### Parameters:
    # - `name`: The name of the uniform.
    # - `type`: Type of the uniform (`Vec2`, `Vec3`, `Vec4`, `Color`, `Float32`, `Int32`, `Sampler2D`, etc.).
    # - `hint`: Optional Godot inspector hint (`:screen_texture`, `:depth_texture`, `hint_range(min, max)`, etc.).
    # - `filter`: Texture filtering mode (`:nearest`, `:linear`, `:nearest_mipmap`, `:linear_mipmap`).
    # - `repeat`: Texture repeat mode (`:enable`, `:disable`).
    # - `group`: Inspector group title.
    # - `subgroup`: Inspector subgroup title.
    macro uniform(declaration, **options)
    end

    # Declares a varying variable passed from the vertex processor to the fragment processor.
    #
    # Interpolated smoothly across the polygon surface using perspective-correct interpolation.
    macro varying(declaration, **options)
    end

    # Declares a compile-time constant value.
    macro constant(declaration)
    end

    # Processor function executed once per vertex.
    #
    # Used to modify vertex positions, normals, tangents, and pass varyings.
    # In GDShader, vertex processors cannot use `return` statements.
    def vertex : Nil
    end

    # Processor function executed once per visible rasterized fragment (pixel).
    #
    # Used to calculate surface albedo, normals, roughness, metallic, emission, or 2D color.
    # In GDShader, fragment processors cannot use `return` statements.
    def fragment : Nil
    end

    # Processor function executed once per light source affecting the fragment.
    #
    # Used to implement custom lighting models (e.g. toon shading, anisotropic highlights).
    # In GDShader, light processors cannot use `return` statements.
    def light : Nil
    end

    # Processor function executed when a particle is spawned or restarted.
    def start : Nil
    end

    # Processor function executed on every simulation step for active particles.
    def process : Nil
    end

    # Processor function executed for sky background rendering.
    def sky : Nil
    end

    # Processor function executed for volumetric fog voxels.
    def fog : Nil
    end

    # Main compute kernel entry point for compute shaders.
    def main : Nil
    end
  end

  # Vector and matrix types used in shader programs.
  module Types
    # 2-component single-precision floating-point vector.
    struct Vec2
      property x : Float32
      property y : Float32

      def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32)
      end

      def +(other : Vec2) : Vec2; self; end
      def -(other : Vec2) : Vec2; self; end
      def *(other : Vec2 | Float32) : Vec2; self; end
      def /(other : Vec2 | Float32) : Vec2; self; end
      def - : Vec2; self; end

      def r : Float32; @x; end
      def g : Float32; @y; end
      def s : Float32; @x; end
      def t : Float32; @y; end
      def xy : Vec2; self; end
      def yx : Vec2; self; end
      def xx : Vec2; self; end
      def yy : Vec2; self; end
    end

    # 3-component single-precision floating-point vector.
    struct Vec3
      property x : Float32
      property y : Float32
      property z : Float32

      def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32)
      end

      def initialize(v2 : Vec2, @z : Float32)
        @x = v2.x
        @y = v2.y
      end

      def +(other : Vec3) : Vec3; self; end
      def -(other : Vec3) : Vec3; self; end
      def *(other : Vec3 | Float32) : Vec3; self; end
      def /(other : Vec3 | Float32) : Vec3; self; end
      def - : Vec3; self; end

      def r : Float32; @x; end
      def g : Float32; @y; end
      def b : Float32; @z; end
      def xy : Vec2; Vec2.new(@x, @y); end
      def xz : Vec2; Vec2.new(@x, @z); end
      def yz : Vec2; Vec2.new(@y, @z); end
      def rgb : Vec3; self; end
      def bgr : Vec3; self; end
      def zyx : Vec3; self; end
    end

    # 4-component single-precision floating-point vector.
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

      def +(other : Vec4) : Vec4; self; end
      def -(other : Vec4) : Vec4; self; end
      def *(other : Vec4 | Float32) : Vec4; self; end
      def /(other : Vec4 | Float32) : Vec4; self; end
      def - : Vec4; self; end

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

    # 2x2 column-major matrix.
    struct Mat2
      def initialize(col0 : Vec2, col1 : Vec2)
      end
    end

    # 3x3 column-major matrix.
    struct Mat3
      def initialize(col0 : Vec3, col1 : Vec3, col2 : Vec3)
      end
      def *(v : Vec3) : Vec3; v; end
      def *(m : Mat3) : Mat3; self; end
    end

    # 4x4 column-major matrix.
    struct Mat4
      def initialize(col0 : Vec4, col1 : Vec4, col2 : Vec4, col3 : Vec4)
      end
      def *(v : Vec4) : Vec4; v; end
      def *(m : Mat4) : Mat4; self; end
    end

    # 2-component 32-bit signed integer vector.
    struct IVec2
      property x : Int32
      property y : Int32
      def initialize(@x : Int32 = 0, @y : Int32 = 0); end
    end

    # 3-component 32-bit signed integer vector.
    struct IVec3
      property x : Int32
      property y : Int32
      property z : Int32
      def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0); end
    end

    # 4-component 32-bit signed integer vector.
    struct IVec4
      property x : Int32
      property y : Int32
      property z : Int32
      property w : Int32
      def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0, @w : Int32 = 0); end
    end

    # 2-component 32-bit unsigned integer vector.
    struct UVec2
      property x : UInt32
      property y : UInt32
      def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32); end
    end

    # 3-component 32-bit unsigned integer vector.
    struct UVec3
      property x : UInt32
      property y : UInt32
      property z : UInt32
      def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32); end
    end

    # 4-component 32-bit unsigned integer vector.
    struct UVec4
      property x : UInt32
      property y : UInt32
      property z : UInt32
      property w : UInt32
      def initialize(@x : UInt32 = 0_u32, @y : UInt32 = 0_u32, @z : UInt32 = 0_u32, @w : UInt32 = 0_u32); end
    end

    # 2D texture sampler reference.
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

    # Cubemap texture sampler reference.
    class SamplerCube
      # Samples the cubemap in direction `dir`.
      def sample(dir : Vec3) : Vec4; Vec4.new; end
      # Samples the cubemap at explicit mipmap level `lod`.
      def sample_lod(dir : Vec3, lod : Float32) : Vec4; Vec4.new; end
    end

    # 2D texture array sampler reference.
    class Sampler2DArray
      def sample(uv : Vec3) : Vec4; Vec4.new; end
      def sample_lod(uv : Vec3, lod : Float32) : Vec4; Vec4.new; end
    end

    # 3D volumetric texture sampler reference.
    class Sampler3D
      def sample(uvw : Vec3) : Vec4; Vec4.new; end
      def sample_lod(uvw : Vec3, lod : Float32) : Vec4; Vec4.new; end
    end
  end

  # Built-in shader variables provided by the Godot Engine for each shader mode and processor stage.
  module Builtins
    # Built-in variables available in 2D CanvasItem shaders (`shader_type :canvas_item`).
    module CanvasItem
      # Input vertex position in 2D space (vertex processor) or fragment position (read-only).
      VERTEX = Types::Vec2.new
      # Normalized texture coordinate (UV) in range [0.0, 1.0].
      UV = Types::Vec2.new
      # Output color for fragment stage, or vertex color in vertex stage.
      COLOR = Types::Vec4.new
      # Screen-space UV coordinate in range [0.0, 1.0] for sampling `screen_texture`.
      SCREEN_UV = Types::Vec2.new
      # Normalized point coordinate within a point sprite [0.0, 1.0].
      POINT_COORD = Types::Vec2.new
      # Size of a single pixel in the base texture: `vec2(1.0 / width, 1.0 / height)`.
      TEXTURE_PIXEL_SIZE = Types::Vec2.new
      # Size of a single pixel on the screen: `vec2(1.0 / viewport_width, 1.0 / viewport_height)`.
      SCREEN_PIXEL_SIZE = Types::Vec2.new
      # Window-relative fragment coordinates: `(x, y, z=depth, w=1/w)`.
      FRAGCOORD = Types::Vec4.new
      # Global game elapsed time in seconds.
      TIME = 0.0_f32
    end

    # Built-in variables available in 3D Spatial shaders (`shader_type :spatial`).
    module Spatial
      # Vertex position in model/view space.
      VERTEX = Types::Vec3.new
      # Normal vector perpendicular to surface in model/view space.
      NORMAL = Types::Vec3.new
      # Tangent vector orthogonal to normal in model/view space.
      TANGENT = Types::Vec3.new
      # Binormal (bitangent) vector perpendicular to normal and tangent.
      BINORMAL = Types::Vec3.new
      # Primary texture coordinates [0.0, 1.0].
      UV = Types::Vec2.new
      # Secondary texture coordinates for lightmapping or detail textures.
      UV2 = Types::Vec2.new
      # Diffuse albedo surface color in range [0.0, 1.0].
      ALBEDO = Types::Vec3.new
      # Opacity / transparency channel in range [0.0, 1.0].
      ALPHA = 1.0_f32
      # Alpha scissor threshold value for alpha-tested materials.
      ALPHA_SCISSOR_THRESHOLD = 0.5_f32
      # Surface roughness microfacet factor [0.0, 1.0]. 0 = mirror smooth, 1 = rough diffuse.
      ROUGHNESS = 1.0_f32
      # Metallic dielectric/conductor blend factor [0.0, 1.0]. 0 = dielectric, 1 = metal.
      METALLIC = 0.0_f32
      # Specular reflectivity coefficient for dielectrics (default: 0.5 = 4% reflectivity).
      SPECULAR = 0.5_f32
      # Emissive light color emitted by surface, added to scene radiance.
      EMISSION = Types::Vec3.new
      # Normal map vector unpacked from tangent space texture.
      NORMAL_MAP = Types::Vec3.new
      # Depth scale multiplier for normal map perturbation.
      NORMAL_MAP_DEPTH = 1.0_f32
      # Rim lighting intensity factor.
      RIM = 0.0_f32
      # Tint color blend for rim lighting.
      RIM_TINT = 0.5_f32
      # Secondary clearcoat specular reflection lobe intensity.
      CLEARCOAT = 0.0_f32
      # Roughness of secondary clearcoat layer.
      CLEARCOAT_ROUGHNESS = 0.0_f32
      # Anisotropic highlight direction and flow.
      ANISOTROPY = 0.0_f32
      # Anisotropic tangent flow vector.
      ANISOTROPY_FLOW = Types::Vec2.new
      # Ambient occlusion darkening factor [0.0, 1.0].
      AO = 1.0_f32
      # Subsurface scattering strength coefficient.
      SSS_STRENGTH = 0.0_f32
      # Translucent light transmission through thin backfaces.
      TRANSMISSION = Types::Vec3.new
      # Backlight illumination factor.
      BACKLIGHT = Types::Vec3.new
      # Screen-space UV coordinate in range [0.0, 1.0].
      SCREEN_UV = Types::Vec2.new
      # Window-relative fragment coordinates: `(x, y, z=depth, w=1/w)`.
      FRAGCOORD = Types::Vec4.new
      # True if the current primitive is facing towards the camera.
      FRONT_FACING = true
      # Model to world coordinate transformation matrix.
      MODEL_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # World to camera view space transformation matrix.
      VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Camera view space to clip space projection matrix.
      PROJECTION_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Combined modelview matrix: `VIEW_MATRIX * MODEL_MATRIX`.
      MODELVIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Inverse camera view matrix: transforms from camera space back to world space.
      INV_VIEW_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Inverse camera projection matrix: transforms from clip space back to view space.
      INV_PROJECTION_MATRIX = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Global game elapsed time in seconds.
      TIME = 0.0_f32
      # Normalized camera view direction in camera space.
      VIEW = Types::Vec3.new(0.0_f32, 0.0_f32, -1.0_f32)
    end

    # Built-in variables available in Particle shaders (`shader_type :particles`).
    module Particles
      # 4x4 transform matrix representing position, rotation, and scale of the particle.
      TRANSFORM = Types::Mat4.new(Types::Vec4.new, Types::Vec4.new, Types::Vec4.new, Types::Vec4.new)
      # Linear velocity vector of the particle in units per second.
      VELOCITY = Types::Vec3.new
      # 4-component custom user attribute vector associated with the particle.
      CUSTOM = Types::Vec4.new
      # Particle mass multiplier for physics and forces.
      MASS = 1.0_f32
      # True if the particle is currently active and alive in the simulation.
      ACTIVE = true
      # True on the first simulation frame when a particle is spawned or restarted.
      RESTART = false
      # Total lifetime duration of the particle in seconds.
      LIFETIME = 1.0_f32
      # Frame delta time step in seconds.
      DELTA = 0.016666_f32
      # Unique zero-based integer index of this particle instance.
      INDEX = 0_u32
      # Total count of particles in the emitter.
      NUMBER = 100_u32
      # Deterministic pseudo-random seed assigned to this particle.
      SEED = 0_u32
    end

    # Built-in variables available in Sky shaders (`shader_type :sky`).
    module Sky
      # Normalized view direction vector looking out into the sky dome.
      EYEDIR = Types::Vec3.new
      # Equirectangular spherical coordinates on the sky sphere.
      SKY_COORDS = Types::Vec2.new
      # Half-resolution background radiance sample.
      HALF_RES_COLOR = Types::Vec4.new
      # Quarter-resolution background radiance sample.
      QUARTER_RES_COLOR = Types::Vec4.new
      # Direction vector pointing towards the primary directional light (sun).
      LIGHT0_DIRECTION = Types::Vec3.new
      # Radiance color of the primary directional light.
      LIGHT0_COLOR = Types::Vec3.new
      # Energy multiplier of the primary directional light.
      LIGHT0_ENERGY = 1.0_f32
      # True if the primary directional light is enabled.
      LIGHT0_ENABLED = true
    end

    # Built-in variables available in Volumetric Fog shaders (`shader_type :fog`).
    module Fog
      # World-space coordinate of the current fog voxel.
      WORLD_POSITION = Types::Vec3.new
      # Output color and emission for the volumetric fog voxel.
      FOG_COLOR = Types::Vec4.new
      # Volumetric extinction density for the fog voxel.
      DENSITY = 0.0_f32
      # Signed distance field (SDF) distance to the nearest scene geometry.
      SDF = 0.0_f32
      # Surface normal gradient derived from the signed distance field.
      SDF_NORMAL = Types::Vec3.new
    end
  end

  # Built-in mathematical, vector, matrix, and texture sampling functions mirrored from Godot Engine docs.
  module Functions
    # Returns radians converted from degrees: `deg * (PI / 180.0)`.
    def radians(deg : Float32) : Float32; deg * 0.0174532925_f32; end
    # Returns degrees converted from radians: `rad * (180.0 / PI)`.
    def degrees(rad : Float32) : Float32; rad * 57.2957795_f32; end
    # Returns the sine of `x` (in radians).
    def sin(x : Float32) : Float32; 0.0_f32; end
    # Returns the cosine of `x` (in radians).
    def cos(x : Float32) : Float32; 1.0_f32; end
    # Returns the tangent of `x` (in radians).
    def tan(x : Float32) : Float32; 0.0_f32; end
    # Returns the arcsine of `x` in radians in the range `[-PI/2, PI/2]`.
    def asin(x : Float32) : Float32; 0.0_f32; end
    # Returns the arccosine of `x` in radians in the range `[0, PI]`.
    def acos(x : Float32) : Float32; 0.0_f32; end
    # Returns the arctangent of `y/x` in radians in the range `[-PI, PI]`.
    def atan(y : Float32, x : Float32) : Float32; 0.0_f32; end
    # Returns the arctangent of `y_over_x` in radians in the range `[-PI/2, PI/2]`.
    def atan(y_over_x : Float32) : Float32; 0.0_f32; end
    # Returns `x` raised to power `y` (x^y).
    def pow(x : Float32, y : Float32) : Float32; 1.0_f32; end
    # Returns natural exponential of `x` (e^x).
    def exp(x : Float32) : Float32; 1.0_f32; end
    # Returns natural logarithm of `x` (ln(x)).
    def log(x : Float32) : Float32; 0.0_f32; end
    # Returns base-2 exponential of `x` (2^x).
    def exp2(x : Float32) : Float32; 1.0_f32; end
    # Returns base-2 logarithm of `x` (log2(x)).
    def log2(x : Float32) : Float32; 0.0_f32; end
    # Returns square root of `x`.
    def sqrt(x : Float32) : Float32; 1.0_f32; end
    # Returns inverse square root of `x` (1.0 / sqrt(x)).
    def inversesqrt(x : Float32) : Float32; 1.0_f32; end
    # Returns the absolute value of `x`.
    def abs(x : Float32) : Float32; x >= 0 ? x : -x; end
    # Returns 1.0 if `x > 0`, 0.0 if `x == 0`, and -1.0 if `x < 0`.
    def sign(x : Float32) : Float32; x > 0 ? 1.0_f32 : (x < 0 ? -1.0_f32 : 0.0_f32); end
    # Returns the largest integer less than or equal to `x`.
    def floor(x : Float32) : Float32; 0.0_f32; end
    # Returns `x` truncated towards zero.
    def trunc(x : Float32) : Float32; 0.0_f32; end
    # Returns `x` rounded to the nearest integer.
    def round(x : Float32) : Float32; 0.0_f32; end
    # Returns the smallest integer greater than or equal to `x`.
    def ceil(x : Float32) : Float32; 0.0_f32; end
    # Returns the fractional part of `x`: `x - floor(x)`.
    def fract(x : Float32) : Float32; 0.0_f32; end
    # Returns `x` modulo `y`: `x - y * floor(x / y)`.
    def mod(x : Float32, y : Float32) : Float32; 0.0_f32; end
    # Returns the minimum of `a` and `b`.
    def min(a : Float32, b : Float32) : Float32; a < b ? a : b; end
    # Returns the maximum of `a` and `b`.
    def max(a : Float32, b : Float32) : Float32; a > b ? a : b; end
    # Clamps `x` to the range `[min_val, max_val]`.
    def clamp(x : Float32, min_val : Float32, max_val : Float32) : Float32
      x < min_val ? min_val : (x > max_val ? max_val : x)
    end
    # Performs linear interpolation between `x` and `y` using weight `a`: `x * (1 - a) + y * a`.
    def mix(x : Float32, y : Float32, a : Float32) : Float32; x * (1.0_f32 - a) + y * a; end
    # Performs linear interpolation between vector `x` and `y` using weight `a`.
    def mix(x : Types::Vec3, y : Types::Vec3, a : Float32) : Types::Vec3; x; end
    # Performs linear interpolation between vector `x` and `y` using vector weight `a`.
    def mix(x : Types::Vec3, y : Types::Vec3, a : Types::Vec3) : Types::Vec3; x; end
    # Returns 0.0 if `x < edge`, otherwise 1.0.
    def step(edge : Float32, x : Float32) : Float32; x < edge ? 0.0_f32 : 1.0_f32; end
    # Smooth Hermite interpolation between 0.0 and 1.0 when `edge0 < x < edge1`.
    def smoothstep(edge0 : Float32, edge1 : Float32, x : Float32) : Float32; 0.0_f32; end
    # Returns length (magnitude) of vector `v`: `sqrt(dot(v, v))`.
    def length(v : Types::Vec2 | Types::Vec3 | Types::Vec4) : Float32; 1.0_f32; end
    # Returns distance between points `p0` and `p1`: `length(p0 - p1)`.
    def distance(p0 : Types::Vec2 | Types::Vec3, p1 : Types::Vec2 | Types::Vec3) : Float32; 0.0_f32; end
    # Returns scalar dot product of two vectors: `sum(a[i] * b[i])`.
    def dot(a : Types::Vec2, b : Types::Vec2) : Float32; 0.0_f32; end
    def dot(a : Types::Vec3, b : Types::Vec3) : Float32; 0.0_f32; end
    def dot(a : Types::Vec4, b : Types::Vec4) : Float32; 0.0_f32; end
    # Returns 3D cross product vector of `a` and `b`: `a x b`.
    def cross(a : Types::Vec3, b : Types::Vec3) : Types::Vec3; Types::Vec3.new; end
    # Returns vector `v` scaled to unit length: `v / length(v)`.
    def normalize(v : Types::Vec2) : Types::Vec2; v; end
    def normalize(v : Types::Vec3) : Types::Vec3; v; end
    def normalize(v : Types::Vec4) : Types::Vec4; v; end
    # Calculates reflection vector for incident vector `i` against surface normal `n`: `i - 2.0 * dot(n, i) * n`.
    def reflect(i : Types::Vec3, n : Types::Vec3) : Types::Vec3; i; end
    # Calculates refraction vector for incident vector `i` through normal `n` with ratio `eta`.
    def refract(i : Types::Vec3, n : Types::Vec3, eta : Float32) : Types::Vec3; i; end
    # Transposes matrix `m`.
    def transpose(m : Types::Mat3) : Types::Mat3; m; end
    def transpose(m : Types::Mat4) : Types::Mat4; m; end
    # Calculates inverse matrix of `m`.
    def inverse(m : Types::Mat3) : Types::Mat3; m; end
    def inverse(m : Types::Mat4) : Types::Mat4; m; end
    # Calculates scalar determinant of matrix `m`.
    def determinant(m : Types::Mat3 | Types::Mat4) : Float32; 1.0_f32; end

    # Samples texture `sampler` at normalized coordinates `uv` returning RGBA vector.
    def texture(sampler : Types::Sampler2D, uv : Types::Vec2) : Types::Vec4; Types::Vec4.new; end
    # Samples texture `sampler` at normalized coordinates `uv` with explicit level-of-detail `lod`.
    def textureLod(sampler : Types::Sampler2D, uv : Types::Vec2, lod : Float32) : Types::Vec4; Types::Vec4.new; end
    # Returns texture dimensions as `ivec2(width, height)` at mipmap level `lod`.
    def textureSize(sampler : Types::Sampler2D, lod : Int32 = 0) : Types::IVec2; Types::IVec2.new; end
    # Fetches texel at integer pixel coordinates `coord` without bilinear filtering.
    def texelFetch(sampler : Types::Sampler2D, coord : Types::IVec2, lod : Int32 = 0) : Types::Vec4; Types::Vec4.new; end

    # Linearizes non-linear screen depth buffer sample to camera-space distance.
    def linear_depth(depth : Float32, inv_proj : Types::Mat4) : Float32; 1.0_f32; end
    # Calculates perceptual luminance from RGB color using ITU-R BT.709 weights (0.2126 R + 0.7152 G + 0.0722 B).
    def luminance(col : Types::Vec3) : Float32; dot(col, Types::Vec3.new(0.2126_f32, 0.7152_f32, 0.0722_f32)); end
    # Calculates barrel / pincushion lens distortion for UV coordinate.
    def barrel_distortion(uv : Types::Vec2, k : Float32) : Types::Vec2; uv; end
    # Computes smooth radial vignette factor between 0.0 (edge) and 1.0 (center).
    def vignette(uv : Types::Vec2, radius : Float32 = 0.75_f32, softness : Float32 = 0.45_f32) : Float32; 1.0_f32; end
    # Calculates power-law Fresnel reflection factor for view vector against surface normal.
    def fresnel(power : Float32, normal : Types::Vec3, view : Types::Vec3) : Float32
      pow(clamp(1.0_f32 - dot(normal, view), 0.0_f32, 1.0_f32), power)
    end
    # Fast 1D -> 1D pseudo-random hash without texture lookups.
    def hash11(p : Float32) : Float32; 0.5_f32; end
    # Fast 2D -> 1D pseudo-random hash without texture lookups.
    def hash21(p : Types::Vec2) : Float32; 0.5_f32; end
    # Fast 3D -> 1D pseudo-random hash without texture lookups.
    def hash31(p : Types::Vec3) : Float32; 0.5_f32; end
    # Fast 1D -> 2D pseudo-random hash without texture lookups.
    def hash12(p : Float32) : Types::Vec2; Types::Vec2.new(0.5_f32, 0.5_f32); end
    # Fast 2D -> 2D pseudo-random hash without texture lookups.
    def hash22(p : Types::Vec2) : Types::Vec2; Types::Vec2.new(0.5_f32, 0.5_f32); end
    # Fast 3D -> 3D pseudo-random hash without texture lookups.
    def hash33(p : Types::Vec3) : Types::Vec3; Types::Vec3.new(0.5_f32, 0.5_f32, 0.5_f32); end
    # Smooth 2D value noise interpolation.
    def value_noise(p : Types::Vec2) : Float32; 0.5_f32; end
    # Smooth 2D simplex noise gradient.
    def simplex_noise_2d(p : Types::Vec2) : Float32; 0.0_f32; end
    # Multi-octave Fractal Brownian Motion (FBM) noise.
    def fbm(p : Types::Vec2, octaves : Int32 = 4) : Float32; 0.5_f32; end

    # Shorthand constructor for 2-component vector: `vec2(x, y)`.
    def vec2(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32) : Types::Vec2; Types::Vec2.new(x, y); end
    # Shorthand constructor for 3-component vector: `vec3(x, y, z)`.
    def vec3(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32) : Types::Vec3; Types::Vec3.new(x, y, z); end
    # Shorthand constructor for 4-component vector: `vec4(x, y, z, w)`.
    def vec4(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(x, y, z, w); end
    # Shorthand constructor for 4-component vector from `vec3` and scalar `w`.
    def vec4(v3 : Types::Vec3, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(v3, w); end
    # Shorthand constructor for 2-component integer vector: `ivec2(x, y)`.
    def ivec2(x : Int32 = 0, y : Int32 = 0) : Types::IVec2; Types::IVec2.new(x, y); end
    # Shorthand constructor for 3-component integer vector: `ivec3(x, y, z)`.
    def ivec3(x : Int32 = 0, y : Int32 = 0, z : Int32 = 0) : Types::IVec3; Types::IVec3.new(x, y, z); end
    # Shorthand constructor for 4-component integer vector: `ivec4(x, y, z, w)`.
    def ivec4(x : Int32 = 0, y : Int32 = 0, z : Int32 = 0, w : Int32 = 0) : Types::IVec4; Types::IVec4.new(x, y, z, w); end
    # Shorthand constructor for 2-component unsigned integer vector: `uvec2(x, y)`.
    def uvec2(x : UInt32 = 0_u32, y : UInt32 = 0_u32) : Types::UVec2; Types::UVec2.new(x, y); end
    # Shorthand constructor for 3-component unsigned integer vector: `uvec3(x, y, z)`.
    def uvec3(x : UInt32 = 0_u32, y : UInt32 = 0_u32, z : UInt32 = 0_u32) : Types::UVec3; Types::UVec3.new(x, y, z); end
    # Shorthand constructor for 4-component unsigned integer vector: `uvec4(x, y, z, w)`.
    def uvec4(x : UInt32 = 0_u32, y : UInt32 = 0_u32, z : UInt32 = 0_u32, w : UInt32 = 0_u32) : Types::UVec4; Types::UVec4.new(x, y, z, w); end
    # Shorthand constructor for 2x2 matrix.
    def mat2(col0 : Types::Vec2, col1 : Types::Vec2) : Types::Mat2; Types::Mat2.new(col0, col1); end
    # Shorthand constructor for 3x3 matrix.
    def mat3(col0 : Types::Vec3, col1 : Types::Vec3, col2 : Types::Vec3) : Types::Mat3; Types::Mat3.new(col0, col1, col2); end
    # Shorthand constructor for 4x4 matrix.
    def mat4(col0 : Types::Vec4, col1 : Types::Vec4, col2 : Types::Vec4, col3 : Types::Vec4) : Types::Mat4; Types::Mat4.new(col0, col1, col2, col3); end
  end

  include DSL
  include Types
  include Functions
end
