require "spec"
require "lapis"
require "../../src/crshader/addon"

include Lapis::Test

test_suite "Editor" do
  test "CrShaderPlugin is registered as EditorPlugin" do
    entry = Godot::ClassRegistry.find("CrShaderPlugin")
    assert_not_nil entry, "Expected CrShaderPlugin to be registered"
    assert_eq entry.not_nil!.parent_name, "EditorPlugin"
  end

  test "CrShaderTabEditor is registered as VBoxContainer tool" do
    entry = Godot::ClassRegistry.find("CrShaderTabEditor")
    assert_not_nil entry, "Expected CrShaderTabEditor to be registered"
    assert_eq entry.not_nil!.parent_name, "VBoxContainer"
    assert_true entry.not_nil!.is_tool, "CrShaderTabEditor must have is_tool == true"
  end

  test "ShaderCreateDialogIntegration normalizes paths to .crshader" do
    assert_eq CrShader::ShaderCreateDialogIntegration.to_crshader_path("res://new_shader.gdshader"), "res://new_shader.crshader"
    assert_eq CrShader::ShaderCreateDialogIntegration.to_crshader_path("res://shaders/water.tres"), "res://shaders/water.crshader"
    assert_eq CrShader::ShaderCreateDialogIntegration.to_crshader_path("res://shaders/common.gdshaderinc"), "res://shaders/common.crshader"
    assert_eq CrShader::ShaderCreateDialogIntegration.to_crshader_path("shaders/outline"), "res://shaders/outline.crshader"
  end

  test "ShaderEditorIntegration and ShaderCreateDialogIntegration steady-state sync is O(1)" do
    # Warm up initial hook lookup if running inside live Godot Editor
    CrShader::ShaderEditorIntegration.sync_shader_tabs!
    CrShader::ShaderCreateDialogIntegration.sync_dialogs!

    t0 = Time.instant
    500.times do
      CrShader::ShaderEditorIntegration.sync_shader_tabs!
    end
    elapsed_ms = (Time.instant - t0).total_milliseconds
    assert_true elapsed_ms < 250.0, "Expected 500 steady-state sync_shader_tabs! ticks in < 250ms, got #{elapsed_ms.round(2)}ms"
  end
end

test_case "Editor", "CrShaderPlugin is marked as tool" do
  entry = Godot::ClassRegistry.find("CrShaderPlugin")
  assert_not_nil entry, "Expected CrShaderPlugin to be registered"
  assert_true entry.not_nil!.is_tool, "CrShaderPlugin must have is_tool == true"
end

test_case "Editor", "CrShaderStudioPanel is registered and marked as tool" do
  entry = Godot::ClassRegistry.find("CrShaderStudioPanel")
  assert_not_nil entry, "Expected CrShaderStudioPanel to be registered"
  assert_eq entry.not_nil!.parent_name, "Control"
  assert_true entry.not_nil!.is_tool, "CrShaderStudioPanel must have is_tool == true"
end

describe "Addon In-Editor Test Suite" do
  it "registers addon in-editor tests with Lapis::Test" do
    tests = Registry.all_tests
    tests.should_not be_empty
  end

  it "normalizes shader creation dialog paths to .crshader" do
    CrShader::ShaderCreateDialogIntegration.to_crshader_path("res://new_shader.gdshader").should eq("res://new_shader.crshader")
    CrShader::ShaderCreateDialogIntegration.to_crshader_path("res://fx/bloom.glsl").should eq("res://fx/bloom.crshader")
    CrShader::ShaderCreateDialogIntegration.to_crshader_path("").should eq("res://new_shader.crshader")
  end
end
