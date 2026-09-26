# Generated strongly typed wrapper for GDScript node `CrShaderStudioPanel`
# Script Path:
module Godot
  class CrShaderStudioPanel < Godot::Control
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end
  end
end

alias CrShaderStudioPanel = Godot::CrShaderStudioPanel
