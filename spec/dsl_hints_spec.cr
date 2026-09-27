require "./spec_helper"
require "../src/crshader/compiler"

describe "CrShader Uniform Hints & Groups" do
  it "parses and normalizes hint_range and source_color correctly" do
    source = <<-CR
      shader_type :canvas_item

      group "Lighting"
      subgroup "Parameters"
      uniform speed : Float32 = 1.0, hint: range(0.0, 5.0, 0.1)
      uniform tint : Vec4 = vec4(1.0, 0.5, 0.2, 1.0), hint: :source_color

      def fragment
        COLOR = tint * speed
      end
    CR

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    speed_uni = program.uniforms.find { |u| u.name == "speed" }.not_nil!
    speed_uni.hints.should contain("hint_range(0.0, 5.0, 0.1)")
    speed_uni.group.should eq("Lighting")
    speed_uni.subgroup.should eq("Parameters")

    tint_uni = program.uniforms.find { |u| u.name == "tint" }.not_nil!
    tint_uni.hints.should contain("source_color")

    # Transpilation check
    compiled = CrShader.compile(source)
    compiled.should contain("group_uniforms Lighting;")
    compiled.should contain("group_uniforms.Parameters;")
    compiled.should contain("uniform float speed : hint_range(0.0, 5.0, 0.1) = 1.0;")
    compiled.should contain("uniform vec4 tint : source_color")
  end
end
