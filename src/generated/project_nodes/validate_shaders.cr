# Generated strongly typed wrapper for GDScript node `ValidateShaders`
# Script Path: res://scripts/validate_shaders.gd
module Godot
  class ValidateShaders < Godot::SceneTree
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end

    # Method `_init` -> Void
    def _init : Void
      call("_init")
      nil
    end
  end
end

alias ValidateShaders = Godot::ValidateShaders
