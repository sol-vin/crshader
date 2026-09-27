require "./spec_helper"
require "../src/crshader/std/registry"
require "../src/crshader/compiler"

describe "CrShader Standard Library Graphics Expansion" do
  it "loads all registered standard modules" do
    expected_modules = [
      "math", "noise", "color", "lighting", "sdf", "tonemap",
      "triplanar", "post_processing", "compositor",
      "dither", "curl_noise", "color_spaces", "atmosphere", "glitch"
    ]

    expected_modules.each do |mod_name|
      defs = CrShader::Std.load_module(mod_name)
      defs.should_not be_empty, "Module #{mod_name} should contain function definitions"
    end
  end

  it "compiles a shader requiring dither, curl_noise, color_spaces, atmosphere, and glitch" do
    source = <<-CR
      shader_type :canvas_item
      render_mode :unshaded

      require "std/dither"
      require "std/curl_noise"
      require "std/color_spaces"
      require "std/atmosphere"
      require "std/glitch"

      def fragment
        p = ivec2(int(FRAGCOORD.x), int(FRAGCOORD.y))
        b = bayer4x4(p)
        c_rgb = vec3(0.5, 0.2, 0.8)
        lab = linear_srgb_to_oklab(c_rgb)
        rgb_back = oklab_to_linear_srgb(lab)
        curl = curl_noise_2d(UV, 0.01)
        phase = hg_phase(0.5, 0.2)
        jit = scanline_jitter(UV, TIME, 0.05)
        COLOR = vec4(rgb_back.x + b * 0.1 + curl.x * 0.05, rgb_back.y, rgb_back.z, 1.0)
      end
    CR

    compiled = CrShader.compile(source)
    compiled.should contain("shader_type canvas_item;")
    compiled.should contain("bayer4x4")
    compiled.should contain("linear_srgb_to_oklab")
    compiled.should contain("curl_noise_2d")
    compiled.should contain("hg_phase")
    compiled.should contain("scanline_jitter")
  end
end
