require "spec"
require "lapis"

include Lapis::Test

test_suite "Editor" do
  test "CrShaderPlugin is registered as EditorPlugin" do
    entry = Godot::ClassRegistry.find("CrShaderPlugin")
    assert_not_nil entry, "Expected CrShaderPlugin to be registered"
    assert_eq entry.not_nil!.parent_name, "EditorPlugin"
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
end
