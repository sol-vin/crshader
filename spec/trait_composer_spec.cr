require "./spec_helper"

describe "Composable Shader Traits & CrShader::Composer" do
  it "fuses custom shader_trait blocks with local variable collision hygiene and prefixing" do
    source = <<-CR
      shader_trait :pulse_tint do
        property pulse_speed : Float32 = 2.0
        on_fragment do
          d = sin(TIME * pulse_speed) * 0.5 + 0.5
          ALBEDO = ALBEDO * mix(0.6, 1.2, d)
        end
      end

      shader_trait :uv_grid_glow do
        property grid_scale : Float32 = 8.0
        on_fragment do
          # Intentionally reuses `d` with a DIFFERENT type (`Vec2` vs `Float32`) to test AST hygiene!
          d = fract(UV * grid_scale)
          line = max(step(0.92, d.x), step(0.92, d.y))
          EMISSION += vec3(0.1, 0.5, 1.0) * line
        end
      end

      surface_material :pbr do
        use_trait :pulse_tint, prefix: :primary
        use_trait :pulse_tint, prefix: :secondary
        use_trait :uv_grid_glow

        ALBEDO = vec3(0.8, 0.8, 0.9)
      end
    CR

    compiled = CrShader.compile(source)
    compiled.should contain("uniform float primary_pulse_speed = 2.0;")
    compiled.should contain("uniform float secondary_pulse_speed = 2.0;")
    compiled.should contain("uniform float grid_scale = 8.0;")
    compiled.should contain("group_uniforms Primary_PulseTint;")
    compiled.should contain("group_uniforms Secondary_PulseTint;")
    # Both `float ..._d` and `vec2 ..._d` coexist in `void fragment()` with zero collision!
    compiled.should contain("float _primary_pulse_tint_")
    compiled.should contain("vec2 _uv_grid_glow_")
  end

  it "compiles all built-in std/traits/* surface and post-processing traits cleanly" do
    surface_code = CrShader::Composer.spatial(:toon)
      .with_trait("std/traits/wind_sway")
      .with_trait("std/traits/triplanar_surface")
      .with_trait("std/traits/rim_fresnel")
      .with_trait("std/traits/dissolve")
      .with_trait("std/traits/hit_flash")
      .with_trait("std/traits/emission_pulse")
      .compile

    surface_code.should contain("shader_type spatial;")
    surface_code.should contain("render_mode cull_back, diffuse_toon, specular_toon;")
    surface_code.should contain("void vertex()")
    surface_code.should contain("void fragment()")
    surface_code.should contain("triplanar_sample")
    surface_code.should contain("value_noise")
    surface_code.should contain("rim_color")
    surface_code.should contain("flash_amount")
    surface_code.should contain("pulse_speed")

    post_gdshader = CrShader::Composer.screen_effect
      .with_trait("std/traits/shockwave_ripple")
      .with_trait("std/traits/chromatic_aberration")
      .with_trait("std/traits/color_grade")
      .with_trait("std/traits/vignette")
      .with_trait("std/traits/film_grain")
      .compile

    post_gdshader.should contain("shader_type canvas_item;")
    post_gdshader.should contain("hint_screen_texture")
    post_gdshader.should contain("aberration_amount")
    post_gdshader.should contain("grade_saturation")
    post_gdshader.should contain("vignette_intensity")
    post_gdshader.should contain("grain_amount")
    post_gdshader.should contain("ripple_strength")

    # Verify the exact same `on_pixel` traits fuse into a Vulkan GLSL `compositor_effect`!
    post_glsl = CrShader::Composer.compositor_effect(:post_transparent)
      .with_trait("std/traits/chromatic_aberration")
      .with_trait("std/traits/color_grade")
      .with_trait("std/traits/vignette")
      .with_trait("std/traits/film_grain")
      .compile

    post_glsl.should contain("#version 450")
    post_glsl.should contain("imageLoad(color_image")
    post_glsl.should contain("imageStore(color_image, coord, color);")
    post_glsl.should contain("CrShaderSceneData")
  end
end
