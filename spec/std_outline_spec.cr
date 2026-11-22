require "./spec_helper"
require "../src/crshader/generator/node_generator"

describe "CrShader std/outline Toolkit & Multi-Cue Outline Shaders" do
  it "compiles a Spatial screen-space ID + depth + morphological bevel/boil outline shader to valid GDShader and GDShaderInc" do
    source = <<-CR
      shader_type :spatial
      render_mode :unshaded, :depth_draw_never, :depth_test_disabled

      require "std/outline"

      uniform screen_tex : Sampler2D, hint: :screen_texture, filter: :nearest
      uniform depth_tex : Sampler2D, hint: :depth_texture, filter: :nearest

      group "Outline"
      # Pixel radius of morphological outline
      uniform radius_px : Float32 = 2.0, hint: range(0.5, 8.0, 0.5)
      uniform boil_amp_px : Float32 = 0.75, hint: range(0.0, 4.0, 0.25)
      uniform line_color : Vec4 = vec4(0.05, 0.04, 0.08, 1.0), hint: :source_color

      def fragment
        texel = vec2(1.0) / VIEWPORT_SIZE
        wobbled_uv = apply_line_boil(SCREEN_UV, texel, TIME, 8.0, boil_amp_px, 2.0)

        center_col = texture(screen_tex, wobbled_uv)
        center_info = decode_outline_pixel(center_col)
        center_raw_d = texture(depth_tex, wobbled_uv).r
        center_vpos = reconstruct_view_pos(wobbled_uv, center_raw_d, INV_PROJECTION_MATRIX)
        center_z = -center_vpos.z

        best_z = 1000000.0
        has_edge = false

        (0...24).each do |i|
          s_uv = clamp(wobbled_uv + OUTLINE_DIRS_24[i] * texel * radius_px, vec2(0.0005), vec2(0.9995))
          n_info = decode_outline_pixel(texture(screen_tex, s_uv))
          n_raw_d = texture(depth_tex, s_uv).r
          n_z = linear_view_depth(s_uv, n_raw_d, INV_PROJECTION_MATRIX)

          id_diff = (center_info.valid && n_info.valid) && (center_info.surface_id != n_info.surface_id)
          d_diff = is_depth_edge(center_z, n_z, 0.08, 1.0)

          if (id_diff || d_diff) && (n_z < best_z)
            best_z = n_z
            has_edge = true
          end
        end

        bevel = apply_win98_bevel(line_color.rgb, OUTLINE_DIRS_8[0], 0.25, 0.3)
        ALBEDO = has_edge ? bevel : srgb_to_linear(center_info.rgb)
        ALPHA = has_edge ? line_color.a : 0.0
      end
    CR

    gd = CrShader.compile(source, target: CrShader::ShaderTarget::GDShader)
    gd.should contain("shader_type spatial;")
    gd.should contain("render_mode unshaded, depth_draw_never, depth_test_disabled;")
    gd.should contain("const vec2 OUTLINE_DIRS_24[24] =")
    gd.should contain("PixelOutlineSample decode_outline_pixel(")
    gd.should contain("vec3 reconstruct_view_pos(")
    gd.should contain("vec3 apply_win98_bevel(")
    gd.should contain("vec2 apply_line_boil(")
    gd.should contain("floatBitsToUint")

    # Verify the same outline shader exports cleanly as a .gdshaderinc header
    inc = CrShader.compile(source, target: CrShader::ShaderTarget::GDShaderInc)
    inc.should contain("#ifndef ")
    inc.should contain("PixelOutlineSample decode_outline_pixel(")
    inc.should_not contain("void fragment()")
  end

  it "compiles examples/compositor_multicue_outline.crshader to GLSL 450 and generates a typed CompositorEffect node" do
    example_path = File.expand_path("../examples/compositor_multicue_outline.crshader", __DIR__)
    File.exists?(example_path).should be_true

    compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GLSL)
    glsl = compiler.compile_file(example_path)
    glsl.should contain("#version 450")
    glsl.should contain("layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;")
    glsl.should contain("layout(set = 0, binding = 1) uniform sampler2D depth_texture;")
    glsl.should contain("layout(set = 0, binding = 2) uniform sampler2D normal_roughness_texture;")
    glsl.should contain("layout(set = 0, binding = 3, std140) uniform CrShaderSceneData {")
    glsl.should contain("layout(push_constant, std430) uniform CrShaderParams {")
    glsl.should contain("vec4 unpack_normal_roughness(vec4 raw)")
    glsl.should contain("float grazing_depth_scale(")

    node_code = CrShader::NodeGenerator.generate_from_file(
      example_path,
      CrShader::NodeGenerator::NodeType::CompositorEffect,
      "MultiCueOutlineEffect"
    )
    node_code.should contain("node MultiCueOutlineEffect < CompositorEffect do")
    node_code.should contain("# Outline radius in pixels")
    node_code.should contain("@[Export(range: 4..24, step: 4)]")
    node_code.should contain("property sample_directions : Int32 = 8")
    node_code.should contain("call(\"set_needs_normal_roughness\", true)")
    node_code.should contain("CRShaderCompositorEffect.build_scene_ubo_bytes")
    node_code.should contain("helper.set_push_constant(buf)")
  end

  it "supports Spatial blend_premul_alpha & specular_occlusion_disabled, render_mode before #include, writeonly image2d, and #[compute] header" do
    spatial_src = <<-CR
      shader_type :spatial
      render_mode :blend_premul_alpha, :depth_draw_opaque, :cull_back, :specular_disabled, :specular_occlusion_disabled
      gd_include "res://addons/portals/materials/portalclip_mesh.gdshaderinc"

      def fragment
        ALBEDO = vec3(PI / TAU)
        ALPHA = 125.0 / 128.0
      end

      def light
        if LIGHT_IS_DIRECTIONAL
          SPECULAR_LIGHT += LIGHT_COLOR / PI
        end
      end
    CR

    gd = CrShader.compile(spatial_src, target: CrShader::ShaderTarget::GDShader)
    rm_idx = gd.index("render_mode blend_premul_alpha").not_nil!
    inc_idx = gd.index("#include \"res://addons/portals/materials/portalclip_mesh.gdshaderinc\"").not_nil!
    rm_idx.should be < inc_idx

    compute_src = <<-CR
      shader_type :compute
      local_size 8, 8, 1

      sampler color_texture, set: 0, binding: 0
      image2d :output_image, format: :rgba16f, set: 0, binding: 3, writeonly: true
      buffer PaletteBuffer, instance: :palette, set: 0, binding: 4, std: :std430, readonly: true do
        field colors : Array(Vec4)
      end
      push_constant PushConstants, instance: :params do
        field screen_width : Float32
      end

      def main
        pos = ivec2(gl_GlobalInvocationID.xy)
        if pos.x >= int(params.screen_width)
          return
        end
        col = texelFetch(color_texture, pos, 0) + palette.colors[0]
        imageStore(output_image, pos, col)
      end
    CR

    glsl_compiler = CrShader::Compiler.new(
      target_override: CrShader::ShaderTarget::GLSL,
      godot_compute_header: true
    )
    glsl = glsl_compiler.compile(compute_src)
    glsl.starts_with?("#[compute]\n#version 450").should be_true
    glsl.should contain("layout(rgba16f, set = 0, binding = 3) uniform writeonly image2D output_image;")
    glsl.should contain("layout(set = 0, binding = 4, std430) readonly buffer PaletteBuffer {")
    glsl.should contain("} palette;")
    glsl.should contain("layout(push_constant, std430) uniform PushConstants {")
    glsl.should contain("} params;")
  end
end
