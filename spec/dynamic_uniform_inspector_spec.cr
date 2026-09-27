require "./spec_helper"
require "../src/crshader/editor/dynamic_uniform_inspector"
require "../src/crshader/parser/dsl_parser"

describe "CrShader::DynamicUniformInspector" do
  it "initializes without errors" do
    inspector = CrShader::DynamicUniformInspector.new
    inspector.should_not be_nil
    inspector.default_values.should be_empty
  end

  it "parses uniforms and configures default value tracking" do
    source = <<-CR
      shader_type :canvas_item

      uniform speed : Float32 = 2.5, hint: range(0.0, 10.0, 0.5)
      uniform tint : Color = Color.new(0.2, 0.4, 0.8, 1.0), hint: :source_color
      uniform is_enabled : Bool = true
      uniform palette : Array(Color) = []

      def fragment
        COLOR = tint * speed
      end
    CR

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    inspector = CrShader::DynamicUniformInspector.new
    inspector.configure(program, nil)

    inspector.default_values.has_key?("speed").should be_true
    inspector.default_values["speed"].should eq(2.5)
  end
end
