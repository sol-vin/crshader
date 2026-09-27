require "./spec_helper"
require "file_utils"
require "../src/crshader/stubs/stub_generator"
require "../src/crshader/language"

describe CrShader::StubGenerator do
  it "generates complete Crystal stubs with mirrored Godot documentation" do
    content = CrShader::StubGenerator.generate
    content.should_not be_empty
    content.should contain("module CrShader")
    content.should contain("module Language")
    content.should contain("module PreProcessors")
    content.should contain("module Stages")
    content.should contain("module DSL")
    content.should contain("module Types")
    content.should contain("module Builtins")
    content.should contain("module Functions")
    content.should contain("CRShader = CrShader")
    content.should contain("Language = CrShader::Language")
  end

  it "documents built-in variables from Godot Engine docs" do
    content = CrShader::StubGenerator.generate
    # CanvasItem
    content.should contain("SCREEN_UV")
    content.should contain("TEXTURE_PIXEL_SIZE")
    content.should contain("SCREEN_PIXEL_SIZE")
    # Spatial
    content.should contain("ALBEDO")
    content.should contain("ROUGHNESS")
    content.should contain("METALLIC")
    content.should contain("MODEL_MATRIX")
    content.should contain("INV_VIEW_MATRIX")
    # Particles
    content.should contain("TRANSFORM")
    content.should contain("VELOCITY")
    # Sky
    content.should contain("EYEDIR")
    content.should contain("LIGHT0_DIRECTION")
    # Fog
    content.should contain("WORLD_POSITION")
    content.should contain("DENSITY")
  end

  it "documents built-in mathematical and texture functions" do
    content = CrShader::StubGenerator.generate
    content.should contain("def smoothstep")
    content.should contain("def clamp")
    content.should contain("def mix")
    content.should contain("def texture")
    content.should contain("def textureLod")
    content.should contain("def textureSize")
    content.should contain("def texelFetch")
    content.should contain("def linear_depth")
    content.should contain("def luminance")
    content.should contain("def fresnel")
  end

  it "writes stubs to a target file on disk" do
    tmp_path = File.join(__DIR__, "..", "scratch", "test_stubs.cr")
    FileUtils.mkdir_p(File.dirname(tmp_path))
    CrShader::StubGenerator.write_to_file(tmp_path)
    File.exists?(tmp_path).should be_true
    File.read(tmp_path).should contain("module CrShader")
    File.read(tmp_path).should contain("module Language")
    FileUtils.rm(tmp_path)
  end
end

describe "CrShader::Language Hierarchy" do
  it "defines PreProcessors and directive methods" do
    CrShader::Language::PreProcessors.should_not be_nil
    CrShader::DSL.should_not be_nil
  end

  it "defines Stages and processor entry points" do
    CrShader::Language::Stages.should_not be_nil
    CrShader::Stages.should_not be_nil
  end

  it "defines Types and vector structs" do
    v = CrShader::Language::Types::Vec2.new(1.0_f32, 2.0_f32)
    v.x.should eq(1.0_f32)
    v.y.should eq(2.0_f32)
    v.xy.x.should eq(1.0_f32)
  end

  it "defines Functions and mathematical helpers" do
    deg = CrShader::Language::Functions.degrees(3.14159265_f32)
    deg.round.should eq(180)
  end

  it "defines Builtins per stage" do
    CrShader::Language::Builtins::CanvasItem::TIME.should eq(0.0_f32)
    CrShader::Language::Builtins::Spatial::ALPHA.should eq(1.0_f32)
  end

  it "provides top-level aliases" do
    CRShader.should eq(CrShader)
    Language.should eq(CrShader::Language)
  end
end
