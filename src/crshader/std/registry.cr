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

    DITHER_LIB = <<-CR
      def bayer2x2(p : IVec2) : Float32
        m = (p.x % 2) * 2 + (p.y % 2)
        (m == 0 ? 0.0 : (m == 1 ? 2.0 : (m == 2 ? 3.0 : 1.0))) / 4.0
      end

      def bayer4x4(p : IVec2) : Float32
        x = p.x % 4
        y = p.y % 4
        val = 0.0
        if y == 0
          val = x == 0 ? 0.0 : (x == 1 ? 8.0 : (x == 2 ? 2.0 : 10.0))
        elsif y == 1
          val = x == 0 ? 12.0 : (x == 1 ? 4.0 : (x == 2 ? 14.0 : 6.0))
        elsif y == 2
          val = x == 0 ? 3.0 : (x == 1 ? 11.0 : (x == 2 ? 1.0 : 9.0))
        else
          val = x == 0 ? 15.0 : (x == 1 ? 7.0 : (x == 2 ? 13.0 : 5.0))
        end
        val / 16.0
      end

      def ign(pos : Vec2) : Float32
        fract(52.9829189 * fract(dot(pos, vec2(0.06711056, 0.00583715))))
      end

      def dither_quantize(color : Float32, steps : Float32, dither_val : Float32) : Float32
        floor(color * steps + dither_val) / steps
      end
    CR

    CURL_NOISE_LIB = <<-CR
      def simplex_noise_2d(p : Vec2) : Float32
        c = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439)
        i = floor(p + dot(p, c.yy))
        x0 = p - i + dot(i, c.xx)
        i1 = x0.x > x0.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0)
        x12 = x0.xyxy + c.xxzz
        x12.xy = x12.xy - i1
        p3 = fract(vec3(i.x, i.y, i.x) * 0.1031)
        p3 += dot(p3, p3.yzx + 33.33)
        m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), vec3(0.0, 0.0, 0.0))
        m = m * m
        m = m * m
        dot(m, vec3(p3.x, p3.y, p3.z) - 0.5) * 70.0
      end

      def curl_noise_2d(p : Vec2, eps : Float32) : Vec2
        n1 = simplex_noise_2d(p + vec2(0.0, eps))
        n2 = simplex_noise_2d(p - vec2(0.0, eps))
        n3 = simplex_noise_2d(p + vec2(eps, 0.0))
        n4 = simplex_noise_2d(p - vec2(eps, 0.0))
        x = (n1 - n2) / (2.0 * eps)
        y = -(n3 - n4) / (2.0 * eps)
        vec2(x, y)
      end

      def curl_noise_3d(p : Vec3, eps : Float32) : Vec3
        dx = vec3(eps, 0.0, 0.0)
        dy = vec3(0.0, eps, 0.0)
        dz = vec3(0.0, 0.0, eps)
        p_x0 = simplex_noise_2d(p.yz - dx.yz)
        p_x1 = simplex_noise_2d(p.yz + dx.yz)
        p_y0 = simplex_noise_2d(p.zx - dy.zx)
        p_y1 = simplex_noise_2d(p.zx + dy.zx)
        p_z0 = simplex_noise_2d(p.xy - dz.xy)
        p_z1 = simplex_noise_2d(p.xy + dz.xy)
        x = (p_y1 - p_y0) - (p_z1 - p_z0)
        y = (p_z1 - p_z0) - (p_x1 - p_x0)
        z = (p_x1 - p_x0) - (p_y1 - p_y0)
        normalize(vec3(x, y, z))
      end
    CR

    COLOR_SPACES_LIB = <<-CR
      def linear_srgb_to_oklab(c : Vec3) : Vec3
        l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b
        m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b
        s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b
        l_ = cbrt(l)
        m_ = cbrt(m)
        s_ = cbrt(s)
        l_out = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        a_out = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        b_out = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        vec3(l_out, a_out, b_out)
      end

      def oklab_to_linear_srgb(c : Vec3) : Vec3
        l_ = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z
        m_ = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z
        s_ = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z
        l = l_ * l_ * l_
        m = m_ * m_ * m_
        s = s_ * s_ * s_
        r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        vec3(r, g, b)
      end

      def delta_e_oklab(c1 : Vec3, c2 : Vec3) : Float32
        lab1 = linear_srgb_to_oklab(c1)
        lab2 = linear_srgb_to_oklab(c2)
        length(lab1 - lab2)
      end
    CR

    ATMOSPHERE_LIB = <<-CR
      def hg_phase(cos_theta : Float32, g : Float32) : Float32
        g2 = g * g
        num = 1.0 - g2
        denom = 4.0 * 3.14159265 * (1.0 + g2 - 2.0 * g * cos_theta) ** 1.5
        num / max(denom, 0.0001)
      end

      def ray_sphere_intersect(ro : Vec3, rd : Vec3, radius : Float32) : Vec2
        b = dot(ro, rd)
        c = dot(ro, ro) - radius * radius
        d = b * b - c
        if d < 0.0
          vec2(-1.0, -1.0)
        else
          sqrt_d = sqrt(d)
          vec2(-b - sqrt_d, -b + sqrt_d)
        end
      end
    CR

    GLITCH_LIB = <<-CR
      def scanline_jitter(uv : Vec2, time : Float32, intensity : Float32) : Vec2
        j = fract(sin(dot(vec2(floor(uv.y * 240.0), time), vec2(12.9898, 78.233))) * 43758.5453)
        offset = (j - 0.5) * intensity * step(0.92, j)
        vec2(uv.x + offset, uv.y)
      end

      def rgb_split(uv : Vec2, amount : Float32) : Vec4
        vec4(uv.x - amount, uv.y, uv.x + amount, uv.y)
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
      "dither"          => DITHER_LIB,
      "curl_noise"      => CURL_NOISE_LIB,
      "color_spaces"    => COLOR_SPACES_LIB,
      "atmosphere"      => ATMOSPHERE_LIB,
      "glitch"          => GLITCH_LIB,
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
