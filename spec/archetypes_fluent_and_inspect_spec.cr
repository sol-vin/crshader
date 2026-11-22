require "./spec_helper"
require "../src/crshader/stubs/stub_generator"

describe "Intent Archetypes, Fluent Chains, Artist Stdlib & Visual Inspector" do
  it "compiles sprite_effect, screen_effect (:canvas & :spatial), ui_effect, and surface_material archetypes" do
    sprite_code = CrShader.compile(<<-CR)
      sprite_effect unshaded: true do |uv, color|
        property brightness : Float32 = 1.2
        vec4(color.rgb * brightness, color.a)
      end
    CR
    sprite_code.should contain("shader_type canvas_item;")
    sprite_code.should contain("render_mode unshaded;")
    sprite_code.should contain("uniform float brightness = 1.2;")
    sprite_code.should contain("COLOR = color;")

    spatial_screen = CrShader.compile(<<-CR)
      screen_effect mode: :spatial, depth: true do |uv, color|
        d = texture(depth_texture, uv).r
        vec4(color.rgb * (1.0 - d * 0.1), 1.0)
      end
    CR
    spatial_screen.should contain("shader_type spatial;")
    spatial_screen.should contain("depth_test_disabled")
    spatial_screen.should contain("hint_screen_texture")
    spatial_screen.should contain("hint_depth_texture")
    spatial_screen.should contain("POSITION = vec4(VERTEX.xy, 1.0, 1.0);")
    spatial_screen.should contain("ALBEDO = color.rgb;")

    ui_code = CrShader.compile(<<-CR)
      ui_effect do |uv, centered_uv, color|
        require "std/sdf2d"
        d = sdf2d_circle(centered_uv, 0.35)
        vec4(vec3(1.0, 1.0, 1.0), sdf_fill(d))
      end
    CR
    ui_code.should contain("dFdx(")
    ui_code.should contain("dFdy(")
    ui_code.should contain("sdf2d_circle")
    ui_code.should contain("fwidth(")

    glass_code = CrShader.compile(<<-CR)
      surface_material :glass do
        ALBEDO = vec3(0.8, 0.95, 1.0)
        ALPHA = 0.35
        ROUGHNESS = 0.05
      end
    CR
    glass_code.should contain("depth_prepass_alpha")
    glass_code.should contain("ALPHA = 0.35;")
  end

  it "transpiles fluent Vec2, Vec3/Vec4, and Float32 method chains and artist stdlib modules" do
    source = <<-CR
      require "std/easing"
      require "std/sdf2d"

      sprite_effect do |uv, color|
        p = uv.tile(4.0).scroll(0.2, -0.1).offset(0.05, 0.05).rotate(TIME * 0.5).pixelate(64.0).wave(8.0, 0.01)
        polar_p = p.polar
        eased = ease_out_elastic(polar_p.x.remap(0.0, 2.0, 0.0, 1.0)).one_minus
        star_d = sdf2d_star(uv - vec2(0.5, 0.5), 0.25, 5.0, 0.45)
        glow = sdf_glow(star_d, 0.1, 2.0)

        graded = color.rgb
          .blend(:overlay, vec3(0.2, 0.6, 1.0), 0.5)
          .contrast(1.15)
          .saturate_color(1.25)
          .hue_shift(0.1)
          .posterize(12.0)

        luma = graded.luminance
        vec4(graded + vec3(glow * eased * luma, 0.0, 0.0), color.a)
      end
    CR

    compiled = CrShader.compile(source)
    compiled.should contain("uv_rotate(")
    compiled.should contain("uv_pixelate(")
    compiled.should contain("uv_wave(")
    compiled.should contain("uv_polar(")
    compiled.should contain("remap(")
    compiled.should contain("ease_out_elastic(")
    compiled.should contain("sdf2d_star(")
    compiled.should contain("blend_overlay_opacity(")
    compiled.should contain("adjust_contrast(")
    compiled.should contain("adjust_saturation(")
    compiled.should contain("hue_shift_rgb(")
  end

  it "synthesizes `debug_view` heatmaps for `inspect` probes and strips them cleanly in --release" do
    gd_src = <<-CR
      surface_material :toon do
        mask = clamp(UV.x * 2.0 - 0.5, -0.5, 1.5)
        inspect :mask_probe, mask
        tinted = inspect(:tint_probe, vec3(mask, 0.4, 0.8))
        ALBEDO = tinted
      end
    CR

    dev_out = CrShader.compile_variant(gd_src, strip_debug_inspects: false)
    dev_out.should contain("group_uniforms Debug;")
    dev_out.should contain("uniform int debug_view : hint_enum(\"Off\", \"mask_probe\", \"tint_probe\", \"NaN_Inf_Detector\") = 0;")
    dev_out.should contain("isnan(_cr_dbg_1)")
    dev_out.should contain("if ((debug_view > 0))")

    rel_out = CrShader.compile_variant(gd_src, strip_debug_inspects: true)
    rel_out.should_not contain("debug_view")
    rel_out.should_not contain("_cr_dbg_")
    rel_out.should contain("vec3 tinted = vec3(mask, 0.4, 0.8);")

    # Also verify `inspect` inside a GLSL `compositor_effect` places visualization BEFORE `imageStore`!
    comp_src = <<-CR
      compositor_effect :post_transparent do
        access :color
        process_pixel do |coord, uv, color|
          luma = color.luminance
          inspect :scene_luma, luma
          color = vec4(vec3(luma, luma, luma), color.a)
        end
      end
    CR

    comp_dev = CrShader.compile_variant(comp_src, target: CrShader::ShaderTarget::GLSL, strip_debug_inspects: false)
    comp_dev.should contain("int debug_view;")
    dbg_pos = comp_dev.index("if ((debug_view > 0))").not_nil!
    store_pos = comp_dev.index("imageStore(color_image").not_nil!
    (dbg_pos < store_pos).should be_true

    comp_rel = CrShader.compile_variant(comp_src, target: CrShader::ShaderTarget::GLSL, strip_debug_inspects: true)
    comp_rel.should_not contain("debug_view")
  end

  it "includes new archetypes, traits, gradients, fluent methods, and artist stdlib in generated LSP stubs" do
    stubs = CrShader::StubGenerator.generate
    stubs.should contain("def sprite_effect")
    stubs.should contain("def screen_effect")
    stubs.should contain("def ui_effect")
    stubs.should contain("def surface_material")
    stubs.should contain("def shader_trait")
    stubs.should contain("def use_trait")
    stubs.should contain("def gradient")
    stubs.should contain("def inspect")
    stubs.should contain("def sdf2d_rounded_box")
    stubs.should contain("def triplanar_sample")
  end
end
