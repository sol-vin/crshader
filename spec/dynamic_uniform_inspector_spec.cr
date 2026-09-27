require "./spec_helper"
require "../src/crshader/editor/dynamic_uniform_inspector"
require "../src/crshader/parser/dsl_parser"

describe "CrShader::DynamicUniformInspector" do
  it "initializes without errors" do
    inspector = CrShader::DynamicUniformInspector.new
    inspector.should_not be_nil
    inspector.default_values.should be_empty
    inspector.lfos.should be_empty
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

  it "handles vector and sampler uniforms gracefully" do
    source = <<-CR
      shader_type :spatial

      uniform offset : Vec2 = Vec2.new(0.5, 0.5)
      uniform direction : Vec3 = Vec3.new(0.0, 1.0, 0.0)
      uniform weights : Vec4 = Vec4.new(1.0, 0.5, 0.2, 1.0)
      uniform albedo_map : Sampler2D, filter: :linear, repeat: :enable

      def fragment
        ALBEDO = direction
      end
    CR

    parser = CrShader::DslParser.new
    program = parser.parse(source)

    inspector = CrShader::DynamicUniformInspector.new
    inspector.configure(program, nil)

    inspector.current_program.should eq(program)
  end

  it "processes LFO animation frame steps" do
    inspector = CrShader::DynamicUniformInspector.new
    # Should not crash when no LFOs are active
    inspector._process(0.016_f64)
    inspector.elapsed_time.should eq(0.0)
  end
end
