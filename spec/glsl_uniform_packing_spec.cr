require "./spec_helper"
require "../src/crshader/transpiler/glsl/layout_packer"
require "../src/crshader/compositor/compositor_effect_base"

describe "CrShader GLSL Vulkan Uniform Packing (std430 / std140)" do
  it "computes Vulkan-compliant std430 push_constant offsets including vec3 16-byte alignment" do
    source = <<-CR
      compositor_effect :post_transparent do
        access :color, :depth

        property thickness : Float32 = 1.5
        property samples : Int32 = 8
        property tint_rgb : Vec3 = vec3(0.1, 0.2, 0.3)
        property opacity : Float32 = 0.9
        property edge_color : Vec4 = vec4(0.0, 0.0, 0.0, 1.0)

        process_pixel do |coord, color|
          color.rgb = mix(color.rgb, edge_color.rgb + tint_rgb, opacity * thickness * float(samples) * 0.01)
        end
      end
    CR

    parser = CrShader::DslParser.new(default_target: CrShader::ShaderTarget::GLSL, force_target: true)
    prog = parser.parse(source)
    layout = CrShader::GLSLLayoutPacker.compute_layout(prog)

    layout.kind.should eq(CrShader::GLSLLayoutPacker::PackingKind::PushConstant)
    # thickness: offset 0 (4B)
    # samples:   offset 4 (4B)
    # tint_rgb:  vec3 requires 16B alignment -> offset 16 (12B, ends at 28!)
    # opacity:   float requires 4B alignment -> packs cleanly into vec3 tail at offset 28 (4B, ends at 32!)
    # edge_color: vec4 requires 16B alignment -> offset 32 (16B, ends at 48!)
    offsets = layout.fields.to_h { |f| {f.name, f.byte_offset} }
    offsets["thickness"].should eq(0)
    offsets["samples"].should eq(4)
    offsets["tint_rgb"].should eq(16)
    offsets["opacity"].should eq(28)
    offsets["edge_color"].should eq(32)
    layout.total_bytes.should eq(48)

    glsl = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    glsl.should contain("layout(push_constant, std430) uniform CrShaderParams {")
    glsl.should_not contain("CrShaderUniforms")
  end

  it "falls back automatically to set = 1, binding = 0 std140 UBO when uniform payload exceeds 128 bytes" do
    source = <<-CR
      shader_type :compute
      local_size 8, 8, 1

      uniform m0 : Mat4
      uniform m1 : Mat4
      uniform extra_tint : Vec4 = vec4(1.0)

      image2d color_image, format: :rgba16f, set: 0, binding: 0

      def main
        c = ivec2(gl_GlobalInvocationID.xy)
        v = m0 * (m1 * extra_tint)
        imageStore(color_image, c, v)
      end
    CR

    parser = CrShader::DslParser.new(default_target: CrShader::ShaderTarget::GLSL, force_target: true)
    prog = parser.parse(source)
    layout = CrShader::GLSLLayoutPacker.compute_layout(prog)

    # 64 + 64 + 16 = 144 bytes > 128 bytes push_constant cap
    layout.kind.should eq(CrShader::GLSLLayoutPacker::PackingKind::UniformBuffer)
    layout.total_bytes.should eq(144)

    glsl = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    glsl.should contain("layout(set = 1, binding = 0, std140) uniform CrShaderUniforms {")
  end

  it "emits CrShaderSceneData UBO (set = 0, binding = 3) when compositor accesses :scene_data" do
    source = <<-CR
      compositor_effect :post_transparent do
        access :color, :depth, :normal_roughness, :scene_data

        process_pixel do |coord, uv, color|
          raw_d = texelFetch(depth_texture, coord, 0).r
          clip = vec4(uv * 2.0 - 1.0, raw_d, 1.0)
          vp = INV_PROJECTION_MATRIX * clip
          nr = texelFetch(normal_roughness_texture, coord, 0)
          color.rgb += (vp.xyz / vp.w) * 0.001 + nr.xyz * 0.001 + vec3(TIME * 0.0)
        end
      end
    CR

    glsl = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    glsl.should contain("layout(set = 0, binding = 1) uniform sampler2D depth_texture;")
    glsl.should contain("layout(set = 0, binding = 2) uniform sampler2D normal_roughness_texture;")
    glsl.should contain("layout(set = 0, binding = 3, std140) uniform CrShaderSceneData {")
    glsl.should contain("mat4 INV_PROJECTION_MATRIX;")
    glsl.should contain("mat4 PROJECTION_MATRIX;")
    glsl.should contain("vec2 VIEWPORT_SIZE;")
    glsl.should contain("float TIME;")
  end

  it "compiles DSL source in CRShaderCompositorEffect and tracks parameter overrides" do
    effect = CrShader::CRShaderCompositorEffect.new
    effect.set_shader_code(<<-CR)
      compositor_effect :post_opaque do
        access :color, :depth, :normal_roughness
        property edge_strength : Float32 = 1.0
        process_pixel do |coord, color|
          color.rgb *= edge_strength
        end
      end
    CR

    effect.compiled_glsl.should contain("#version 450")
    effect.needs_depth_buffer.should be_true
    effect.needs_normal_roughness_buffer.should be_true
    effect.stage_callback.should eq(1) # PostOpaque
    effect.set_shader_parameter("edge_strength", 2.5_f32)
    effect.parameter_overrides["edge_strength"].should eq(2.5_f32)
  end
end
