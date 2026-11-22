require "lapis"
require "../compiler"
require "../compute/compute_helper"
require "../transpiler/glsl/layout_packer"

module CrShader
  include Godot

  # =============================================================================
  # CRShaderCompositorEffect - Godot 4.8+ Render Pipeline Compositor Effect Base
  # =============================================================================
  # Plugs directly into Godot 4's WorldEnvironment / Camera3D Compositor stack.
  # Compiles `.crshader` or `.glsl` compute shaders to SPIR-V via RenderingDevice,
  # binds per-view color (rgba16f image2D), depth (sampler2D), Forward+
  # normal_roughness (sampler2D), and CrShaderSceneData matrices, and packs
  # uniform parameters automatically into std430 push constants or std140 UBOs.
  @[Tool]
  node CRShaderCompositorEffect < CompositorEffect do
    @[Export]
    property crshader_path : String = ""

    @[Export]
    property crshader_source : String = ""

    @[Export(range: 0.0_f32..2.0_f32, step: 0.01_f32)]
    property intensity : Float32 = 1.0_f32

    @[Export]
    property needs_depth_buffer : Bool = true

    @[Export]
    property needs_normal_roughness_buffer : Bool = false

    @[ExportEnum("PostTransparent:4", "PostOpaque:1", "PreOpaque:0", "PostSky:2", "PreTransparent:3")]
    property stage_callback : Int32 = 4

    alias ParamValue = Float32 | Int32 | UInt32 | Bool | Godot::Vector2 | Godot::Vector3 | Godot::Color | Array(Godot::Color)

    getter compiled_glsl : String = ""
    getter compiled_program : ShaderProgram? = nil
    getter packed_layout : GLSLLayoutPacker::PackedLayout? = nil
    property parameter_overrides : Hash(String, ParamValue) = {} of String => ParamValue
    property active_features : Hash(String, FeatureValue) = {} of String => FeatureValue
    property strip_debug_inspects : Bool = false

    @compute_helper : ComputeHelper? = nil
    @scene_ubo_rid : Int64 = 0_i64
    @params_ubo_rid : Int64 = 0_i64
    @shader_dirty : Bool = true
    @start_ticks_usec : Int64 = 0_i64

    def self.new(pointer : Void* = Pointer(Void).null) : self
      inst = allocate
      inst.initialize(pointer)
      inst
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      configure_compositor_flags unless @pointer.null?
    end

    def configure_compositor_flags : Void
      return if @pointer.null?
      set_access_resolved_color(true)
      set_access_resolved_depth(@needs_depth_buffer)
      set_needs_normal_roughness(@needs_normal_roughness_buffer)
      set_effect_callback_type(@stage_callback)
    rescue
    end

    # Sets `.crshader` source code at runtime and flags GPU pipeline for recompilation
    def set_shader_code(source : String, is_glsl : Bool = false) : Void
      if is_glsl
        @compiled_glsl = source
        @compiled_program = nil
        @packed_layout = nil
      else
        @crshader_source = source
        compile_dsl_to_glsl(source)
      end
      @shader_dirty = true
    end

    # Sets `.crshader` or `.glsl` file path at runtime and flags GPU pipeline for recompilation
    def load_shader_file(path : String) : Bool
      @crshader_path = path
      resolved = resolve_project_path(path)
      return false if resolved.empty? || !File.exists?(resolved)

      raw = File.read(resolved)
      if path.downcase.ends_with?(".glsl")
        set_shader_code(raw, is_glsl: true)
      else
        compile_dsl_to_glsl(raw, filename: resolved)
        @shader_dirty = true
      end
      true
    rescue ex
      Godot.printerr("[CRShaderCompositorEffect] Failed to load #{path}: #{ex.message}")
      false
    end

    # Updates a uniform parameter dynamically (mirrors ShaderMaterial#set_shader_parameter)
    def set_shader_parameter(name : String, value : ParamValue) : Void
      @parameter_overrides[name] = value
    end

    # Toggles or updates a compile-time specialization feature and schedules SPIR-V swap
    def set_feature(name : Symbol | String, value : FeatureValue) : Bool
      @active_features[name.to_s] = value
      if !@crshader_source.strip.empty?
        ok = compile_dsl_to_glsl(@crshader_source)
        @shader_dirty = true
        ok
      elsif !@crshader_path.strip.empty?
        load_shader_file(@crshader_path)
      else
        false
      end
    end

    # Compiles a specialized GLSL compute permutation using VariantCache
    def specialize(**features) : String
      map = @active_features.dup
      features.each do |k, v|
        map[k.to_s] = v.as(FeatureValue)
      end
      @active_features = map
      if !@crshader_source.strip.empty?
        compile_dsl_to_glsl(@crshader_source)
        @shader_dirty = true
      end
      @compiled_glsl
    end

    private def compile_dsl_to_glsl(source : String, filename : String? = nil) : Bool
      compiler = Compiler.new(
        target_override: ShaderTarget::GLSL,
        feature_overrides: @active_features,
        strip_debug_inspects: @strip_debug_inspects
      )
      @compiled_glsl = compiler.compile_source(source, filename: filename)
      if prog = compiler.last_program
        @compiled_program = prog
        @packed_layout = GLSLLayoutPacker.compute_layout(prog)
        if prog.is_compositor
          @needs_depth_buffer = prog.compositor_access_depth || @needs_depth_buffer
          @needs_normal_roughness_buffer = prog.compositor_access_normal_roughness || @needs_normal_roughness_buffer
          @stage_callback = case prog.compositor_stage
                            when "PreOpaque"      then 0
                            when "PostOpaque"     then 1
                            when "PostSky"        then 2
                            when "PreTransparent" then 3
                            else                       4
                            end
          configure_compositor_flags
        end
      end
      true
    rescue ex
      Godot.printerr("[CRShaderCompositorEffect] CRShader compile error: #{ex.message}")
      false
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      return true if norm == "_render_callback"
      super
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      if norm == "_render_callback"
        if !args.null? && !args[0].null? && !args[1].null?
          cb_type = args[0].as(Int64*).value
          rd_ptr = args[1].as(Void**).value
          if !rd_ptr.null?
            _render_callback(cb_type, Godot::RenderData.new(rd_ptr))
          end
        end
        return
      end
      super
    end

    # Executed on the Godot render thread for each frame
    def _render_callback(effect_callback_type : Int64, render_data : Godot::RenderData) : Void
      return if render_data.pointer.null?

      # 1. Acquire ComputeHelper & compile SPIR-V lazily if dirty
      helper = @compute_helper
      if helper.nil?
        helper = ComputeHelper.new
        @compute_helper = helper
      end

      if @shader_dirty
        ensure_compiled_on_render_thread(helper)
      end
      return if helper.pipeline_rid <= 0

      # 2. Extract RenderSceneBuffersRD
      buffers_base = render_data.get_render_scene_buffers
      return if buffers_base.pointer.null?
      buffers = Godot::RenderSceneBuffersRD.new(buffers_base.pointer)

      size = buffers.get_internal_size
      return if size.x <= 0 || size.y <= 0

      # 3. Upload uniform parameters (push constants or set = 1 UBO)
      upload_uniform_parameters(helper)

      # 4. Dispatch per stereo / camera view
      view_count = buffers.get_view_count
      view_count = 1_i64 if view_count <= 0

      prog = @compiled_program
      local_x = prog.try(&.compute_layout.x) || 8
      local_y = prog.try(&.compute_layout.y) || 8
      wants_scene_ubo = prog.try(&.compositor_access_scene_data) || false

      scene_data = wants_scene_ubo ? render_data.get_render_scene_data : nil

      view_count.times do |view|
        color_tex = buffers.get_color_layer(view)
        next if color_tex <= 0
        helper.bind_image(0, color_tex, set_index: 0)

        if @needs_depth_buffer
          depth_tex = buffers.get_depth_layer(view)
          if depth_tex > 0
            helper.bind_sampler_with_texture(1, depth_tex, linear: false, set_index: 0)
          end
        end

        if @needs_normal_roughness_buffer && buffers.has_texture("forward_clustered", "normal_roughness")
          nr_tex = buffers.get_texture_slice("forward_clustered", "normal_roughness", view, 0_i64, 1_i64, 1_i64)
          nr_tex = buffers.get_texture("forward_clustered", "normal_roughness") if nr_tex <= 0
          if nr_tex > 0
            helper.bind_sampler_with_texture(2, nr_tex, linear: false, set_index: 0)
          end
        end

        if wants_scene_ubo && scene_data && !scene_data.pointer.null?
          scene_bytes = pack_scene_data_bytes(scene_data, view, size)
          @scene_ubo_rid = helper.ensure_uniform_buffer(@scene_ubo_rid, scene_bytes, binding: 3, set_index: 0)
        end

        helper.dispatch(size.x.to_i32, size.y.to_i32, 1, local_x, local_y, 1)
      end
    rescue ex
      Godot.print("[CRShaderCompositorEffect] _render_callback exception: #{ex.message}")
    end

    private def ensure_compiled_on_render_thread(helper : ComputeHelper) : Void
      @shader_dirty = false
      if @compiled_glsl.empty?
        if !@crshader_source.strip.empty?
          compile_dsl_to_glsl(@crshader_source)
        elsif !@crshader_path.strip.empty?
          load_shader_file(@crshader_path)
          @shader_dirty = false
        end
      end
      return if @compiled_glsl.empty?
      helper.compile_glsl(@compiled_glsl, "CRShaderCompositorEffect")
    end

    private def upload_uniform_parameters(helper : ComputeHelper) : Void
      layout = @packed_layout
      prog = @compiled_program
      return unless layout && prog
      return if layout.kind == GLSLLayoutPacker::PackingKind::None || layout.total_bytes <= 0

      buf = Bytes.new(layout.total_bytes, 0_u8)
      layout.fields.each do |slot|
        u_decl = prog.uniforms.find { |u| u.name == slot.name }
        write_slot_value(buf, slot, u_decl)
      end

      case layout.kind
      when GLSLLayoutPacker::PackingKind::PushConstant
        helper.set_push_constant(buf)
      when GLSLLayoutPacker::PackingKind::UniformBuffer
        @params_ubo_rid = helper.ensure_uniform_buffer(@params_ubo_rid, buf, binding: 0, set_index: 1)
      end
    end

    private def write_slot_value(buf : Bytes, slot : GLSLLayoutPacker::FieldSlot, u_decl : UniformDecl?) : Void
      ptr = buf.to_unsafe + slot.byte_offset
      override = @parameter_overrides[slot.name]?
      if override.nil? && slot.name == "intensity"
        override = @intensity
      end

      case slot.glsl_type
      when "float"
        val = case override
              when Float32 then override
              when Int32   then override.to_f32
              else              extract_float_default(u_decl, 0.0_f32)
              end
        ptr.as(Float32*).value = val
      when "int"
        val = case override
              when Int32   then override
              when Float32 then override.to_i32
              else              extract_float_default(u_decl, 0.0_f32).to_i32
              end
        ptr.as(Int32*).value = val
      when "uint"
        val = case override
              when UInt32  then override
              when Int32   then override.to_u32
              when Float32 then override.to_u32
              else              extract_float_default(u_decl, 0.0_f32).to_u32
              end
        ptr.as(UInt32*).value = val
      when "bool"
        val = case override
              when Bool then override ? 1_u32 : 0_u32
              else           (u_decl.try(&.default_value.try(&.to_s)) == "true") ? 1_u32 : 0_u32
              end
        ptr.as(UInt32*).value = val
      when "vec2"
        v = override.is_a?(Godot::Vector2) ? override : extract_vec2_default(u_decl)
        fp = ptr.as(Float32*)
        fp[0] = v.x
        fp[1] = v.y
      when "vec3"
        v = override.is_a?(Godot::Vector3) ? override : extract_vec3_default(u_decl)
        fp = ptr.as(Float32*)
        fp[0] = v.x
        fp[1] = v.y
        fp[2] = v.z
      when "vec4"
        if slot.is_array && override.is_a?(Array(Godot::Color))
          colors = override.as(Array(Godot::Color))
          count = Math.min(colors.size, slot.array_len)
          count.times do |i|
            fp = (ptr + i * 16).as(Float32*)
            fp[0] = colors[i].r
            fp[1] = colors[i].g
            fp[2] = colors[i].b
            fp[3] = colors[i].a
          end
        else
          c = override.is_a?(Godot::Color) ? override : extract_color_default(u_decl)
          fp = ptr.as(Float32*)
          fp[0] = c.r
          fp[1] = c.g
          fp[2] = c.b
          fp[3] = c.a
        end
      end
    end

    private def extract_float_default(u : UniformDecl?, fallback : Float32) : Float32
      return fallback unless u && (dv = u.default_value)
      dv.to_s.gsub(/_f32|_f64|_i32|_u32/, "").to_f32? || fallback
    end

    private def extract_vec2_default(u : UniformDecl?) : Godot::Vector2
      return Godot::Vector2.new(0_f32, 0_f32) unless u && (dv = u.default_value)
      nums = dv.to_s.scan(/[-\d.]+/).map(&.[0].to_f32?)
      Godot::Vector2.new(nums[0]?.try(&.not_nil!) || 0_f32, nums[1]?.try(&.not_nil!) || 0_f32)
    end

    private def extract_vec3_default(u : UniformDecl?) : Godot::Vector3
      return Godot::Vector3.new(0_f32, 0_f32, 0_f32) unless u && (dv = u.default_value)
      nums = dv.to_s.scan(/[-\d.]+/).map(&.[0].to_f32?)
      Godot::Vector3.new(
        nums[0]?.try(&.not_nil!) || 0_f32,
        nums[1]?.try(&.not_nil!) || 0_f32,
        nums[2]?.try(&.not_nil!) || 0_f32
      )
    end

    private def extract_color_default(u : UniformDecl?) : Godot::Color
      return Godot::Color.new(1_f32, 1_f32, 1_f32, 1_f32) unless u && (dv = u.default_value)
      nums = dv.to_s.scan(/[-\d.]+/).map(&.[0].to_f32?)
      Godot::Color.new(
        nums[0]?.try(&.not_nil!) || 0_f32,
        nums[1]?.try(&.not_nil!) || 0_f32,
        nums[2]?.try(&.not_nil!) || 0_f32,
        nums[3]?.try(&.not_nil!) || 1_f32
      )
    end

    @@mb_view_proj : Void* = Pointer(Void).null

    # Packs 272-byte CrShaderSceneData std140 UBO:
    # mat4 INV_PROJECTION_MATRIX, mat4 PROJECTION_MATRIX, mat4 INV_VIEW_MATRIX, mat4 VIEW_MATRIX, vec2 VIEWPORT_SIZE, float TIME, float pad
    def self.build_scene_ubo_bytes(scene_data : Godot::RenderSceneData, view : Int64, size : Vector2i, elapsed_sec : Float32) : Bytes
      bytes = Bytes.new(272, 0_u8)
      fp = bytes.to_unsafe.as(Float32*)

      # Safely fetch 64-byte Godot Projection (4 x Vector4 = float[16]) via direct ptrcall
      proj_buf = StaticArray(Float32, 16).new(0.0_f32)
      proj_buf[0] = 1.0_f32; proj_buf[5] = 1.0_f32; proj_buf[10] = 1.0_f32; proj_buf[15] = 1.0_f32
      if !scene_data.pointer.null?
        @@mb_view_proj = Godot::Bridge.get_method_bind("RenderSceneData", "get_view_projection", 3179846605_i64) if @@mb_view_proj.null?
        if !@@mb_view_proj.null?
          v_idx = view.to_i64
          arg_0 = pointerof(v_idx).as(Void*)
          args = StaticArray[arg_0]
          Godot::Bridge.ptrcall(@@mb_view_proj, scene_data.pointer, args.to_unsafe.as(Void**), proj_buf.to_unsafe.as(Void*))
        end
      end

      # Copy PROJECTION_MATRIX (fp + 16) and compute exact 4x4 inverse INV_PROJECTION_MATRIX (fp + 0)
      (fp + 16).copy_from(proj_buf.to_unsafe, 16)
      invert_mat4(proj_buf.to_unsafe, fp + 0)

      cam_xform = scene_data.get_cam_transform # Camera->World (INV_VIEW_MATRIX)
      view_xform = cam_xform.affine_inverse    # World->Camera (VIEW_MATRIX)
      write_transform_mat4(fp + 32, cam_xform)
      write_transform_mat4(fp + 48, view_xform)

      fp[64] = size.x.to_f32
      fp[65] = size.y.to_f32
      fp[66] = elapsed_sec
      fp[67] = 0.0_f32

      bytes
    end

    private def pack_scene_data_bytes(scene_data : Godot::RenderSceneData, view : Int64, size : Vector2i) : Bytes
      now_usec = Time.monotonic.total_microseconds.to_i64
      @start_ticks_usec = now_usec if @start_ticks_usec == 0_i64
      elapsed = ((now_usec - @start_ticks_usec).to_f64 / 1_000_000.0).to_f32
      self.class.build_scene_ubo_bytes(scene_data, view, size, elapsed)
    end

    # Analytical 4x4 column-major matrix inversion (Cramer's rule / cofactors in Float64 precision)
    def self.invert_mat4(m : Float32*, out_inv : Float32*) : Void
      m0 = m[0].to_f64; m1 = m[1].to_f64; m2 = m[2].to_f64; m3 = m[3].to_f64
      m4 = m[4].to_f64; m5 = m[5].to_f64; m6 = m[6].to_f64; m7 = m[7].to_f64
      m8 = m[8].to_f64; m9 = m[9].to_f64; m10 = m[10].to_f64; m11 = m[11].to_f64
      m12 = m[12].to_f64; m13 = m[13].to_f64; m14 = m[14].to_f64; m15 = m[15].to_f64

      inv = StaticArray(Float64, 16).new(0.0)
      inv[0] = m5 * m10 * m15 - m5 * m11 * m14 - m9 * m6 * m15 + m9 * m7 * m14 + m13 * m6 * m11 - m13 * m7 * m10
      inv[4] = -m4 * m10 * m15 + m4 * m11 * m14 + m8 * m6 * m15 - m8 * m7 * m14 - m12 * m6 * m11 + m12 * m7 * m10
      inv[8] = m4 * m9 * m15 - m4 * m11 * m13 - m8 * m5 * m15 + m8 * m7 * m13 + m12 * m5 * m11 - m12 * m7 * m9
      inv[12] = -m4 * m9 * m14 + m4 * m10 * m13 + m8 * m5 * m14 - m8 * m6 * m13 - m12 * m5 * m10 + m12 * m6 * m9

      inv[1] = -m1 * m10 * m15 + m1 * m11 * m14 + m9 * m2 * m15 - m9 * m3 * m14 - m13 * m2 * m11 + m13 * m3 * m10
      inv[5] = m0 * m10 * m15 - m0 * m11 * m14 - m8 * m2 * m15 + m8 * m3 * m14 + m12 * m2 * m11 - m12 * m3 * m10
      inv[9] = -m0 * m9 * m15 + m0 * m11 * m13 + m8 * m1 * m15 - m8 * m3 * m13 - m12 * m1 * m11 + m12 * m3 * m9
      inv[13] = m0 * m9 * m14 - m0 * m10 * m13 - m8 * m1 * m14 + m8 * m2 * m13 + m12 * m1 * m10 - m12 * m2 * m9

      inv[2] = m1 * m6 * m15 - m1 * m7 * m14 - m5 * m2 * m15 + m5 * m3 * m14 + m13 * m2 * m7 - m13 * m3 * m6
      inv[6] = -m0 * m6 * m15 + m0 * m7 * m14 + m4 * m2 * m15 - m4 * m3 * m14 - m12 * m2 * m7 + m12 * m3 * m6
      inv[10] = m0 * m5 * m15 - m0 * m7 * m13 - m4 * m1 * m15 + m4 * m3 * m13 + m12 * m1 * m7 - m12 * m3 * m5
      inv[14] = -m0 * m5 * m14 + m0 * m6 * m13 + m4 * m1 * m14 - m4 * m2 * m13 - m12 * m1 * m6 + m12 * m2 * m5

      inv[3] = -m1 * m6 * m11 + m1 * m7 * m10 + m5 * m2 * m11 - m5 * m3 * m10 - m9 * m2 * m7 + m9 * m3 * m6
      inv[7] = m0 * m6 * m11 - m0 * m7 * m10 - m4 * m2 * m11 + m4 * m3 * m10 + m8 * m2 * m7 - m8 * m3 * m6
      inv[11] = -m0 * m5 * m11 + m0 * m7 * m9 + m4 * m1 * m11 - m4 * m3 * m9 - m8 * m1 * m7 + m8 * m3 * m5
      inv[15] = m0 * m5 * m10 - m0 * m6 * m9 - m4 * m1 * m10 + m4 * m2 * m9 + m8 * m1 * m6 - m8 * m2 * m5

      det = m0 * inv[0] + m1 * inv[4] + m2 * inv[8] + m3 * inv[12]
      if det.abs < 1e-12
        16.times { |i| out_inv[i] = (i % 5 == 0) ? 1.0_f32 : 0.0_f32 }
        return
      end

      inv_det = 1.0 / det
      16.times { |i| out_inv[i] = (inv[i] * inv_det).to_f32 }
    end

    def self.write_transform_mat4(dst : Float32*, t : Transform3D) : Void
      # Column-major GLSL mat4 from Godot Basis (rows x, y, z) + origin
      b = t.basis
      o = t.origin
      # Column 0 (X axis)
      dst[0] = b.x.x; dst[1] = b.y.x; dst[2] = b.z.x; dst[3] = 0.0_f32
      # Column 1 (Y axis)
      dst[4] = b.x.y; dst[5] = b.y.y; dst[6] = b.z.y; dst[7] = 0.0_f32
      # Column 2 (Z axis)
      dst[8] = b.x.z; dst[9] = b.y.z; dst[10] = b.z.z; dst[11] = 0.0_f32
      # Column 3 (Translation)
      dst[12] = o.x; dst[13] = o.y; dst[14] = o.z; dst[15] = 1.0_f32
    end

    @@compositor_mount_bridge : Godot::Object? = nil

    COMPOSITOR_MOUNT_GDSCRIPT = <<-GDSCRIPT
