require "./spec_helper"
require "file_utils"
require "../src/crshader"

describe "Feature Specialization & VariantCache" do
  it "specializes boolean, enum, and integer features and prunes disabled uniforms and helpers" do
    source = <<-CR
      shader_type :spatial

      feature :rim_light, default: true
      feature :detail_map, default: false
      feature :quality, options: [:low, :medium, :high], default: :medium
      feature :samples, default: 3

      property base_color : Color = Color.hex("#3b82f6"), hint: :source_color
      sampler detail_tex, filter: :linear
      property detail_strength : Float32 = 0.5

      when_feature :rim_light do
        property rim_color : Color = Color.hex("#66ccff"), hint: :source_color
      end

      def expensive_high_quality(c : Vec3) : Vec3
        c * 1.25
      end

      def fragment
        col = base_color.rgb
        when_feature :detail_map do
          col = mix(col, detail_tex.sample(UV).rgb, detail_strength)
        end
        when_feature :quality, :high do
          col = expensive_high_quality(col)
        end
        acc = 0.0
        {% for i in 0...FEATURE_SAMPLES %}
          acc = acc + {{ i }}.0
        {% end %}
        when_feature :rim_light do
          EMISSION = rim_color.rgb * 0.5
        end
        ALBEDO = col + vec3(acc * 0.01, 0.0, 0.0)
      end
    CR

    # 1. Default variant: rim_light=true, detail_map=false, quality=medium, samples=3
    default_code = CrShader.compile_variant(source)
    default_code.should contain("uniform vec4 rim_color")
    default_code.should_not contain("detail_tex")
    default_code.should_not contain("detail_strength")
    default_code.should_not contain("expensive_high_quality")
    default_code.should contain("acc = (acc + 2.0)")
    default_code.should_not contain("acc = (acc + 3.0)")

    # 2. High-quality + detail_map=true + rim_light=false + samples=5
    hq_code = CrShader.compile_variant(source, features: {
      "rim_light"  => false.as(CrShader::FeatureValue),
      "detail_map" => true.as(CrShader::FeatureValue),
      "quality"    => :high.as(CrShader::FeatureValue),
      "samples"    => 5.as(CrShader::FeatureValue),
    })
    hq_code.should_not contain("rim_color")
    hq_code.should contain("uniform sampler2D detail_tex")
    hq_code.should contain("uniform float detail_strength")
    hq_code.should contain("vec3 expensive_high_quality")
    hq_code.should contain("acc = (acc + 4.0)")
  end

  it "supports unless_feature and array matching in when_feature" do
    source = <<-CR
      shader_type :canvas_item
      feature :mode, options: [:fast, :balanced, :ultra], default: :fast
      feature :grayscale_override, default: false

      def fragment
        c = vec3(1.0, 0.5, 0.2)
        when_feature :mode, [:balanced, :ultra] do
          c = c * 1.5
        end
        unless_feature :grayscale_override do
          c = c + vec3(0.05, 0.05, 0.05)
        end
        COLOR = vec4(c, 1.0)
      end
    CR

    fast_out = CrShader.compile_variant(source)
    fast_out.should_not contain("* 1.5")
    fast_out.should contain("vec3(0.05, 0.05, 0.05)")

    ultra_gray = CrShader.compile_variant(source, features: {
      "mode"               => :ultra.as(CrShader::FeatureValue),
      "grayscale_override" => true.as(CrShader::FeatureValue),
    })
    ultra_gray.should contain("* 1.5")
    ultra_gray.should_not contain("vec3(0.05, 0.05, 0.05)")
  end

  it "caches compiled variants deterministically in VariantCache with O(1) hits and eviction" do
    cache = CrShader::VariantCache.new(max_entries: 2)
    source = <<-CR
      shader_type :spatial
      feature :a, default: true
      feature :b, default: false
      def fragment
        ALBEDO = vec3(1.0, 1.0, 1.0)
      end
    CR

    # Different hash insertion order must produce identical canonical key and hit cache!
    f1 = {"b" => true.as(CrShader::FeatureValue), "a" => false.as(CrShader::FeatureValue)}
    f2 = {"a" => false.as(CrShader::FeatureValue), "b" => true.as(CrShader::FeatureValue)}

    v1 = cache.get_or_compile(source, features: f1)
    cache.stats.misses.should eq(1)
    cache.stats.hits.should eq(0)

    v2 = cache.get_or_compile(source, features: f2)
    v2.key.should eq(v1.key)
    v2.signature.should eq("a=false;b=true")
    cache.stats.hits.should eq(1)
    cache.stats.misses.should eq(1)

    # Trigger max_entries eviction
    cache.get_or_compile(source, features: {"a" => true.as(CrShader::FeatureValue)})
    cache.get_or_compile(source, features: {"b" => false.as(CrShader::FeatureValue)})
    cache.stats.entries.should eq(2)

    cache.clear!
    cache.stats.entries.should eq(0)
    cache.stats.hits.should eq(0)
  end

  it "supports CLI -D defines, --release stripping, and `crshader matrix` permutation output" do
    tmp_dir = File.join(__DIR__, "..", "scratch", "matrix_spec")
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)

    src_file = File.join(tmp_dir, "perm_test.crshader")
    File.write(src_file, <<-CR)
      shader_type :spatial
      feature :rim, default: true
      feature :tier, options: [:low, :high], default: :low

      when_feature :rim do
        property rim_boost : Float32 = 1.0
      end

      def fragment
        v = 0.5
        inspect :half_val, v
        when_feature :rim do
          EMISSION = vec3(rim_boost, 0.0, 0.0)
        end
        ALBEDO = vec3(v, v, v)
      end
    CR

    out_single = File.join(tmp_dir, "single_release.gdshader")
    CrShader::CLI.run(["build", src_file, "-o", out_single, "-D", "rim=false", "--release"])
    single_txt = File.read(out_single)
    single_txt.should_not contain("rim_boost")
    single_txt.should_not contain("debug_view")

    matrix_dir = File.join(tmp_dir, "variants")
    CrShader::CLI.run(["matrix", src_file, "-o", matrix_dir, "--release"])
    generated = Dir.glob(File.join(matrix_dir, "*.gdshader").gsub('\\', '/'))
    # 2 bool states * 2 enum options = 4 variants
    generated.size.should eq(4)

    FileUtils.rm_rf(tmp_dir)
  end
end
