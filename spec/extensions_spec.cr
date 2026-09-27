require "./spec_helper"
require "../src/crshader/extensions/pipeline"
require "../src/crshader/extensions/samples/debug_overlay_extension"

describe "CrShader Extensibility Architecture" do
  it "dispatches custom directives to registered extensions" do
    ext = CrShader::DebugOverlayExtension.new
    CrShader::Extensions.register(ext)

    source = <<-CR
      shader_type :spatial
      debug_overlay :normals

      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    code = CrShader::Pipeline.compile(source)
    code.should contain("uniform bool debug_overlay_enabled = false;")

    # Cleanup
    CrShader::Extensions.unregister("debug_overlay")
  end

  it "allows extensions to hook custom validation rules" do
    custom_ext = CustomRuleExtension.new
    CrShader::Extensions.register(custom_ext)

    source = <<-CR
      shader_type :spatial

      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Custom rule violation: Shaders must define a roughness uniform/) do
      CrShader::Pipeline.compile(source)
    end

    CrShader::Extensions.unregister(custom_ext.name)
  end
end

class CustomRuleExtension < CrShader::Extension
  getter name : String = "custom_rule_ext"

  def validate(program : CrShader::ShaderProgram, context : CrShader::Validator::ValidationContext) : Nil
    has_roughness = program.uniforms.any? { |u| u.name == "roughness" }
    unless has_roughness
      context.error(
        "Custom rule violation: Shaders must define a roughness uniform.",
        tip: "Add uniform roughness : Float32 = 0.5"
      )
    end
  end
end
