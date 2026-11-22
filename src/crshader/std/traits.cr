module CrShader
  module Std
    TRAIT_RIM_FRESNEL = <<-CR
      shader_trait :rim_fresnel do
        property rim_color : Color = Color.hex("#66ccff"), hint: :source_color
        property rim_power : Float32 = 3.0, range: 0.5..10.0
        property rim_intensity : Float32 = 1.2, range: 0.0..5.0

        on_fragment do
          ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0)
          rim_mask = (1.0 - ndotv) ** rim_power
          EMISSION += rim_color.rgb * (rim_mask * rim_intensity)
        end
      end
    CR

    TRAIT_DISSOLVE = <<-CR
      shader_trait :dissolve do
        require "std/noise"

        property dissolve_amount : Float32 = 0.0, range: 0.0..1.0
        property dissolve_scale : Float32 = 10.0, range: 1.0..64.0
        property dissolve_edge_width : Float32 = 0.06, range: 0.005..0.3
        property dissolve_edge_color : Color = Color.hex("#ff6a10"), hint: :source_color

        on_fragment do
          noise_val = value_noise(UV * dissolve_scale)
          if dissolve_amount > 0.001 && noise_val < dissolve_amount
            discard
          end
          edge_mask = smoothstep(dissolve_amount + dissolve_edge_width, dissolve_amount, noise_val) * step(0.001, dissolve_amount)
          EMISSION += dissolve_edge_color.rgb * (edge_mask * 3.0)
        end
      end
    CR

    TRAIT_HIT_FLASH = <<-CR
      shader_trait :hit_flash do
        property flash_color : Color = Color.hex("#ffffff"), hint: :source_color
        property flash_amount : Float32 = 0.0, range: 0.0..1.0
        property flash_glow : Float32 = 1.5, range: 0.0..5.0

        on_fragment do
          amt = clamp(flash_amount, 0.0, 1.0)
          ALBEDO = mix(ALBEDO, flash_color.rgb, amt)
          EMISSION += flash_color.rgb * (amt * flash_glow)
        end
      end
    CR

    TRAIT_WIND_SWAY = <<-CR
      shader_trait :wind_sway do
        property wind_speed : Float32 = 2.2, range: 0.0..10.0
        property wind_strength : Float32 = 0.12, range: 0.0..1.5
        property wind_scale : Float32 = 1.5, range: 0.1..10.0

        on_vertex do
          height_mask = clamp(VERTEX.y, 0.0, 2.0) * 0.5
          phase = TIME * wind_speed + (VERTEX.x + VERTEX.z) * wind_scale
          VERTEX += vec3(sin(phase) * wind_strength * height_mask, 0.0, cos(phase * 0.8) * wind_strength * 0.5 * height_mask)
        end
      end
    CR

    TRAIT_TRIPLANAR_SURFACE = <<-CR
      shader_trait :triplanar_surface do
        require "std/uv"

        sampler triplanar_tex, filter: :linear_mipmap, repeat: :enable
        property triplanar_scale : Float32 = 0.5, range: 0.05..8.0
        property triplanar_sharpness : Float32 = 4.0, range: 1.0..16.0
        property triplanar_blend : Float32 = 1.0, range: 0.0..1.0

        varying v_triplanar_pos : Vec3
        varying v_triplanar_normal : Vec3

        on_vertex do
          v_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
          v_triplanar_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz)
        end

        on_fragment do
          sampled = triplanar_sample(triplanar_tex, v_triplanar_pos, normalize(v_triplanar_normal), triplanar_scale, triplanar_sharpness)
          ALBEDO = mix(ALBEDO, sampled.rgb, clamp(triplanar_blend, 0.0, 1.0))
        end
      end
    CR

    TRAIT_EMISSION_PULSE = <<-CR
      shader_trait :emission_pulse do
        property pulse_color : Color = Color.hex("#38bdf8"), hint: :source_color
        property pulse_speed : Float32 = 2.0, range: 0.0..12.0
        property pulse_min : Float32 = 0.1, range: 0.0..4.0
        property pulse_max : Float32 = 1.2, range: 0.0..8.0

        on_fragment do
          wave = sin(TIME * pulse_speed) * 0.5 + 0.5
          EMISSION += pulse_color.rgb * mix(pulse_min, pulse_max, wave)
        end
      end
    CR

    TRAIT_VIGNETTE = <<-CR
      shader_trait :vignette do
        property vignette_intensity : Float32 = 0.45, range: 0.0..1.0
        property vignette_radius : Float32 = 0.82, range: 0.1..1.5
        property vignette_softness : Float32 = 0.45, range: 0.02..1.0
        property vignette_color : Color = Color.hex("#060913"), hint: :source_color

        on_pixel do |uv, color|
          dist = length(uv - vec2(0.5, 0.5))
          vig = smoothstep(vignette_radius, vignette_radius - vignette_softness, dist)
          out_rgb = mix(color.rgb, vignette_color.rgb, (1.0 - vig) * vignette_intensity)
          color = vec4(out_rgb, color.a)
        end
      end
    CR

    TRAIT_CHROMATIC_ABERRATION = <<-CR
      shader_trait :chromatic_aberration do
        property aberration_amount : Float32 = 0.004, range: 0.0..0.05

        on_pixel do |uv, color|
          dir = uv - vec2(0.5, 0.5)
          uv_r = clamp(uv + dir * aberration_amount, vec2(0.0, 0.0), vec2(1.0, 1.0))
          uv_b = clamp(uv - dir * aberration_amount, vec2(0.0, 0.0), vec2(1.0, 1.0))
          {% if IS_GLSL %}
          img_sz = imageSize(color_image)
          sz_f = vec2(float(img_sz.x), float(img_sz.y))
          max_px = img_sz - ivec2(1, 1)
          r_ch = imageLoad(color_image, clamp(ivec2(uv_r * sz_f), ivec2(0, 0), max_px)).r
          b_ch = imageLoad(color_image, clamp(ivec2(uv_b * sz_f), ivec2(0, 0), max_px)).b
          {% else %}
          r_ch = texture(screen_texture, uv_r).r
          b_ch = texture(screen_texture, uv_b).b
          {% end %}
          color = vec4(r_ch, color.g, b_ch, color.a)
        end
      end
    CR

    TRAIT_COLOR_GRADE = <<-CR
      shader_trait :color_grade do
        property grade_exposure : Float32 = 1.0, range: 0.1..4.0
        property grade_contrast : Float32 = 1.08, range: 0.2..2.5
        property grade_saturation : Float32 = 1.12, range: 0.0..2.5
        property grade_tint : Color = Color.hex("#ffffff"), hint: :source_color

        on_pixel do |uv, color|
          exposed = color.rgb * grade_exposure * grade_tint.rgb
          contrasted = (exposed - vec3(0.5, 0.5, 0.5)) * grade_contrast + vec3(0.5, 0.5, 0.5)
          luma = dot(contrasted, vec3(0.2126, 0.7152, 0.0722))
          graded = max(mix(vec3(luma, luma, luma), contrasted, grade_saturation), vec3(0.0, 0.0, 0.0))
          color = vec4(graded, color.a)
        end
      end
    CR

    TRAIT_FILM_GRAIN = <<-CR
      shader_trait :film_grain do
        property grain_amount : Float32 = 0.035, range: 0.0..0.25
        property grain_speed : Float32 = 12.0, range: 0.0..60.0

        on_pixel do |uv, color|
          seed_uv = uv * vec2(512.0, 512.0) + vec2(floor(TIME * grain_speed) * 17.3, floor(TIME * grain_speed) * 31.7)
          n = fract(sin(dot(seed_uv, vec2(12.9898, 78.233))) * 43758.5453) - 0.5
          color = vec4(max(color.rgb + vec3(n, n, n) * grain_amount, vec3(0.0, 0.0, 0.0)), color.a)
        end
      end
    CR

    TRAIT_SHOCKWAVE_RIPPLE = <<-CR
      shader_trait :shockwave_ripple do
        property ripple_center : Vec2 = Vec2.new(0.5, 0.5)
        property ripple_radius : Float32 = 0.28, range: 0.0..1.5
        property ripple_width : Float32 = 0.08, range: 0.01..0.4
        property ripple_strength : Float32 = 0.025, range: 0.0..0.15

        on_pixel do |uv, color|
          delta = uv - ripple_center
          dist = max(length(delta), 0.0001)
          band = smoothstep(ripple_radius - ripple_width, ripple_radius, dist) * (1.0 - smoothstep(ripple_radius, ripple_radius + ripple_width, dist))
          warped_uv = clamp(uv + (delta / dist) * (band * ripple_strength), vec2(0.0, 0.0), vec2(1.0, 1.0))
          {% if IS_GLSL %}
          img_sz = imageSize(color_image)
          sz_f = vec2(float(img_sz.x), float(img_sz.y))
          max_px = img_sz - ivec2(1, 1)
          sampled = imageLoad(color_image, clamp(ivec2(warped_uv * sz_f), ivec2(0, 0), max_px))
          {% else %}
          sampled = texture(screen_texture, warped_uv)
          {% end %}
          color = mix(color, sampled, step(0.0001, ripple_strength))
        end
      end
    CR

    TRAITS_REGISTRY = {
      "rim_fresnel"          => TRAIT_RIM_FRESNEL,
      "dissolve"             => TRAIT_DISSOLVE,
      "hit_flash"            => TRAIT_HIT_FLASH,
      "wind_sway"            => TRAIT_WIND_SWAY,
      "triplanar_surface"    => TRAIT_TRIPLANAR_SURFACE,
      "emission_pulse"       => TRAIT_EMISSION_PULSE,
      "vignette"             => TRAIT_VIGNETTE,
      "chromatic_aberration" => TRAIT_CHROMATIC_ABERRATION,
      "color_grade"          => TRAIT_COLOR_GRADE,
      "film_grain"           => TRAIT_FILM_GRAIN,
      "shockwave_ripple"     => TRAIT_SHOCKWAVE_RIPPLE,
    }

    def self.normalize_trait_key(name : String) : String
      name.strip.sub(/^std\/traits\//, "").sub(/^traits\//, "").sub(/^std\//, "")
    end

    def self.has_trait?(name : String) : Bool
      TRAITS_REGISTRY.has_key?(normalize_trait_key(name))
    end

    def self.trait_source(name : String) : String?
      TRAITS_REGISTRY[normalize_trait_key(name)]?
    end

    def self.trait_names : Array(String)
      TRAITS_REGISTRY.keys
    end
  end
end
