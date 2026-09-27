require "lapis"

# =============================================================================
# CRShaderViewerApp - Interactive 2D/3D Shader Viewer Demo Controller
# =============================================================================
# Provides an interactive showcase for procedural shaders transpiled with CRShader.
# Supports live parameter tweaking, mesh rotation, shader switching, and FPS tracking.
node CrShaderViewerApp < Node3D do
  @pivot : Godot::Node3D? = nil
  @mesh_sphere : Godot::MeshInstance3D? = nil
  @mesh_torus : Godot::MeshInstance3D? = nil
  @sprite_2d : Godot::Sprite2D? = nil
  @fps_label : Godot::Label? = nil
  @shader_name_label : Godot::Label? = nil
  @desc_label : Godot::Label? = nil
  @speed_slider : Godot::HSlider? = nil
  @intensity_slider : Godot::HSlider? = nil
  @shader_option : Godot::OptionButton? = nil

  @rotation_speed : Float32 = 0.8_f32
  @intensity : Float32 = 1.0_f32
  @time_elapsed : Float64 = 0.0
  @current_shader_idx : Int32 = 0

  # Bundled shader presets
  struct ShaderPreset
    getter name : String
    getter path : String
    getter is_spatial : Bool
    getter description : String

    def initialize(@name, @path, @is_spatial, @description)
    end
  end

  @presets : Array(ShaderPreset) = [
    ShaderPreset.new(
      "Spatial Procedural Plasma",
      "res://shaders/basic_spatial.gdshader",
      true,
      "3D vertex displacement wave and dynamic spatial lighting."
    ),
    ShaderPreset.new(
      "Toon Animated Water",
      "res://shaders/toon_water.gdshader",
      false,
      "2D procedural water waves with crest foam and specular highlights."
    ),
    ShaderPreset.new(
      "Retro CRT Scanlines",
      "res://shaders/crt_scanlines.gdshader",
      false,
      "Simulated curved CRT monitor with phosphor grid and rolling scanlines."
    ),
    ShaderPreset.new(
      "Pixel Art Dither",
      "res://shaders/pixel_dither.gdshader",
      false,
      "Ordered 4x4 Bayer matrix luminance dithering filter."
    ),
    ShaderPreset.new(
      "Kuwahara Painterly Filter",
      "res://shaders/kuwahara.gdshader",
      false,
      "Multi-window variance filter producing an oil-painting artistic aesthetic."
    ),
    ShaderPreset.new(
      "PSX Retro Vertex Snap",
      "res://shaders/psx_retro.gdshader",
      true,
      "PlayStation 1 style fixed-point vertex coordinate truncation."
    ),
  ]

  def _ready : Void
    Godot.print("==================================================================")
    Godot.print("  [CRShaderViewer] Interactive Shader Viewer Scene Initialized!")
    Godot.print("  Loaded #{@presets.size} bundled CRShader showcase presets.")
    Godot.print("==================================================================")


    # Locate scene elements
    if node = get_node_or_null("Pivot3D")
      @pivot = node.as?(Godot::Node3D)
    end
    if node = get_node_or_null("Pivot3D/SphereMesh")
      @mesh_sphere = node.as?(Godot::MeshInstance3D)
    end
    if node = get_node_or_null("Pivot3D/TorusMesh")
      @mesh_torus = node.as?(Godot::MeshInstance3D)
    end
    if node = get_node_or_null("Preview2D/Sprite2D")
      @sprite_2d = node.as?(Godot::Sprite2D)
    end

    # Locate UI controls
    if node = get_node_or_null("UI/Margin/Panel/VBox/Header/FPSLabel")
      @fps_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Controls/ShaderOption")
      @shader_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Info/ShaderName")
      @shader_name_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Info/ShaderDesc")
      @desc_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Sliders/SpeedRow/SpeedSlider")
      @speed_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Sliders/IntensityRow/IntensitySlider")
      @intensity_slider = node.as?(Godot::HSlider)
    end

    setup_ui
    activate_shader(0)
  end

  def setup_ui : Void
    if opt = @shader_option
      opt.call("clear")
      @presets.each_with_index do |preset, idx|
        opt.call("add_item", "#{idx + 1}. #{preset.name}")
      end
      opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        activate_shader(idx)
      end
    end

    if btn = get_node_or_null("UI/Margin/Panel/VBox/Controls/PrevBtn")
      btn.connect("pressed") do |_args|
        prev_idx = (@current_shader_idx - 1 + @presets.size) % @presets.size
        activate_shader(prev_idx)
      end
    end

    if btn = get_node_or_null("UI/Margin/Panel/VBox/Controls/NextBtn")
      btn.connect("pressed") do |_args|
        next_idx = (@current_shader_idx + 1) % @presets.size
        activate_shader(next_idx)
      end
    end

    if slider = @speed_slider
      slider.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        @rotation_speed = val
        update_uniform("wave_speed", val.to_f64)
        update_uniform("scanline_speed", val.to_f64)
      end
    end

    if slider = @intensity_slider
      slider.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        @intensity = val
        update_uniform("scanline_intensity", val.to_f64)
        update_uniform("wave_height", (val * 0.15_f32).to_f64)
      end
    end

  end

  def activate_shader(index : Int32) : Void
    return if index < 0 || index >= @presets.size
    @current_shader_idx = index
    preset = @presets[index]

    if opt = @shader_option
      opt.call("select", index)
    end

    if lbl = @shader_name_label
      lbl.call("set_text", "Active: #{preset.name}")
    end

    if desc = @desc_label
      desc.call("set_text", preset.description)
    end

    # Toggle 3D mesh vs 2D sprite visibility based on shader target
    if pivot = @pivot
      pivot.call("set_visible", preset.is_spatial)
    end
    if sprite = @sprite_2d
      sprite.call("set_visible", !preset.is_spatial)
    end

    # Apply shader material if file exists
    apply_shader_file(preset.path, preset.is_spatial)
  end

  def apply_shader_file(path : String, is_spatial : Bool) : Void
    res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
    shader = res_loader.call_obj("load", path)
    return unless shader && !shader.pointer.null?

    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat
    mat.call("set_shader", shader)

    if is_spatial
      @mesh_sphere.try(&.call("set_surface_override_material", 0, mat))
      @mesh_torus.try(&.call("set_surface_override_material", 0, mat))
    else
      @sprite_2d.try(&.call("set_material", mat))
    end
    Godot.print("[CrShaderViewer] Applied shader: #{path}")
  rescue ex
    Godot.print("[CrShaderViewer] Note applying shader #{path}: #{ex.message}")
  end

  def update_uniform(name : String, value : Float64) : Void
    preset = @presets[@current_shader_idx]?
    return unless preset

    if preset.is_spatial
      if sphere = @mesh_sphere
        mat = sphere.call_obj("get_surface_override_material", 0)
        mat.try(&.call("set_shader_parameter", name, value))
      end
    else
      if sprite = @sprite_2d
        mat = sprite.call_obj("get_material")
        mat.try(&.call("set_shader_parameter", name, value))
      end
    end
  end

  def _process(delta : Float64) : Void
    @time_elapsed += delta

    # Rotate 3D preview meshes smoothly
    if pivot = @pivot
      pivot.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
      pivot.call("rotate_x", (@rotation_speed * 0.3_f32 * delta.to_f32).to_f64)
    end

    # Pulse 2D sprite gently for canvas shaders
    if sprite = @sprite_2d
      scale_base = 2.5_f32 + (Math.sin(@time_elapsed * 2.0).to_f32 * 0.05_f32)
      sprite.call("set_scale", Vector2.new(scale_base, scale_base))
    end

    # Real-time performance monitor
    if label = @fps_label
      fps = delta > 0.0 ? (1.0 / delta).round.to_i : 60
      ms = (delta * 1000.0).round(1)
      label.call("set_text", "Performance: #{fps} FPS (#{ms} ms)")
    end
  end
end

CRShaderViewerApp = CrShaderViewerApp

