# Generated strongly typed wrapper for GDScript node `CrShaderPlugin`
# Script Path:
module Godot
  class CrShaderPlugin < Godot::EditorPlugin
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end

    # Property `file_timestamps` (Godot::HashStringTime?)
    def file_timestamps : Godot::HashStringTime?
      call_obj_as(Godot::HashStringTime, "get", "file_timestamps")
    end

    def file_timestamps=(val) : Void
      call("set", "file_timestamps", val)
    end

    # Property `check_interval` (Godot::Float64?)
    def check_interval : Float64
      call_f64("get", "check_interval")
    end

    def check_interval=(val) : Void
      call("set", "check_interval", val)
    end

    # Property `time_since_last_check` (Godot::Float64?)
    def time_since_last_check : Float64
      call_f64("get", "time_since_last_check")
    end

    def time_since_last_check=(val) : Void
      call("set", "time_since_last_check", val)
    end
  end
end

alias CrShaderPlugin = Godot::CrShaderPlugin
