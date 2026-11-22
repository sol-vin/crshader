require "lapis"

module CrShader
  include Godot

  # =============================================================================
  # ComputeHelper - High-Level Godot 4 RenderingDevice Compute Orchestration
  # =============================================================================
  # Eliminates low-level RenderingDevice boilerplate for compiling GLSL 450
  # compute kernels to SPIR-V, managing pipeline states, sampler states, multi-set
  # uniform descriptors, push constants, and workgroup dispatches.
  class ComputeHelper
    # Exact Godot 4.x RenderingDevice::UniformType values
    UNIFORM_TYPE_SAMPLER              = 0
    UNIFORM_TYPE_SAMPLER_WITH_TEXTURE = 1
    UNIFORM_TYPE_TEXTURE              = 2
    UNIFORM_TYPE_IMAGE                = 3
    UNIFORM_TYPE_UNIFORM_BUFFER       = 7
    UNIFORM_TYPE_STORAGE_BUFFER       = 8

    SHADER_STAGE_COMPUTE = 4_i64

    property rd : Godot::RenderingDevice? = nil
    property shader_rid : Int64 = 0_i64
    property pipeline_rid : Int64 = 0_i64
    property uniform_set_rid : Int64 = 0_i64
    property uniform_set_dirty : Bool = true
    getter last_compile_error : String = ""

    # Cached uniform bindings: binding_index => BoundUniform
    record BoundUniform, uniform_type : Int32, rid : Int64, sampler_rid : Int64 = 0_i64, linear : Bool = false

    property set_bindings : Hash(Int32, Hash(Int32, BoundUniform)) = {
      0 => {} of Int32 => BoundUniform,
    }
    property set_rids : Hash(Int32, Int64) = {} of Int32 => Int64
    property dirty_sets : Set(Int32) = Set{0}

    @owns_shader_rid : Bool = false
    @nearest_sampler_rid : Int64 = 0_i64
    @linear_sampler_rid : Int64 = 0_i64
    @owned_buffers : Set(Int64) = Set(Int64).new
    @rd_bridge : Godot::Object? = nil

    RD_BRIDGE_GDSCRIPT = <<-GDSCRIPT
extends RefCounted
var _uniforms: Array[RDUniform] = []

func clear_uniforms() -> void:
\t_uniforms.clear()

func push_uniform(u: RDUniform) -> void:
\t_uniforms.push_back(u)

func create_uniform_set(rd: RenderingDevice, shader_id: int, set_idx: int) -> int:
\tvar rid := rd.uniform_set_create(_uniforms, rid_from_int64(shader_id), set_idx)
\t_uniforms.clear()
\treturn rid.get_id()

func create_ubo(rd: RenderingDevice, size_bytes: int, data: PackedByteArray) -> int:
\treturn rd.uniform_buffer_create(size_bytes, data).get_id()

func update_buf(rd: RenderingDevice, buf_id: int, offset: int, size_bytes: int, data: PackedByteArray) -> int:
\treturn rd.buffer_update(rid_from_int64(buf_id), offset, size_bytes, data)

func create_ssbo_data(rd: RenderingDevice, size_bytes: int, data: PackedByteArray) -> int:
\treturn rd.storage_buffer_create(size_bytes, data).get_id()

func create_ssbo_empty(rd: RenderingDevice, size_bytes: int) -> int:
\treturn rd.storage_buffer_create(size_bytes).get_id()

