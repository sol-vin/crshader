require "./spec_helper"
require "file_utils"

describe "CrShader Cross-Shader Modules & GDShader/GLSL Interop" do
  it "resolves relative and diamond require modules, sharing macros, structs, constants, uniforms, and helpers" do
    tmp_dir = File.join(Dir.tempdir, "crshader_mod_spec_#{Random.rand(100000)}")
    Dir.mkdir_p(tmp_dir)
    begin
      base_mod = File.join(tmp_dir, "common_types.crshader")
      File.write(base_mod, <<-CR)
        const BASE_SCALE : Float32 = 2.0

        struct PixelSample
          id : UInt32
          depth : Float32
        end

        macro scale_val(x)
          (({{x}}) * BASE_SCALE)
        end

        def make_sample(raw_id : UInt32, d : Float32) : PixelSample
          return PixelSample.new(raw_id, d)
        end
      CR

      helper_a = File.join(tmp_dir, "branch_a.crshader")
      File.write(helper_a, <<-CR)
        require "./common_types"

        group "Outline"
        subgroup "Stroke"
        # Pixel stroke width
        uniform stroke_width : Float32 = 1.5, hint: range(0.0, 8.0, 0.5)

        def eval_a(d : Float32) : Float32
          s = make_sample(7_u32, d)
          return scale_val(s.depth) + stroke_width
        end
      CR

      helper_b = File.join(tmp_dir, "branch_b.crshader")
      File.write(helper_b, <<-CR)
        require "./common_types"

        def eval_b(d : Float32) : UInt32
          s = make_sample(28_u32, d)
          return s.id
        end
      CR

      main_shader = File.join(tmp_dir, "main_test.crshader")
      File.write(main_shader, <<-CR)
        shader_type :spatial
        render_mode :unshaded

        require "./branch_a"
        require "./branch_b"

        uniform tint : Vec4 = vec4(1.0, 0.5, 0.2, 1.0), hint: :source_color

        def fragment
          val_a = eval_a(0.5)
          id_b = eval_b(0.25)
          world_p = INV_VIEW_MATRIX * vec4(VERTEX, 1.0)
          n_view = VIEW_MATRIX * vec4(NORMAL, 0.0)
          ALBEDO = tint.rgb * val_a + world_p.xyz * 0.001 + n_view.xyz * float(id_b) * 0.01
        end
      CR

      compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)
      code = compiler.compile_file(main_shader)

      # Diamond deduplication: struct & constant emitted once
      code.scan("struct PixelSample {").size.should eq(1)
      code.scan("const float BASE_SCALE").size.should eq(1)

      # Unsigned literal suffix + struct field inference
      code.should contain("7u")
      code.should contain("28u")
      code.should contain("PixelSample s = make_sample(")
      code.should contain("uint id_b = eval_b(0.25);")

      # Matrix * Vector product type inference (vec4, not mat4!)
      code.should contain("vec4 world_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0));")

      # Uniform group + subgroup + group reset + doc comment
      code.should contain("group_uniforms Outline;")
      code.should contain("group_uniforms Outline.Stroke;")
      code.should contain("/** Pixel stroke width */")
      code.should contain("group_uniforms;\nuniform vec4 tint : source_color")
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end

  it "exports reusable .gdshaderinc library headers with #ifndef guards and no shader_type" do
    source = <<-CR
      const GOLDEN_RATIO : Float32 = 1.6180339

      struct EdgeHit
        found : Bool
        weight : Float32
      end

      group "SharedOutline"
      # Shared edge thickness
      uniform edge_width : Float32 = 2.0, hint: range(0.0, 10.0, 0.5)

      def compute_edge(d0 : Float32, d1 : Float32) : EdgeHit
        diff = abs(d0 - d1)
        return EdgeHit.new(diff > 0.05, diff * GOLDEN_RATIO)
      end
    CR

    inc_code = CrShader.compile(source, target: CrShader::ShaderTarget::GDShaderInc)
    inc_code.should contain("#ifndef ")
    inc_code.should contain("_GDSHADERINC")
    inc_code.should contain("#endif")
    inc_code.should_not contain("shader_type ")
    inc_code.should contain("const float GOLDEN_RATIO = 1.6180339;")
    inc_code.should contain("struct EdgeHit {")
    inc_code.should contain("group_uniforms SharedOutline;")
    inc_code.should contain("/** Shared edge thickness */")
    inc_code.should contain("uniform float edge_width : hint_range(0.0, 10.0, 0.5) = 2.0;")
    inc_code.should contain("group_uniforms;")
    inc_code.should contain("EdgeHit compute_edge(float d0, float d1) {")
  end

  it "imports signatures from existing .gdshaderinc files via include for accurate type inference" do
    tmp_dir = File.join(Dir.tempdir, "crshader_inc_spec_#{Random.rand(100000)}")
    Dir.mkdir_p(tmp_dir)
    begin
      inc_path = File.join(tmp_dir, "legacy_depth.gdshaderinc")
      File.write(inc_path, <<-GDSHADERINC)
        #ifndef LEGACY_DEPTH_GDSHADERINC
        #define LEGACY_DEPTH_GDSHADERINC

        const float DEPTH_BIAS = 0.0025;

        struct LegacyHit {
          vec3 normal;
          float dist;
        };

        vec3 reconstruct_legacy_pos(vec2 uv, float raw_d, mat4 inv_proj) {
          vec4 clip = vec4(uv * 2.0 - 1.0, raw_d, 1.0);
          vec4 vp = inv_proj * clip;
          return vp.xyz / vp.w;
        }

        LegacyHit build_legacy_hit(vec3 n, float d) {
          return LegacyHit(n, d + DEPTH_BIAS);
        }

        #endif
      GDSHADERINC

      cr_path = File.join(tmp_dir, "consumer.crshader")
      File.write(cr_path, <<-CR)
        shader_type :spatial
        render_mode :unshaded

        include "./legacy_depth.gdshaderinc"
        uniform depth_tex : Sampler2D, hint: :depth_texture

        def fragment
          raw_d = texture(depth_tex, SCREEN_UV).r
          pos = reconstruct_legacy_pos(SCREEN_UV, raw_d, INV_PROJECTION_MATRIX)
          hit = build_legacy_hit(NORMAL, length(pos) + DEPTH_BIAS)
          ALBEDO = hit.normal * hit.dist
        end
      CR

      compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)
      code = compiler.compile_file(cr_path)

      code.should contain("#include \"./legacy_depth.gdshaderinc\"")
      # Must NOT re-emit the external function or struct body
      code.should_not contain("vec3 reconstruct_legacy_pos(vec2 uv")
      code.should_not contain("struct LegacyHit {")
      # Must infer exact return types from the scanned .gdshaderinc header!
      code.should contain("vec3 pos = reconstruct_legacy_pos(")
      code.should contain("LegacyHit hit = build_legacy_hit(")
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end

  it "supports TARGET / IS_GLSL / IS_GDSHADER conditional compilation from one source" do
    dual_source = <<-CR
      {% if IS_GLSL %}
        shader_type :compute
        local_size 8, 8, 1
      {% else %}
        shader_type :canvas_item
      {% end %}

      def shared_luma(c : Vec3) : Float32
        return dot(c, vec3(0.299, 0.587, 0.114))
      end

      {% if TARGET == :glsl %}
        image2d out_img, format: :rgba16f, set: 0, binding: 0
        def main
          coord = ivec2(gl_GlobalInvocationID.xy)
          lum = shared_luma(vec3(0.4, 0.6, 0.2))
          imageStore(out_img, coord, vec4(vec3(lum), 1.0))
        end
      {% else %}
        def fragment
          lum = shared_luma(COLOR.rgb)
          COLOR = vec4(vec3(lum), 1.0)
        end
      {% end %}
    CR

    gd_out = CrShader.compile(dual_source, target: CrShader::ShaderTarget::GDShader)
    gd_out.should contain("shader_type canvas_item;")
    gd_out.should contain("float shared_luma(vec3 c)")
    gd_out.should contain("void fragment()")
    gd_out.should_not contain("imageStore")

    glsl_out = CrShader.compile(dual_source, target: CrShader::ShaderTarget::GLSL)
    glsl_out.should contain("#version 450")
    glsl_out.should contain("float shared_luma(vec3 c)")
    glsl_out.should contain("void main()")
    glsl_out.should contain("imageStore(out_img")
  end
end
