require "spec"
require "../src/main"

describe CrShaderPlugin do
  it "registers with Godot ClassRegistry as EditorPlugin" do
    entry = Godot::ClassRegistry.find("CrShaderPlugin")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("EditorPlugin")
  end

  it "is marked as tool node for editor execution" do
    entry = Godot::ClassRegistry.find("CrShaderPlugin")
    entry.should_not be_nil
    entry.not_nil!.is_tool.should be_true
  end
end

describe CrShader::CrShaderStudioPanel do
  it "registers with Godot ClassRegistry as Control" do
    entry = Godot::ClassRegistry.find("CrShaderStudioPanel")
    entry.should_not be_nil
    entry.not_nil!.parent_name.should eq("Control")
  end

  it "is marked as tool node for in-editor studio dock" do
    entry = Godot::ClassRegistry.find("CrShaderStudioPanel")
    entry.should_not be_nil
    entry.not_nil!.is_tool.should be_true
  end
end
