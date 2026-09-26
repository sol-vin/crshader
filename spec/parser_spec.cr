require "./spec_helper"

describe CrShader::DslParser do
  it "parses setup_gdshader both with and without parentheses" do
    source_no_parens = "setup_gdshader\n"
    parser1 = CrShader::DslParser.new
    prog1 = parser1.parse(source_no_parens)
    prog1.setup_gdshader.should be_true

    source_parens = "setup_gdshader()\n"
    parser2 = CrShader::DslParser.new
    prog2 = parser2.parse(source_parens)
    prog2.setup_gdshader.should be_true
  end

  it "parses shader_type and render_mode" do
    source = <<-CR
      shader_type :spatial
      render_mode :cull_disabled, :depth_draw_opaque
    CR
    parser = CrShader::DslParser.new
    prog = parser.parse(source)
    prog.shader_type.should eq(CrShader::ShaderType::Spatial)
    prog.render_modes.should eq(["cull_disabled", "depth_draw_opaque"])
  end

  it "parses uniforms with type declarations, defaults, and hints" do
    source = <<-CR
      uniform albedo : Color = Color.new(0.8, 0.2, 0.3, 1.0), hint: :source_color
      uniform roughness : Float32 = 0.5, hint: hint_range(0.0, 1.0)
      uniform tex : Sampler2D, filter: :linear_mipmap, repeat: :enable
    CR
    parser = CrShader::DslParser.new
    prog = parser.parse(source)
    prog.uniforms.size.should eq(3)

    u1 = prog.uniforms[0]
    u1.name.should eq("albedo")
    u1.type_name.should eq("Color")
    u1.hints.should eq(["source_color"])

    u2 = prog.uniforms[1]
    u2.name.should eq("roughness")
    u2.hints.should eq(["hint_range(0.0, 1.0)"])

    u3 = prog.uniforms[2]
    u3.name.should eq("tex")
    u3.type_name.should eq("Sampler2D")
    u3.hints.should eq(["filter_linear_mipmap", "repeat_enable"])
  end

  it "parses varying declarations" do
    source = <<-CR
      varying v_normal : Vec3
      varying v_color : Vec4, qualifier: :flat
    CR
    parser = CrShader::DslParser.new
    prog = parser.parse(source)
    prog.varyings.size.should eq(2)
    prog.varyings[0].name.should eq("v_normal")
    prog.varyings[0].qualifier.should be_nil
    prog.varyings[1].name.should eq("v_color")
    prog.varyings[1].qualifier.should eq("flat")
  end

  it "parses compute layout and buffer declarations" do
    source = <<-CR
      shader_type :compute
      local_size 16, 16, 1
      buffer DataBuffer, set: 0, binding: 1, std: :std430, restrict: true do
        field values : Array(Float32)
      end
    CR
    parser = CrShader::DslParser.new
    prog = parser.parse(source)
    prog.shader_type.should eq(CrShader::ShaderType::Compute)
    prog.target.should eq(CrShader::ShaderTarget::GLSL)
    prog.compute_layout.x.should eq(16)
    prog.compute_layout.y.should eq(16)
    prog.buffers.size.should eq(1)
    prog.buffers[0].name.should eq("DataBuffer")
    prog.buffers[0].set.should eq(0)
    prog.buffers[0].binding.should eq(1)
    prog.buffers[0].restrict.should be_true
    prog.buffers[0].fields.size.should eq(1)
    prog.buffers[0].fields[0].is_array.should be_true
  end
end
