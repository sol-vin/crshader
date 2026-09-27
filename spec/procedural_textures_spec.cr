require "./spec_helper"
require "../src/crshader/editor/procedural_textures"

describe "CrShader::ProceduralTextures" do
  it "lists all standard procedural presets" do
    presets = CrShader::ProceduralTextures.presets
    presets.should contain("Checkerboard")
    presets.should contain("UV Gradient")
    presets.should contain("Flat Normal (0,0,1)")
    presets.should contain("Color Bars")
    presets.should contain("Concentric Target")
  end

  it "generates valid SVG markup for checkerboard" do
    svg = CrShader::ProceduralTextures.svg_checkerboard(tiles: 4, size: 128)
    svg.should contain("<svg")
    svg.should contain("width=\"128\"")
    svg.should contain("height=\"128\"")
    svg.should contain("</svg>")
  end

  it "generates valid SVG markup for UV gradient" do
    svg = CrShader::ProceduralTextures.svg_uv_gradient(size: 256)
    svg.should contain("linearGradient id=\"gx\"")
    svg.should contain("linearGradient id=\"gy\"")
  end

  it "generates valid SVG markup for flat normal map" do
    svg = CrShader::ProceduralTextures.svg_flat_normal(size: 64)
    svg.should contain("#8080ff")
  end

  it "generates valid SVG markup for color bars" do
    svg = CrShader::ProceduralTextures.svg_color_bars(size: 140)
    svg.should contain("#ffffff")
    svg.should contain("#0000ff")
  end

  it "generates valid SVG markup for concentric target" do
    svg = CrShader::ProceduralTextures.svg_concentric_target(size: 200)
    svg.should contain("<circle")
    svg.should contain("<line")
  end

  it "manages texture cache" do
    CrShader::ProceduralTextures.clear_cache
    # In headless specs, get may return nil if Godot engine isn't running, but shouldn't raise
    CrShader::ProceduralTextures.get("Checkerboard")
    CrShader::ProceduralTextures.clear_cache
  end
end
