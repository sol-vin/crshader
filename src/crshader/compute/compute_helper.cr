require "lapis"

module CrShader
  include Godot

  # =============================================================================
  # ComputeHelper - High-Level Godot 4 RenderingDevice Compute Orchestration
  # =============================================================================
  # Inspired by DevPoodle/compute-shader-plus. Eliminates 40+ lines of low-level
  # RenderingDevice boilerplate for managing compute shaders, pipeline states,
  # uniform sets, and dispatch workgroup sizing.
  class ComputeHelper
    property rd : Godot::RenderingDevice? = nil
    property shader_rid : Int64 = 0_i64
    property pipeline_rid : Int64 = 0_i64
    property uniform_set_rid : Int64 = 0_i64
    property uniform_set_dirty : Bool = true

    # Cached uniform bindings: binding_index => {uniform_type, rid}
    record BoundUniform, uniform_type : Int32, rid : Int64
    property bindings : Hash(Int32, BoundUniform) = {} of Int32 => BoundUniform

    def initialize(@rd : Godot::RenderingDevice? = nil)
      if @rd.nil? && !Godot::RenderingServer.singleton_ptr.null?
        rs = Godot::RenderingServer.new(Godot::RenderingServer.singleton_ptr)
        rd_ptr = rs.call_obj("get_rendering_device")
        @rd = Godot::RenderingDevice.new(rd_ptr.pointer) if rd_ptr && !rd_ptr.pointer.null?
      end
    end

    # Factory method creating helper from a compiled shader RID or SPIR-V
    def self.create(shader_rid : Int64, rd : Godot::RenderingDevice? = nil) : ComputeHelper
      helper = new(rd)
      helper.set_shader(shader_rid)
      helper
    end

    def set_shader(shader_rid : Int64) : Void
      return if shader_rid <= 0
      cleanup_pipeline

      @shader_rid = shader_rid
      if dev = @rd
        # Specialization constants pointer null
        @pipeline_rid = dev.compute_pipeline_create(shader_rid, Pointer(Void).null)
        @uniform_set_dirty = true
      end
    end

    # Binds an image2D texture (UniformType::Image = 8)
    def bind_image(binding : Int32, texture_rid : Int64) : Void
      return if texture_rid <= 0
      if existing = @bindings[binding]?
        return if existing.rid == texture_rid && existing.uniform_type == 8
      end
      @bindings[binding] = BoundUniform.new(8, texture_rid)
      @uniform_set_dirty = true
    end

    # Binds a sampler texture (UniformType::Texture = 7)
    def bind_texture(binding : Int32, texture_rid : Int64) : Void
      return if texture_rid <= 0
      if existing = @bindings[binding]?
        return if existing.rid == texture_rid && existing.uniform_type == 7
      end
      @bindings[binding] = BoundUniform.new(7, texture_rid)
      @uniform_set_dirty = true
    end

    # Binds a storage buffer (UniformType::StorageBuffer = 6)
    def bind_storage_buffer(binding : Int32, buffer_rid : Int64) : Void
      return if buffer_rid <= 0
      if existing = @bindings[binding]?
        return if existing.rid == buffer_rid && existing.uniform_type == 6
      end
      @bindings[binding] = BoundUniform.new(6, buffer_rid)
      @uniform_set_dirty = true
    end

    # Rebuilds the RDUniform set if bindings changed
    def update_uniform_set(set_index : Int32 = 0) : Bool
      dev = @rd
      return false unless dev && @shader_rid > 0
      return true unless @uniform_set_dirty

      # Destroy old uniform set
      if @uniform_set_rid > 0
        dev.call("free_rid", @uniform_set_rid)
        @uniform_set_rid = 0_i64
      end

      # Construct RDUniform array
      uniforms_array = Godot::Array.new
      @bindings.each do |binding_idx, bound|
        rd_uniform = Godot.create(Godot::RDUniform)
        next unless rd_uniform
        rd_uniform.call("set_uniform_type", bound.uniform_type)
        rd_uniform.call("set_binding", binding_idx)
        rd_uniform.call("add_id", bound.rid)
        uniforms_array.call("push_back", rd_uniform)
      end

      new_set = dev.call_int("uniform_set_create", uniforms_array, @shader_rid, set_index)
      if new_set > 0
        @uniform_set_rid = new_set
        @uniform_set_dirty = false
        true
      else
        false
      end
    rescue ex
      Godot.print("[ComputeHelper] update_uniform_set error: #{ex.message}")
      false
    end

    # Dispatches the compute shader over screen / volume dimensions
    def dispatch(
      width : Int32,
      height : Int32,
      depth : Int32 = 1,
      local_x : Int32 = 8,
      local_y : Int32 = 8,
      local_z : Int32 = 1
    ) : Bool
      dev = @rd
      return false unless dev && @pipeline_rid > 0

      update_uniform_set(0)
      return false if @uniform_set_rid <= 0

      groups_x = (width + local_x - 1) // local_x
      groups_y = (height + local_y - 1) // local_y
      groups_z = (depth + local_z - 1) // local_z
      return false if groups_x <= 0 || groups_y <= 0 || groups_z <= 0

      compute_list = dev.compute_list_begin
      dev.compute_list_bind_compute_pipeline(compute_list, @pipeline_rid)
      dev.compute_list_bind_uniform_set(compute_list, @uniform_set_rid, 0)
      dev.compute_list_dispatch(compute_list, groups_x, groups_y, groups_z)
      dev.compute_list_end

      true
    rescue ex
      Godot.print("[ComputeHelper] dispatch error: #{ex.message}")
      false
    end

    # Syncs execution to guarantee compute tasks complete
    def sync : Void
      if dev = @rd
        dev.call("submit")
        dev.call("sync")
      end
    rescue
    end

    # Cleans up GPU pipeline and uniform set resources
    def cleanup_pipeline : Void
      if dev = @rd
        if @uniform_set_rid > 0
          dev.call("free_rid", @uniform_set_rid)
          @uniform_set_rid = 0_i64
        end
        if @pipeline_rid > 0
          dev.call("free_rid", @pipeline_rid)
          @pipeline_rid = 0_i64
        end
      end
      @uniform_set_dirty = true
    rescue
    end

    def finalize
      cleanup_pipeline
    end
  end
end