extends RefCounted

func mount_effect(world_env: WorldEnvironment, effect: CompositorEffect) -> void:
\tif world_env == null or effect == null:
\t\treturn
\tif world_env.compositor == null:
\t\tworld_env.compositor = Compositor.new()
\tvar list: Array[CompositorEffect] = [effect]
\tworld_env.compositor.compositor_effects = list

func clear_effects(world_env: WorldEnvironment) -> void:
\tif world_env == null or world_env.compositor == null:
\t\treturn
\tvar empty: Array[CompositorEffect] = []
\tworld_env.compositor.compositor_effects = empty
GDSCRIPT

    private def self.ensure_mount_bridge : Godot::Object?
      if b = @@compositor_mount_bridge
        return b unless b.pointer.null?
      end
      script = Godot.create(Godot::GDScript)
      return nil if script.pointer.null?
      script.set_source_code(COMPOSITOR_MOUNT_GDSCRIPT)
      return nil if script.reload(false).value != 0
      inst = script.call_obj_as(Godot::RefCounted, "new")
      @@compositor_mount_bridge = inst
      inst
    rescue
      nil
    end

    # Mounts a `CompositorEffect` onto a `WorldEnvironment` (auto-creating `Compositor` if needed)
    def self.mount_to_world_environment(world_env : Godot::Object, effect : Godot::CompositorEffect) : Void
      return if world_env.pointer.null? || effect.pointer.null?
      if bridge = ensure_mount_bridge
        bridge.call("mount_effect", world_env, effect)
      end
    rescue
    end

    # Clears active `CompositorEffect` entries on a `WorldEnvironment`
    def self.clear_world_environment(world_env : Godot::Object) : Void
      return if world_env.pointer.null?
      if bridge = ensure_mount_bridge
        bridge.call("clear_effects", world_env)
      end
    rescue
    end

    private def resolve_project_path(target_path : String) : String
      return "" if target_path.empty?
      if target_path.starts_with?("res://") || target_path.starts_with?("user://")
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          gp = ps.call_str("globalize_path", target_path).gsub('\\', '/')
          return gp if !gp.empty? && File.exists?(gp)
        end
        stripped = target_path.sub(/^(res|user):\/\//, "")
        return stripped if File.exists?(stripped)
      end
      File.exists?(target_path) ? target_path : ""
    end
  end
end
