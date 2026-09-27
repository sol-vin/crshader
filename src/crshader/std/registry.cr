require "compiler/crystal/syntax"

module CrShader
  module Std
    MATH_LIB = <<-CR
      def saturate(x : Float32) : Float32
        clamp(x, 0.0, 1.0)
      end

      def lerp(a : Float32, b : Float32, t : Float32) : Float32
        mix(a, b, t)
      end

      def remap(val : Float32, in_min : Float32, in_max : Float32, out_min : Float32, out_max : Float32) : Float32
        out_min + (val - in_min) * (out_max - out_min) / (in_max - in_min)
      end

      def rotate_2d(p : Vec2, angle : Float32) : Vec2
        s = sin(angle)
        c = cos(angle)
        vec2(p.x * c - p.y * s, p.x * s + p.y * c)
      end

      def fresnel(power : Float32, normal : Vec3, view : Vec3) : Float32
        clamp(1.0 - dot(normal, view), 0.0, 1.0) ** power
      end

      def rand(uv : Vec2) : Float32
        fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123)
      end

      def rand() : Float32
        fract(sin(dot(vec2(0.123, 0.456), vec2(12.9898, 78.233))) * 43758.5453123)
      end
    CR

    NOISE_LIB = <<-CR
      def hash11(p : Float32) : Float32
        p3 = fract(vec3(p, p, p) * 0.1031)
        p3 += dot(p3, p3.yzx + 33.33)
        fract((p3.x + p3.y) * p3.z)
      end

      def hash22(p : Vec2) : Vec2
        p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973))
        p3 += dot(p3, p3.yzx + 33.33)
        fract((p3.xx + p3.yz) * p3.zy)
      end

      def value_noise(p : Vec2) : Float32
        i = floor(p)
        f = fract(p)
        u = f * f * (3.0 - 2.0 * f)

        a = hash11(i.x + i.y * 57.0)
        b = hash11(i.x + 1.0 + i.y * 57.0)
        c = hash11(i.x + (i.y + 1.0) * 57.0)
        d = hash11(i.x + 1.0 + (i.y + 1.0) * 57.0)

        mix(mix(a, b, u.x), mix(c, d, u.x), u.y)
      end

      def voronoi(p : Vec2) : Float32
        n = floor(p)
        f = fract(p)
        min_dist = 8.0

        diff_0 = hash22(n) - f
        min_dist = min(min_dist, length(diff_0))

        diff_1 = hash22(n + vec2(1.0, 0.0)) + vec2(1.0, 0.0) - f
        min_dist = min(min_dist, length(diff_1))

        diff_2 = hash22(n + vec2(0.0, 1.0)) + vec2(0.0, 1.0) - f
        min_dist = min(min_dist, length(diff_2))

        diff_3 = hash22(n + vec2(1.0, 1.0)) + vec2(1.0, 1.0) - f
        min_dist = min(min_dist, length(diff_3))

        min_dist
      end
    CR

    COLOR_LIB = <<-CR
      def hsv2rgb(c : Vec3) : Vec3
        rgb = clamp(abs(fract(vec3(c.x, c.x, c.x) + vec3(0.0, 4.0, 2.0) / 6.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0)
        c.z * mix(vec3(1.0, 1.0, 1.0), rgb, c.y)
      end

      def rgb2hsv(c : Vec3) : Vec3
        k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0)
        p = mix(vec4(c.b, c.g, k.w, k.z), vec4(c.g, c.b, k.x, k.y), step(c.b, c.g))
        q = mix(vec4(p.x, p.y, p.w, c.r), vec4(c.r, p.y, p.z, p.x), step(p.x, c.r))
        d = q.x - min(q.w, q.y)
        e = 1.0e-10
        vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x)
      end

      def grayscale(c : Vec3) : Float32
        dot(c, vec3(0.299, 0.587, 0.114))
      end

      def adjust_contrast(c : Vec3, contrast : Float32) : Vec3
        (c - 0.5) * contrast + 0.5
      end

      def adjust_saturation(c : Vec3, saturation : Float32) : Vec3
        gray = grayscale(c)
        mix(vec3(gray, gray, gray), c, saturation)
      end
    CR

    LIGHTING_LIB = <<-CR
      def cel_shade(n_dot_l : Float32, steps : Float32) : Float32
        floor(clamp(n_dot_l, 0.0, 1.0) * steps) / steps
      end

      def blinn_phong(normal : Vec3, light_dir : Vec3, view_dir : Vec3, shininess : Float32) : Float32
        half_dir = normalize(light_dir + view_dir)
        clamp(dot(normal, half_dir), 0.0, 1.0) ** shininess
      end
    CR

    SDF_LIB = <<-CR
      def sdf_sphere(p : Vec3, radius : Float32) : Float32
        length(p) - radius
      end

      def sdf_box(p : Vec3, b : Vec3) : Float32
        q = abs(p) - b
        length(max(q, vec3(0.0, 0.0, 0.0))) + min(max(q.x, max(q.y, q.z)), 0.0)
      end

      def smin(a : Float32, b : Float32, k : Float32) : Float32
        h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
        mix(b, a, h) - k * h * (1.0 - h)
      end

      def smax(a : Float32, b : Float32, k : Float32) : Float32
        h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0)
        mix(b, a, h) + k * h * (1.0 - h)
      end
    CR

    TONEMAP_LIB = <<-CR
      def aces_tonemap(x : Vec3) : Vec3
        a = 2.51
        b = 0.03
        c = 2.43
        d = 0.59
        e = 0.14
        clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0)
      end

      def reinhard_tonemap(x : Vec3) : Vec3
        x / (x + vec3(1.0, 1.0, 1.0))
      end
    CR

    TRIPLANAR_LIB = <<-CR
      def triplanar_weights(normal : Vec3) : Vec3
        w = abs(normal)
        w = w / (w.x + w.y + w.z)
        w
      end
    CR

    POST_PROCESSING_LIB = <<-CR
      def linear_depth(depth_sample : Float32, inv_proj : Mat4) : Float32
        view_pos = inv_proj * vec4(0.0, 0.0, depth_sample, 1.0)
        -view_pos.z / view_pos.w
      end

      def luminance(c : Vec3) : Float32
        dot(c, vec3(0.2126, 0.7152, 0.0722))
      end

      def barrel_distortion(uv : Vec2, distortion : Float32) : Vec2
        d = uv - vec2(0.5, 0.5)
        uv + d * dot(d, d) * distortion
      end

      def vignette(uv : Vec2, radius : Float32, softness : Float32) : Float32
        d = length(uv - vec2(0.5, 0.5))
        smoothstep(radius, radius - softness, d)
      end
    CR

    COMPOSITOR_LIB = <<-CR
      def linear_depth(depth : Float32, z_near : Float32, z_far : Float32) : Float32
        z_near * z_far / (z_far + depth * (z_near - z_far))
      end

      def depth_sobel(d_up : Float32, d_down : Float32, d_left : Float32, d_right : Float32) : Float32
        abs(d_up - d_down) + abs(d_left - d_right)
      end
    CR

    REGISTRY = {
      "math"            => MATH_LIB,
      "noise"           => NOISE_LIB,
      "color"           => COLOR_LIB,
      "lighting"        => LIGHTING_LIB,
      "sdf"             => SDF_LIB,
      "tonemap"         => TONEMAP_LIB,
      "triplanar"       => TRIPLANAR_LIB,
      "post_processing" => POST_PROCESSING_LIB,
      "compositor"      => COMPOSITOR_LIB,
    }

    def self.load_module(mod_name : String) : Array(Crystal::Def)
      clean_name = mod_name.sub(/^std\//, "")
      source = REGISTRY[clean_name]?
      return [] of Crystal::Def unless source

      parsed = Crystal::Parser.new(source).parse
      defs = [] of Crystal::Def
      if parsed.is_a?(Crystal::Expressions)
        parsed.expressions.each do |child|
          defs << child if child.is_a?(Crystal::Def)
        end
      elsif parsed.is_a?(Crystal::Def)
        defs << parsed
      end
      defs
    end
  end
end
