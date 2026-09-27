require "./spec_helper"
require "../src/crshader/parser/tres_reader"

describe "CrShader::TresReader (ColorPalette)" do
  it "parses Godot 4 ColorPalette with PackedColorArray" do
    tres_text = <<-TRES
    [gd_resource type="ColorPalette" format=3]

    [resource]
    colors = PackedColorArray(Color(0, 0, 0, 1), Color(1, 0, 0, 1), Color(0, 1, 0, 1), Color(0, 0, 1, 1))
    TRES

    data = CrShader::TresReader.parse_string(tres_text)
    data.resource_type.should eq("ColorPalette")
    data.elem_type.should eq("Color")
    data.size.should eq(4)
    data.colors[0].should eq({0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32})
    data.colors[1].should eq({1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32})

    nodes = data.to_ast_nodes
    nodes.size.should eq(4)
  end

  it "parses ColorPalette with multiple colors" do
    tres_text = <<-TRES
    [gd_resource type="ColorPalette" format=3]

    [resource]
    colors = PackedColorArray(Color(0, 0, 0, 1), Color(1, 1, 1, 1), Color(0, 0.85098, 0.05098, 1))
    TRES

    data = CrShader::TresReader.parse_string(tres_text)
    data.elem_type.should eq("Color")
    data.size.should eq(3)
    data.colors[2][1].should be_close(0.85098_f32, 0.001_f32)
  end

  it "writes and re-reads a Godot 4 ColorPalette .tres" do
    temp_path = File.join("scratch", "spec_test_palette.tres")
    test_colors = [
      {0.1_f32, 0.2_f32, 0.3_f32, 1.0_f32},
      {0.4_f32, 0.5_f32, 0.6_f32, 1.0_f32}
    ]

    ok = CrShader::TresReader.write_color_palette(temp_path, test_colors)
    ok.should be_true

    data = CrShader::TresReader.read(temp_path)
    data.should_not be_nil
    if data
      data.elem_type.should eq("Color")
      data.size.should eq(2)
      data.colors[0][0].should be_close(0.1_f32, 0.001_f32)
    end
    File.delete(temp_path) if File.exists?(temp_path)
    Dir.delete("scratch") if Dir.exists?("scratch") && Dir.empty?("scratch")
  end
end
