require "./spec_helper"
require "../src/crshader/compositor/compositor_effect_base"

describe "CrShader::CRShaderCompositorEffect" do
  it "defines the tool node with exported configuration properties" do
    effect = CrShader::CRShaderCompositorEffect.new
    effect.intensity.should eq(1.0_f32)
    effect.needs_depth_buffer.should be_true
    effect.stage_callback.should eq(4) # PostTransparent
  end
end
