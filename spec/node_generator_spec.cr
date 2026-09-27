require "./spec_helper"
require "../src/crshader/generator/node_generator"

describe "CrShader::NodeGenerator" do
  it "generates a ScreenSpaceMesh node from .crshader source" do
    source = <<-CR
    shader_type :canvas_item
    uniform dither_strength : Float32 = 0.5, hint: hint_range(0.0, 1.0, 0.05)
    uniform speed : Float32 = 2.0
    uniform target_palette = resource("res://default_palettes/cottonville.tres")

    def fragment
      COLOR = vec4(1.0)
    end
    CR

    code = CrShader::NodeGenerator.generate_from_source(
      source,
      CrShader::NodeGenerator::NodeType::ScreenSpaceMesh,
      "DitherScreenMesh"
    )

    code.should contain("node DitherScreenMesh < MeshInstance3D do")
    code.should contain("@[Export(range: 0.0_f32..1.0_f32, step: 0.05_f32)]")
    code.should contain("property dither_strength : Float32 = 0.5_f32")
    code.should contain("property target_palette : Godot::ColorPalette? = nil")
    code.should contain("def setup_screenspace_mesh")
    code.should contain("quad.call(\"set_size\", Vector2.new(2.0_f32, 2.0_f32))")
    code.should contain("def apply_parameters : Void")
    code.should contain("mat.call(\"set_shader_parameter\", \"dither_strength\", @dither_strength)")
    code.should contain("colors = pal.call(\"get_colors\")")
  end

  it "generates a ScreenSpaceCanvas node" do
    source = <<-CR
    shader_type :canvas_item
    uniform opacity : Float32 = 0.8

    def fragment
      COLOR = vec4(1.0)
    end
    CR

    code = CrShader::NodeGenerator.generate_from_source(
      source,
      CrShader::NodeGenerator::NodeType::ScreenSpaceCanvas,
      "CanvasOverlay"
    )

    code.should contain("node CanvasOverlay < CanvasLayer do")
    code.should contain("property opacity : Float32 = 0.8_f32")
    code.should contain("def setup_canvas_rect")
    code.should contain("call(\"set_layer\", 128)")
    code.should contain("new_rect.call(\"set_anchors_preset\", 15)")
  end

  it "generates a CompositorEffect node" do
    source = <<-CR
    shader_type :compute
    uniform intensity : Float32 = 1.0
    CR

    code = CrShader::NodeGenerator.generate_from_source(
      source,
      CrShader::NodeGenerator::NodeType::CompositorEffect,
      "OutlineCompositor"
    )

    code.should contain("node OutlineCompositor < CompositorEffect do")
    code.should contain("property intensity : Float32 = 1.0_f32")
    code.should contain("call(\"set_access_resolved_color\", true)")
    code.should contain("call(\"set_access_resolved_depth\", true)")
  end
end
