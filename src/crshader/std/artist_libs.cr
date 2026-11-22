module CrShader
  module Std
    BLEND_LIB = <<-CR
      def blend_multiply(base : Vec3, top : Vec3) : Vec3
        base * top
      end

      def blend_screen(base : Vec3, top : Vec3) : Vec3
        vec3(1.0, 1.0, 1.0) - (vec3(1.0, 1.0, 1.0) - base) * (vec3(1.0, 1.0, 1.0) - top)
      end

      def blend_overlay(base : Vec3, top : Vec3) : Vec3
        dark = 2.0 * base * top
        light = vec3(1.0, 1.0, 1.0) - 2.0 * (vec3(1.0, 1.0, 1.0) - base) * (vec3(1.0, 1.0, 1.0) - top)
        mix(dark, light, step(vec3(0.5, 0.5, 0.5), base))
      end

      def blend_hard_light(base : Vec3, top : Vec3) : Vec3
        blend_overlay(top, base)
      end

      def blend_soft_light(base : Vec3, top : Vec3) : Vec3
        (vec3(1.0, 1.0, 1.0) - 2.0 * top) * base * base + 2.0 * top * base
      end

      def blend_color_dodge(base : Vec3, top : Vec3) : Vec3
        clamp(base / max(vec3(1.0, 1.0, 1.0) - top, vec3(0.0001, 0.0001, 0.0001)), vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0))
      end

      def blend_color_burn(base : Vec3, top : Vec3) : Vec3
        vec3(1.0, 1.0, 1.0) - clamp((vec3(1.0, 1.0, 1.0) - base) / max(top, vec3(0.0001, 0.0001, 0.0001)), vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0))
      end

      def blend_difference(base : Vec3, top : Vec3) : Vec3
        abs(base - top)
      end

      def blend_exclusion(base : Vec3, top : Vec3) : Vec3
        base + top - 2.0 * base * top
      end

      def blend_add(base : Vec3, top : Vec3) : Vec3
        min(base + top, vec3(1.0, 1.0, 1.0))
      end

      def blend_multiply_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_multiply(base, top), opacity)
      end

      def blend_screen_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_screen(base, top), opacity)
      end

      def blend_overlay_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_overlay(base, top), opacity)
      end

      def blend_hard_light_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_hard_light(base, top), opacity)
      end

      def blend_soft_light_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_soft_light(base, top), opacity)
      end

      def blend_color_dodge_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_color_dodge(base, top), opacity)
      end

      def blend_color_burn_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_color_burn(base, top), opacity)
      end

      def blend_difference_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_difference(base, top), opacity)
      end

      def blend_exclusion_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_exclusion(base, top), opacity)
      end

      def blend_add_opacity(base : Vec3, top : Vec3, opacity : Float32) : Vec3
        mix(base, blend_add(base, top), opacity)
      end

      def blend_multiply_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_multiply(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_screen_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_screen(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_overlay_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_overlay(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_hard_light_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_hard_light(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_soft_light_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_soft_light(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_color_dodge_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_color_dodge(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_color_burn_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_color_burn(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_difference_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_difference(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_exclusion_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_exclusion(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def blend_add_rgba(base : Vec4, top : Vec4, opacity : Float32) : Vec4
        vec4(mix(base.rgb, blend_add(base.rgb, top.rgb), opacity * top.a), base.a)
      end

      def hue_shift_rgb(c : Vec3, amount : Float32) : Vec3
        angle = amount * 6.2831853
        k = vec3(0.57735027, 0.57735027, 0.57735027)
        cos_a = cos(angle)
        c * cos_a + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - cos_a)
      end

      def hue_shift_rgba(c : Vec4, amount : Float32) : Vec4
        vec4(hue_shift_rgb(c.rgb, amount), c.a)
      end

      def saturate_rgba(c : Vec4, saturation : Float32) : Vec4
        luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))
        vec4(mix(vec3(luma, luma, luma), c.rgb, saturation), c.a)
      end

      def adjust_contrast_rgba(c : Vec4, contrast : Float32) : Vec4
        vec4((c.rgb - vec3(0.5, 0.5, 0.5)) * contrast + vec3(0.5, 0.5, 0.5), c.a)
      end
    CR

    EASING_LIB = <<-CR
      def ease_in_quad(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        x * x
      end

      def ease_out_quad(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        1.0 - (1.0 - x) * (1.0 - x)
      end

      def ease_in_out_quad(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        if x < 0.5
          2.0 * x * x
        else
          1.0 - ((-2.0 * x + 2.0) ** 2.0) * 0.5
        end
      end

      def ease_in_cubic(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        x * x * x
      end

      def ease_out_cubic(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        u = 1.0 - x
        1.0 - u * u * u
      end

      def ease_in_out_cubic(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        if x < 0.5
          4.0 * x * x * x
        else
          u = -2.0 * x + 2.0
          1.0 - (u * u * u) * 0.5
        end
      end

      def ease_out_back(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        c1 = 1.70158
        c3 = c1 + 1.0
        u = x - 1.0
        1.0 + c3 * u * u * u + c1 * u * u
      end

      def ease_out_elastic(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        if x <= 0.0001
          0.0
        elsif x >= 0.9999
          1.0
        else
          c4 = 2.0943951
          (2.0 ** (-10.0 * x)) * sin((x * 10.0 - 0.75) * c4) + 1.0
        end
      end

      def ease_out_bounce(t : Float32) : Float32
        x = clamp(t, 0.0, 1.0)
        n1 = 7.5625
        d1 = 2.75
        if x < 1.0 / d1
          n1 * x * x
        elsif x < 2.0 / d1
          u = x - 1.5 / d1
          n1 * u * u + 0.75
        elsif x < 2.5 / d1
          u = x - 2.25 / d1
          n1 * u * u + 0.9375
        else
          u = x - 2.625 / d1
          n1 * u * u + 0.984375
        end
      end

      def osc_sine(time : Float32, freq : Float32) : Float32
        sin(time * freq * 6.2831853) * 0.5 + 0.5
      end

      def osc_triangle(time : Float32, freq : Float32) : Float32
        abs(fract(time * freq) * 2.0 - 1.0)
      end

      def osc_sawtooth(time : Float32, freq : Float32) : Float32
        fract(time * freq)
      end

      def osc_pulse(time : Float32, freq : Float32, duty : Float32) : Float32
        step(fract(time * freq), duty)
      end

      def ping_pong(val : Float32, len : Float32) : Float32
        l = max(len, 0.0001)
        t = mod(val, l * 2.0)
        l - abs(t - l)
      end
    CR

    UV_LIB = <<-CR
      def uv_rotate(uv : Vec2, angle : Float32, pivot : Vec2) : Vec2
        d = uv - pivot
        s = sin(angle)
        c = cos(angle)
        vec2(d.x * c - d.y * s, d.x * s + d.y * c) + pivot
      end

      def uv_polar(uv : Vec2, center : Vec2) : Vec2
        d = uv - center
        radius = length(d) * 2.0
        angle = atan(d.y, d.x) / 6.2831853 + 0.5
        vec2(radius, angle)
      end

      def uv_pixelate(uv : Vec2, steps : Float32) : Vec2
        s = max(steps, 1.0)
        floor(uv * s) / s
      end

      def uv_wave(uv : Vec2, freq : Float32, amp : Float32, phase : Float32) : Vec2
        vec2(
          uv.x + sin(uv.y * freq + phase) * amp,
          uv.y + cos(uv.x * freq + phase) * amp
        )
      end

      def uv_aspect_correct(uv : Vec2, aspect : Float32) : Vec2
        (uv - vec2(0.5, 0.5)) * vec2(aspect, 1.0) + vec2(0.5, 0.5)
      end

      def uv_parallax(uv : Vec2, view_dir : Vec3, height : Float32, scale : Float32) : Vec2
        uv - (view_dir.xy / max(abs(view_dir.z), 0.15)) * (height * scale)
      end

      def triplanar_sample(tex : Sampler2D, world_pos : Vec3, world_normal : Vec3, scale : Float32, sharpness : Float32) : Vec4
        w = pow(abs(world_normal), vec3(sharpness, sharpness, sharpness))
        w = w / max(w.x + w.y + w.z, 0.0001)
        cx = texture(tex, world_pos.yz * scale)
        cy = texture(tex, world_pos.xz * scale)
        cz = texture(tex, world_pos.xy * scale)
        cx * w.x + cy * w.y + cz * w.z
      end
    CR

    SDF2D_LIB = <<-CR
      def sdf2d_circle(p : Vec2, radius : Float32) : Float32
        length(p) - radius
      end

      def sdf2d_box(p : Vec2, half_size : Vec2) : Float32
        d = abs(p) - half_size
        length(max(d, vec2(0.0, 0.0))) + min(max(d.x, d.y), 0.0)
      end

      def sdf2d_rounded_box(p : Vec2, half_size : Vec2, radius : Float32) : Float32
        q = abs(p) - half_size + vec2(radius, radius)
        min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0, 0.0))) - radius
      end

      def sdf2d_ring(p : Vec2, radius : Float32, thickness : Float32) : Float32
        abs(length(p) - radius) - thickness * 0.5
      end

      def sdf2d_segment(p : Vec2, a : Vec2, b : Vec2) : Float32
        pa = p - a
        ba = b - a
        h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0)
        length(pa - ba * h)
      end

      def sdf2d_star(p : Vec2, radius : Float32, points : Float32, inner_ratio : Float32) : Float32
        an = 3.14159265 / max(points, 3.0)
        en = 3.14159265 / max(mix(2.0, points, clamp(inner_ratio, 0.05, 0.95)), 2.0)
        acs = vec2(cos(an), sin(an))
        ecs = vec2(cos(en), sin(en))
        bn = mod(atan(p.x, p.y), 2.0 * an) - an
        q = length(p) * vec2(cos(bn), abs(sin(bn)))
        q = q - radius * acs
        q = q + ecs * clamp(-dot(q, ecs), 0.0, radius * acs.y / max(ecs.y, 0.0001))
        length(q) * sign(q.x)
      end

      def sdf_fill(d : Float32) : Float32
        aa = max(fwidth(d), 0.0005)
        1.0 - smoothstep(-aa, aa, d)
      end

      def sdf_stroke(d : Float32, width : Float32) : Float32
        aa = max(fwidth(d), 0.0005)
        hw = width * 0.5
        1.0 - smoothstep(hw - aa, hw + aa, abs(d))
      end

      def sdf_glow(d : Float32, radius : Float32, falloff : Float32) : Float32
        pow(clamp(1.0 - max(d, 0.0) / max(radius, 0.0001), 0.0, 1.0), falloff)
      end
    CR
  end
end
