require "lapis"
require "../compute/compute_helper"

module CrShader
  include Godot

  # =============================================================================
  # CRShaderCompositorEffect - Godot 4 Render Pipeline Compositor Effect Base
  # =============================================================================
  # Inspired by DevPoodle/compositor-effect-library. Plugs directly into Godot 4's
  # WorldEnvironment / Camera3D Compositor stack.
  # Executes compute-based image processing passes on the render thread via
  # _render_callback, accessing internal RenderSceneBuffersRD (color and depth).
  @[Tool]
  node CRShaderCompositorEffect < CompositorEffect do
    @[Export]
    property shader_resource : Godot::Shader? = nil

    @[Export(range: 0.0_f32..2.0_f32, step: 0.01_f32)]
    property intensity : Float32 = 1.0_f32

    @[Export]
    property needs_depth_buffer : Bool = true

    @[ExportEnum("PostTransparent:4", "PostOpaque:1", "PreOpaque:0", "PostSky:2")]
    property stage_callback : Int32 = 4

    @compute_helper : ComputeHelper? = nil

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def _ready : Void
      call("set_access_resolved_color", true)
      call("set_access_resolved_depth", @needs_depth_buffer)
      call("set_effect_callback_type", @stage_callback)
    end

    # Executed on the Godot render thread for each frame
    def _render_callback(effect_callback_type : Int64, render_data : Godot::RenderData) : Void
      return unless render_data && !render_data.pointer.null?

      # 1. Extract RenderSceneBuffersRD
      buffers_obj = render_data.call_obj("get_render_scene_buffers")
      return unless buffers_obj && !buffers_obj.pointer.null?
      buffers = Godot::RenderSceneBuffersRD.new(buffers_obj.pointer)

      # 2. Retrieve internal scene color texture and depth texture
      color_texture = buffers.get_color_layer(0)
      return if color_texture <= 0

      # 3. Retrieve render buffer dimensions
      size = buffers.get_texture_slice_size("render_buffers", "color", 0)
      return if size.x <= 0 || size.y <= 0

      # 4. Acquire ComputeHelper
      helper = @compute_helper
      if helper.nil?
        helper = ComputeHelper.new
        @compute_helper = helper
      end

      # 5. Bind buffers
      helper.bind_image(0, color_texture)
      if @needs_depth_buffer
        depth_texture = buffers.get_depth_layer(0)
        helper.bind_image(1, depth_texture) if depth_texture > 0
      end

      # 6. Dispatch compute workgroups (8x8 local layout)
      helper.dispatch(size.x, size.y)
    rescue ex
      Godot.print("[CRShaderCompositorEffect] _render_callback exception: #{ex.message}")
    end
  end
end
