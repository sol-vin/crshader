require "./spec_helper"

describe CrShader::TreeShaker do
  it "only emits used stdlib functions and eliminates unused ones" do
    source = <<-CR
      shader_type :spatial
      require "math"

      def fragment()
        val = saturate(0.5)
        ALBEDO = vec3(val, val, val)
      end
    CR

    output = CrShader.compile(source)
    # saturate should be emitted
    output.should contain("float saturate(float x) {")
    output.should contain("clamp(x, 0.0, 1.0)")

    # other math functions like rotate_2d, remap, fresnel should NOT be emitted
    output.should_not contain("rotate_2d")
    output.should_not contain("remap")
    output.should_not contain("fresnel")
  end

  it "recursively resolves nested helper dependencies" do
    source = <<-CR
      shader_type :spatial
      require "noise"

      def fragment()
        val = value_noise(vec2(1.0, 2.0))
        ALBEDO = vec3(val, val, val)
      end
    CR

    output = CrShader.compile(source)
    # value_noise calls hash11, so both value_noise and hash11 should be emitted!
    output.should contain("value_noise")
    output.should contain("hash11")

    # unused noise functions like voronoi should NOT be emitted
    output.should_not contain("voronoi")
  end
end
