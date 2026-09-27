# ==============================================================================
# CrShader Language: Functions & Built-in Operations Reference
# ==============================================================================

module CrShader
  module Language
    # Built-in mathematical, geometric, matrix, texture, compute, and standard library functions.
    #
    # Mirrored directly from the Godot Engine 4.8 Shading Language specification.
    # All methods transpile 1:1 to hardware-accelerated GPU intrinsic operations.
    module Functions
      extend self
      # Converts degrees to radians: `deg * (PI / 180.0)`.
      def radians(deg : Float32) : Float32; deg * 0.0174532925_f32; end
      # Converts radians to degrees: `rad * (180.0 / PI)`.
      def degrees(rad : Float32) : Float32; rad * 57.2957795_f32; end
      # Returns the sine of `x` (in radians).
      def sin(x : Float32) : Float32; 0.0_f32; end
      # Returns the cosine of `x` (in radians).
      def cos(x : Float32) : Float32; 1.0_f32; end
      # Returns the tangent of `x` (in radians).
      def tan(x : Float32) : Float32; 0.0_f32; end
      # Returns the arcsine of `x` in radians in range `[-PI/2, PI/2]`.
      def asin(x : Float32) : Float32; 0.0_f32; end
      # Returns the arccosine of `x` in radians in range `[0, PI]`.
      def acos(x : Float32) : Float32; 0.0_f32; end
      # Returns the arctangent of `y/x` in radians in range `[-PI, PI]`.
      def atan(y : Float32, x : Float32) : Float32; 0.0_f32; end
      # Returns the arctangent of `y_over_x` in radians in range `[-PI/2, PI/2]`.
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
      # Returns inverse square root of `x` (`1.0 / sqrt(x)`).
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
      # Clamps `x` to range `[min_val, max_val]`.
      def clamp(x : Float32, min_val : Float32, max_val : Float32) : Float32
        x < min_val ? min_val : (x > max_val ? max_val : x)
      end
      # Linear interpolation between `x` and `y` using weight `a`: `x * (1 - a) + y * a`.
      def mix(x : Float32, y : Float32, a : Float32) : Float32; x * (1.0_f32 - a) + y * a; end
      def mix(x : Types::Vec2, y : Types::Vec2, a : Float32) : Types::Vec2; x; end
      def mix(x : Types::Vec3, y : Types::Vec3, a : Float32) : Types::Vec3; x; end
      def mix(x : Types::Vec4, y : Types::Vec4, a : Float32) : Types::Vec4; x; end
      def mix(x : Types::Vec3, y : Types::Vec3, a : Types::Vec3) : Types::Vec3; x; end
      # Returns 0.0 if `x < edge`, otherwise 1.0.
      def step(edge : Float32, x : Float32) : Float32; x < edge ? 0.0_f32 : 1.0_f32; end
      # Smooth Hermite interpolation between 0.0 and 1.0 when `edge0 < x < edge1`.
      def smoothstep(edge0 : Float32, edge1 : Float32, x : Float32) : Float32; 0.0_f32; end

      # Returns vector magnitude / length: `sqrt(dot(v, v))`.
      def length(v : Types::Vec2 | Types::Vec3 | Types::Vec4) : Float32; 1.0_f32; end
      # Returns Euclidean distance between points `p0` and `p1`: `length(p0 - p1)`.
      def distance(p0 : Types::Vec2 | Types::Vec3, p1 : Types::Vec2 | Types::Vec3) : Float32; 0.0_f32; end
      # Returns scalar dot product: `sum(a[i] * b[i])`.
      def dot(a : Types::Vec2, b : Types::Vec2) : Float32; 0.0_f32; end
      def dot(a : Types::Vec3, b : Types::Vec3) : Float32; 0.0_f32; end
      def dot(a : Types::Vec4, b : Types::Vec4) : Float32; 0.0_f32; end
      # Returns 3D cross product: `a x b`.
      def cross(a : Types::Vec3, b : Types::Vec3) : Types::Vec3; Types::Vec3.new; end
      # Returns vector `v` scaled to unit length: `v / length(v)`.
      def normalize(v : Types::Vec2) : Types::Vec2; v; end
      def normalize(v : Types::Vec3) : Types::Vec3; v; end
      def normalize(v : Types::Vec4) : Types::Vec4; v; end
      # Calculates reflection vector for incident `i` against surface normal `n`: `i - 2.0 * dot(n, i) * n`.
      def reflect(i : Types::Vec3, n : Types::Vec3) : Types::Vec3; i; end
      # Calculates refraction vector for incident `i` through normal `n` with refraction index ratio `eta`.
      def refract(i : Types::Vec3, n : Types::Vec3, eta : Float32) : Types::Vec3; i; end
      # Orients vector `n` to face away from a surface based on incident vector `i` and reference normal `nref`.
      def faceforward(n : Types::Vec3, i : Types::Vec3, nref : Types::Vec3) : Types::Vec3; n; end

      # Transposes matrix `m`.
      def transpose(m : Types::Mat3) : Types::Mat3; m; end
      def transpose(m : Types::Mat4) : Types::Mat4; m; end
      # Calculates inverse matrix of `m`.
      def inverse(m : Types::Mat3) : Types::Mat3; m; end
      def inverse(m : Types::Mat4) : Types::Mat4; m; end
      # Calculates scalar determinant of matrix `m`.
      def determinant(m : Types::Mat3 | Types::Mat4) : Float32; 1.0_f32; end

      # Samples texture `sampler` at normalized coordinates `uv`, returning an RGBA vector.
      def texture(sampler : Types::Sampler2D, uv : Types::Vec2) : Types::Vec4; Types::Vec4.new; end
      # Samples texture `sampler` at normalized coordinates `uv` with explicit level-of-detail `lod`.
      def textureLod(sampler : Types::Sampler2D, uv : Types::Vec2, lod : Float32) : Types::Vec4; Types::Vec4.new; end
      # Returns texture dimensions as `ivec2(width, height)` at mipmap level `lod`.
      def textureSize(sampler : Types::Sampler2D, lod : Int32 = 0) : Types::IVec2; Types::IVec2.new; end
      # Fetches texel at integer pixel coordinates `coord` without bilinear filtering.
      def texelFetch(sampler : Types::Sampler2D, coord : Types::IVec2, lod : Int32 = 0) : Types::Vec4; Types::Vec4.new; end

      # Direct image fetch from a compute storage image binding at pixel coordinate `coord`.
      def imageLoad(image : Symbol | String, coord : Types::IVec2) : Types::Vec4; Types::Vec4.new; end
      # Direct image write into a compute storage image binding at pixel coordinate `coord`.
      def imageStore(image : Symbol | String, coord : Types::IVec2, color : Types::Vec4) : Nil; end
      # Returns dimensions of storage image binding as `ivec2(width, height)`.
      def imageSize(image : Symbol | String) : Types::IVec2; Types::IVec2.new; end

      # Memory barrier ensuring global memory writes complete across all invocations.
      def memoryBarrier : Nil; end
      # Memory barrier ensuring workgroup shared memory writes complete.
      def memoryBarrierShared : Nil; end
      # Memory barrier ensuring storage image writes complete.
      def memoryBarrierImage : Nil; end
      # Workgroup-wide execution and shared memory synchronization barrier.
      def groupMemoryBarrier : Nil; end

      # Standard library: Clamps value between 0.0 and 1.0.
      def saturate(x : Float32) : Float32; clamp(x, 0.0_f32, 1.0_f32); end
      # Standard library: Linear interpolation alias for `mix`.
      def lerp(a : Float32, b : Float32, t : Float32) : Float32; mix(a, b, t); end
      # Standard library: Remaps value from input range `[in_min, in_max]` to output range `[out_min, out_max]`.
      def remap(val : Float32, in_min : Float32, in_max : Float32, out_min : Float32, out_max : Float32) : Float32
        out_min + (val - in_min) * (out_max - out_min) / (in_max - in_min)
      end
      # Standard library: Rotates a 2D vector by `angle` radians.
      def rotate_2d(p : Types::Vec2, angle : Float32) : Types::Vec2; p; end
      # Standard library: Computes power-law Fresnel reflection factor for view vector against surface normal.
      def fresnel(power : Float32, normal : Types::Vec3, view : Types::Vec3) : Float32
        pow(clamp(1.0_f32 - dot(normal, view), 0.0_f32, 1.0_f32), power)
      end
      # Standard library: Fast pseudo-random number generator for UV coordinates.
      def rand(uv : Types::Vec2) : Float32; 0.5_f32; end

      # Standard library: 1D -> 1D pseudo-random hash without texture lookups.
      def hash11(p : Float32) : Float32; 0.5_f32; end
      # Standard library: 2D -> 1D pseudo-random hash.
      def hash21(p : Types::Vec2) : Float32; 0.5_f32; end
      # Standard library: 3D -> 1D pseudo-random hash.
      def hash31(p : Types::Vec3) : Float32; 0.5_f32; end
      # Standard library: 1D -> 2D pseudo-random hash.
      def hash12(p : Float32) : Types::Vec2; Types::Vec2.new(0.5_f32, 0.5_f32); end
      # Standard library: 2D -> 2D pseudo-random hash.
      def hash22(p : Types::Vec2) : Types::Vec2; Types::Vec2.new(0.5_f32, 0.5_f32); end
      # Standard library: 3D -> 3D pseudo-random hash.
      def hash33(p : Types::Vec3) : Types::Vec3; Types::Vec3.new(0.5_f32, 0.5_f32, 0.5_f32); end
      # Standard library: Smooth 2D value noise interpolation.
      def value_noise(p : Types::Vec2) : Float32; 0.5_f32; end
      # Standard library: Cellular Voronoi distance calculation.
      def voronoi(p : Types::Vec2) : Float32; 0.5_f32; end
      # Standard library: Smooth 2D simplex noise gradient.
      def simplex_noise_2d(p : Types::Vec2) : Float32; 0.0_f32; end
      # Standard library: Multi-octave Fractal Brownian Motion (FBM) noise.
      def fbm(p : Types::Vec2, octaves : Int32 = 4) : Float32; 0.5_f32; end

      # Standard library: Converts HSV color vector to RGB.
      def hsv2rgb(c : Types::Vec3) : Types::Vec3; c; end
      # Standard library: Converts RGB color vector to HSV.
      def rgb2hsv(c : Types::Vec3) : Types::Vec3; c; end
      # Standard library: Converts RGB color vector to scalar grayscale luminance.
      def grayscale(c : Types::Vec3) : Float32; dot(c, Types::Vec3.new(0.299_f32, 0.587_f32, 0.114_f32)); end
      # Standard library: Adjusts contrast of an RGB color around midpoint 0.5.
      def adjust_contrast(c : Types::Vec3, contrast : Float32) : Types::Vec3; c; end
      # Standard library: Adjusts saturation of an RGB color.
      def adjust_saturation(c : Types::Vec3, saturation : Float32) : Types::Vec3; c; end

      # Standard library: Quantizes lighting dot product into discrete cel/toon shading bands.
      def cel_shade(n_dot_l : Float32, steps : Float32 = 3.0_f32) : Float32
        floor(clamp(n_dot_l, 0.0_f32, 1.0_f32) * steps) / steps
      end
      # Standard library: Calculates Blinn-Phong specular highlight lobe.
      def blinn_phong(normal : Types::Vec3, light_dir : Types::Vec3, view_dir : Types::Vec3, shininess : Float32) : Float32
        half_dir = normalize(light_dir + view_dir)
        pow(clamp(dot(normal, half_dir), 0.0_f32, 1.0_f32), shininess)
      end

      # Standard library: Signed distance field calculation for a sphere of `radius`.
      def sdf_sphere(p : Types::Vec3, radius : Float32) : Float32; length(p) - radius; end
      # Standard library: Signed distance field calculation for a 3D box of half-extents `b`.
      def sdf_box(p : Types::Vec3, b : Types::Vec3) : Float32; 0.0_f32; end
      # Standard library: Polynomial smooth minimum for blending SDF surfaces.
      def smin(a : Float32, b : Float32, k : Float32 = 0.1_f32) : Float32; min(a, b); end
      # Standard library: Polynomial smooth maximum for carving SDF surfaces.
      def smax(a : Float32, b : Float32, k : Float32 = 0.1_f32) : Float32; max(a, b); end

      # Standard library: Filmic ACES tonemapping curve for HDR to LDR display.
      def aces_tonemap(x : Types::Vec3) : Types::Vec3; x; end
      # Standard library: Reinhard tonemapping curve: `x / (1.0 + x)`.
      def reinhard_tonemap(x : Types::Vec3) : Types::Vec3; x; end

      # Standard library: Computes blend weights for seamless triplanar texture mapping.
      def triplanar_weights(normal : Types::Vec3) : Types::Vec3
        w = Types::Vec3.new(abs(normal.x), abs(normal.y), abs(normal.z))
        w / (w.x + w.y + w.z)
      end

      # Standard library: Linearizes non-linear screen depth buffer sample to camera-space distance.
      def linear_depth(depth : Float32, inv_proj : Types::Mat4) : Float32; 1.0_f32; end
      # Standard library: Calculates perceptual luminance from RGB color using ITU-R BT.709 weights.
      def luminance(col : Types::Vec3) : Float32; dot(col, Types::Vec3.new(0.2126_f32, 0.7152_f32, 0.0722_f32)); end
      # Standard library: Lens barrel / pincushion distortion for UV coordinate.
      def barrel_distortion(uv : Types::Vec2, k : Float32) : Types::Vec2; uv; end
      # Standard library: Smooth radial vignette factor between 0.0 (edge) and 1.0 (center).
      def vignette(uv : Types::Vec2, radius : Float32 = 0.75_f32, softness : Float32 = 0.45_f32) : Float32; 1.0_f32; end

      # Shorthand constructor for 2-component vector: `vec2(x, y)`.
      def vec2(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32) : Types::Vec2; Types::Vec2.new(x, y); end
      def vec2(x : Number, y : Number) : Types::Vec2; Types::Vec2.new(x.to_f32, y.to_f32); end
      # Shorthand constructor for 3-component vector: `vec3(x, y, z)`.
      def vec3(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32) : Types::Vec3; Types::Vec3.new(x, y, z); end
      def vec3(x : Number, y : Number, z : Number) : Types::Vec3; Types::Vec3.new(x.to_f32, y.to_f32, z.to_f32); end
      # Shorthand constructor for 4-component vector: `vec4(x, y, z, w)`.
      def vec4(x : Float32 = 0.0_f32, y : Float32 = 0.0_f32, z : Float32 = 0.0_f32, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(x, y, z, w); end
      def vec4(x : Number, y : Number, z : Number, w : Number = 1.0) : Types::Vec4; Types::Vec4.new(x.to_f32, y.to_f32, z.to_f32, w.to_f32); end
      def vec4(v3 : Types::Vec3, w : Float32 = 1.0_f32) : Types::Vec4; Types::Vec4.new(v3, w); end
      def vec4(val : Float32 | Number) : Types::Vec4; Types::Vec4.new(val.to_f32, val.to_f32, val.to_f32, val.to_f32); end

      # Shorthand constructor for 2-component integer vector: `ivec2(x, y)`.
      def ivec2(x : Int32 = 0, y : Int32 = 0) : Types::IVec2; Types::IVec2.new(x, y); end
      def ivec2(v2 : Types::Vec2) : Types::IVec2; Types::IVec2.new(v2.x.to_i, v2.y.to_i); end
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
  end
end