func set_push_const(rd: RenderingDevice, compute_list: int, data: PackedByteArray, size_bytes: int) -> void:
\trd.compute_list_set_push_constant(compute_list, data, size_bytes)
GDSCRIPT

    private def ensure_rd_bridge : Godot::Object?
      if existing = @rd_bridge
        return existing unless existing.pointer.null?
      end
      script = Godot.create(Godot::GDScript)
      return nil if script.pointer.null?
      script.set_source_code(RD_BRIDGE_GDSCRIPT)
      return nil if script.reload(false).value != 0
      inst = script.call_obj_as(Godot::RefCounted, "new")
      @rd_bridge = inst
      inst
    rescue
      nil
    end

    def initialize(@rd : Godot::RenderingDevice? = nil)
      if @rd.nil? && !Godot::RenderingServer.singleton_ptr.null?
        rs = Godot::RenderingServer.new(Godot::RenderingServer.singleton_ptr)
        rd_ptr = rs.call_obj("get_rendering_device")
        @rd = Godot::RenderingDevice.new(rd_ptr.pointer) if rd_ptr && !rd_ptr.pointer.null?
      end
    end

    # Backwards-compatible accessor for set 0 bindings
    def bindings : Hash(Int32, BoundUniform)
      @set_bindings[0] ||= {} of Int32 => BoundUniform
    end

    # Factory method creating helper from a compiled shader RID
    def self.create(shader_rid : Int64, rd : Godot::RenderingDevice? = nil) : ComputeHelper
      helper = new(rd)
      helper.set_shader(shader_rid)
      helper
    end

    # Compiles GLSL 450 compute source directly to SPIR-V on RenderingDevice and creates pipeline
    def compile_glsl(glsl_source : String, name : String = "CrShaderCompute") : Int64
      @last_compile_error = ""
      dev = @rd
      return 0_i64 unless dev

      src = Godot.create(Godot::RDShaderSource)
      return 0_i64 unless src
      src.set_stage_source(SHADER_STAGE_COMPUTE, glsl_source)

      spirv = dev.shader_compile_spirv_from_source(src)
      if spirv.pointer.null?
        @last_compile_error = "Failed to invoke shader_compile_spirv_from_source"
        return 0_i64
      end

      err = spirv.get_stage_compile_error(SHADER_STAGE_COMPUTE)
      unless err.empty?
        @last_compile_error = err
        Godot.printerr("[ComputeHelper] GLSL SPIR-V compile error (#{name}):\n#{err}")
        return 0_i64
      end

      new_rid = dev.shader_create_from_spirv(spirv, name)
      if new_rid > 0
        set_shader(new_rid, owned: true)
      end
      new_rid
    rescue ex
      @last_compile_error = ex.message || "Unknown SPIR-V compile exception"
      Godot.printerr("[ComputeHelper] compile_glsl error: #{@last_compile_error}")
      0_i64
    end

    def set_shader(shader_rid : Int64, owned : Bool = false) : Void
      return if shader_rid <= 0
      cleanup_pipeline(free_shader: true)

      @shader_rid = shader_rid
      @owns_shader_rid = owned
      if dev = @rd
        @pipeline_rid = dev.compute_pipeline_create(shader_rid, Pointer(Void).null)
        mark_set_dirty(0)
        @set_bindings.each_key { |s| mark_set_dirty(s) }
      end
    end

    def ensure_nearest_sampler : Int64
      return @nearest_sampler_rid if @nearest_sampler_rid > 0
      dev = @rd
      return 0_i64 unless dev

      state = Godot.create(Godot::RDSamplerState)
      return 0_i64 unless state
      state.set_min_filter(Godot::RenderingDevice::SamplerFilter::SamplerFilterNearest)
      state.set_mag_filter(Godot::RenderingDevice::SamplerFilter::SamplerFilterNearest)
      state.set_repeat_u(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      state.set_repeat_v(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      state.set_repeat_w(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      @nearest_sampler_rid = dev.sampler_create(state)
      @nearest_sampler_rid
    rescue
      0_i64
    end

    def ensure_linear_sampler : Int64
      return @linear_sampler_rid if @linear_sampler_rid > 0
      dev = @rd
      return 0_i64 unless dev

      state = Godot.create(Godot::RDSamplerState)
      return 0_i64 unless state
      state.set_min_filter(Godot::RenderingDevice::SamplerFilter::SamplerFilterLinear)
      state.set_mag_filter(Godot::RenderingDevice::SamplerFilter::SamplerFilterLinear)
      state.set_repeat_u(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      state.set_repeat_v(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      state.set_repeat_w(Godot::RenderingDevice::SamplerRepeatMode::SamplerRepeatModeClampToEdge)
      @linear_sampler_rid = dev.sampler_create(state)
      @linear_sampler_rid
    rescue
      0_i64
    end

    private def set_map(set_index : Int32) : Hash(Int32, BoundUniform)
      @set_bindings[set_index] ||= {} of Int32 => BoundUniform
    end

    private def mark_set_dirty(set_index : Int32) : Void
      @dirty_sets.add(set_index)
      @uniform_set_dirty = true if set_index == 0
    end

    # Binds an image2D storage image (UniformTypeImage = 3)
    def bind_image(binding : Int32, texture_rid : Int64, set_index : Int32 = 0) : Void
      return if texture_rid <= 0
      map = set_map(set_index)
      if existing = map[binding]?
        return if existing.rid == texture_rid && existing.uniform_type == UNIFORM_TYPE_IMAGE
      end
      map[binding] = BoundUniform.new(UNIFORM_TYPE_IMAGE, texture_rid)
      mark_set_dirty(set_index)
    end

    # Binds a combined sampler2D (UniformTypeSamplerWithTexture = 1), required for depth & normal_roughness buffers
    def bind_sampler_with_texture(binding : Int32, texture_rid : Int64, linear : Bool = false, set_index : Int32 = 0) : Void
      return if texture_rid <= 0
      samp_rid = @rd ? (linear ? ensure_linear_sampler : ensure_nearest_sampler) : 0_i64
      return if @rd && samp_rid <= 0
      map = set_map(set_index)
      if existing = map[binding]?
        return if existing.rid == texture_rid && existing.sampler_rid == samp_rid && existing.linear == linear && existing.uniform_type == UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
      end
      map[binding] = BoundUniform.new(UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, texture_rid, samp_rid, linear)
      mark_set_dirty(set_index)
    end

    # Binds a raw texture without sampler (UniformTypeTexture = 2)
    def bind_texture(binding : Int32, texture_rid : Int64, set_index : Int32 = 0) : Void
      return if texture_rid <= 0
      map = set_map(set_index)
      if existing = map[binding]?
        return if existing.rid == texture_rid && existing.uniform_type == UNIFORM_TYPE_TEXTURE
      end
      map[binding] = BoundUniform.new(UNIFORM_TYPE_TEXTURE, texture_rid)
      mark_set_dirty(set_index)
    end

    # Binds a Uniform Buffer Object (UniformTypeUniformBuffer = 7)
    def bind_uniform_buffer(binding : Int32, ubo_rid : Int64, set_index : Int32 = 0) : Void
      return if ubo_rid <= 0
      map = set_map(set_index)
      if existing = map[binding]?
        return if existing.rid == ubo_rid && existing.uniform_type == UNIFORM_TYPE_UNIFORM_BUFFER
      end
      map[binding] = BoundUniform.new(UNIFORM_TYPE_UNIFORM_BUFFER, ubo_rid)
      mark_set_dirty(set_index)
    end

    # Binds a storage buffer (UniformTypeStorageBuffer = 8)
    def bind_storage_buffer(binding : Int32, buffer_rid : Int64, set_index : Int32 = 0) : Void
      return if buffer_rid <= 0
      map = set_map(set_index)
      if existing = map[binding]?
        return if existing.rid == buffer_rid && existing.uniform_type == UNIFORM_TYPE_STORAGE_BUFFER
      end
      map[binding] = BoundUniform.new(UNIFORM_TYPE_STORAGE_BUFFER, buffer_rid)
      mark_set_dirty(set_index)
    end

    # Cached push constant payload bytes for the next dispatch
    property push_constant_bytes : Bytes? = nil

    # Sets push constant bytes (aligned to 16 bytes as required by Vulkan / RenderingDevice)
    def set_push_constant(bytes : Bytes) : Void
      if bytes.empty?
        @push_constant_bytes = nil
      elsif bytes.size % 16 == 0
        @push_constant_bytes = bytes
      else
        aligned_size = ((bytes.size + 15) // 16) * 16
        padded = Bytes.new(aligned_size, 0_u8)
        padded.copy_from(bytes)
        @push_constant_bytes = padded
      end
    end

    private def bytes_to_pba(bytes : Bytes) : Godot::PackedByteArray
      pba = Godot::PackedByteArray.new(bytes.size)
      pba.to_unsafe.copy_from(bytes.to_unsafe, bytes.size) unless bytes.empty?
      pba
    end

    # Allocates or updates a GPU Uniform Buffer Object (UBO)
    def ensure_uniform_buffer(existing_rid : Int64, bytes : Bytes, binding : Int32, set_index : Int32 = 0) : Int64
      return 0_i64 if bytes.empty?
      dev = @rd
      return 0_i64 unless dev

      aligned_bytes = if bytes.size % 16 == 0
                        bytes
                      else
                        padded = Bytes.new(((bytes.size + 15) // 16) * 16, 0_u8)
                        padded.copy_from(bytes)
                        padded
                      end

      rid = existing_rid
      pba = bytes_to_pba(aligned_bytes)
      bridge = ensure_rd_bridge
      return 0_i64 unless bridge

      if rid <= 0
        rid = bridge.call_i64("create_ubo", dev, aligned_bytes.size, pba)
        @owned_buffers.add(rid) if rid > 0
      else
        bridge.call_i64("update_buf", dev, rid, 0, aligned_bytes.size, pba)
      end

      if rid > 0
        bind_uniform_buffer(binding, rid, set_index)
      end
      rid
    rescue ex
      Godot.printerr("[ComputeHelper] ensure_uniform_buffer error: #{ex.message}")
      0_i64
    end

    # Allocates a GPU storage buffer of `byte_size` bytes on the RenderingDevice
    def create_storage_buffer(byte_size : Int32, data : Bytes? = nil, binding : Int32? = nil, set_index : Int32 = 0) : Int64
      return 0_i64 if byte_size <= 0
      dev = @rd
      return 0_i64 unless dev
      bridge = ensure_rd_bridge
      return 0_i64 unless bridge

      rid = if bytes = data
              pba = bytes_to_pba(bytes)
              bridge.call_i64("create_ssbo_data", dev, byte_size, pba)
            else
              bridge.call_i64("create_ssbo_empty", dev, byte_size)
            end
      if rid > 0
        @owned_buffers.add(rid)
        if bind_idx = binding
          bind_storage_buffer(bind_idx, rid, set_index)
        end
      end
      rid
    rescue ex
      Godot.print("[ComputeHelper] create_storage_buffer error: #{ex.message}")
      0_i64
    end

    # Dispatches a 1D compute kernel over `element_count` items
    def dispatch_1d(element_count : Int32, local_x : Int32 = 64) : Bool
      dispatch(element_count, 1, 1, local_x, 1, 1)
    end

    # Rebuilds the RDUniform set for `set_index` if bindings changed
    def update_uniform_set(set_index : Int32 = 0) : Bool
      dev = @rd
      return false unless dev && @shader_rid > 0

      is_dirty = @dirty_sets.includes?(set_index) || (set_index == 0 && @uniform_set_dirty)
      existing_set_rid = set_index == 0 ? @uniform_set_rid : (@set_rids[set_index]? || 0_i64)
      return existing_set_rid > 0 unless is_dirty

      map = @set_bindings[set_index]?
      return false if map.nil? || map.empty?

      bridge = ensure_rd_bridge
      return false unless bridge

      if existing_set_rid > 0
        dev.free_rid(existing_set_rid) rescue nil
        @uniform_set_rid = 0_i64 if set_index == 0
        @set_rids.delete(set_index)
      end

      bridge.call("clear_uniforms")
      map.keys.sort!.each do |binding_idx|
        bound = map[binding_idx]
        rd_uniform = Godot.create(Godot::RDUniform)
        next if rd_uniform.pointer.null?
        rd_uniform.set_uniform_type(bound.uniform_type)
        rd_uniform.set_binding(binding_idx.to_i64)
        if bound.uniform_type == UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
          s_rid = bound.sampler_rid > 0 ? bound.sampler_rid : (bound.linear ? ensure_linear_sampler : ensure_nearest_sampler)
          next if s_rid <= 0
          rd_uniform.add_id(s_rid)
          rd_uniform.add_id(bound.rid)
        else
          rd_uniform.add_id(bound.rid)
        end
        bridge.call("push_uniform", rd_uniform)
      end

      new_set = bridge.call_i64("create_uniform_set", dev, @shader_rid, set_index)
      if new_set > 0
        @set_rids[set_index] = new_set
        @uniform_set_rid = new_set if set_index == 0
        @dirty_sets.delete(set_index)
        @uniform_set_dirty = false if set_index == 0
        true
      else
        false
      end
    rescue ex
      Godot.print("[ComputeHelper] update_uniform_set(#{set_index}) error: #{ex.message}")
      false
    end

    # Dispatches the compute shader over screen / volume dimensions
    def dispatch(
      width : Int32,
      height : Int32,
      depth : Int32 = 1,
      local_x : Int32 = 8,
      local_y : Int32 = 8,
      local_z : Int32 = 1,
    ) : Bool
      dev = @rd
      return false unless dev && @pipeline_rid > 0

      @set_bindings.keys.sort!.each do |s_idx|
        next if @set_bindings[s_idx].empty?
        return false unless update_uniform_set(s_idx)
      end

      groups_x = (width + local_x - 1) // local_x
      groups_y = (height + local_y - 1) // local_y
      groups_z = (depth + local_z - 1) // local_z
      return false if groups_x <= 0 || groups_y <= 0 || groups_z <= 0

      compute_list = dev.compute_list_begin
      dev.compute_list_bind_compute_pipeline(compute_list, @pipeline_rid)

      @set_rids.keys.sort!.each do |s_idx|
        s_rid = @set_rids[s_idx]
        if s_rid > 0
          dev.compute_list_bind_uniform_set(compute_list, s_rid, s_idx.to_i64)
        end
      end

      if pc = @push_constant_bytes
        if !pc.empty? && (bridge = ensure_rd_bridge)
          pba = bytes_to_pba(pc)
          bridge.call("set_push_const", dev, compute_list, pba, pc.size)
        end
      end

      dev.compute_list_dispatch(compute_list, groups_x.to_i64, groups_y.to_i64, groups_z.to_i64)
      dev.compute_list_end

      true
    rescue ex
      Godot.print("[ComputeHelper] dispatch error: #{ex.message}")
      false
    end

    # Syncs execution on local RenderingDevices
    def sync : Void
      if dev = @rd
        dev.submit
        dev.sync
      end
    rescue
    end

    # Cleans up GPU pipeline, uniform sets, samplers, and owned shader/buffer RIDs
    def cleanup_pipeline(free_shader : Bool = false) : Void
      if dev = @rd
        @set_rids.each_value do |s_rid|
          dev.free_rid(s_rid) rescue nil if s_rid > 0
        end
        @set_rids.clear
        @uniform_set_rid = 0_i64

        if @pipeline_rid > 0
          dev.free_rid(@pipeline_rid) rescue nil
          @pipeline_rid = 0_i64
        end

        if free_shader && @owns_shader_rid && @shader_rid > 0
          dev.free_rid(@shader_rid) rescue nil
          @shader_rid = 0_i64
          @owns_shader_rid = false
        end
      end
      @uniform_set_dirty = true
      @set_bindings.each_key { |k| @dirty_sets.add(k) }
    rescue
    end

    def cleanup_all : Void
      cleanup_pipeline(free_shader: true)
      if dev = @rd
        if @nearest_sampler_rid > 0
          dev.free_rid(@nearest_sampler_rid) rescue nil
          @nearest_sampler_rid = 0_i64
        end
        if @linear_sampler_rid > 0
          dev.free_rid(@linear_sampler_rid) rescue nil
          @linear_sampler_rid = 0_i64
        end
        @owned_buffers.each do |b_rid|
          dev.free_rid(b_rid) rescue nil if b_rid > 0
        end
        @owned_buffers.clear
      end
    rescue
    end

    def finalize
      cleanup_all
    end
  end
end
