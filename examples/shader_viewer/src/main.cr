require "lapis"
require "../../../src/crshader/editor/variable_array_control"

# =============================================================================
# CRShaderViewerApp - Interactive Shader Viewer Demo Controller
# =============================================================================
# Showcases 20+ procedural shaders authored with CRShader.
# Supports 3D polygon meshes (Sphere, Cube, Cylinder, Torus, Prism, Capsule, Plane),
# full-screen post-processing quads, camera compositor passes, compute shader previews,
# and real-time uniform parameter tweaking.
node CrShaderViewerApp < Node3D do
  enum PipelineMode
    Material
    ScreenSpace
    Compositor
    Compute
  end

  struct ShaderPreset
    getter name : String
    getter path : String
    getter mode : PipelineMode
    getter category : String
    getter description : String
    getter param1_name : String
    getter param2_name : String
    getter param3_name : String
    getter param4_name : String

    def initialize(
      @name : String,
      @path : String,
      @mode : PipelineMode,
      @category : String,
      @description : String,
      @param1_name : String = "speed",
      @param2_name : String = "intensity",
      @param3_name : String = "radius",
      @param4_name : String = "sharpness"
    )
    end
  end

  @pivot : Godot::Node3D? = nil
  @mesh_instances = Hash(String, Godot::MeshInstance3D).new
  @current_shape : String = "Sphere"

  @post_process_rect : Godot::ColorRect? = nil
  @sprite_2d : Godot::Sprite2D? = nil

  @fps_label : Godot::Label? = nil
  @shader_name_label : Godot::Label? = nil
  @desc_label : Godot::Label? = nil
  @mode_label : Godot::Label? = nil

  @category_option : Godot::OptionButton? = nil
  @shader_option : Godot::OptionButton? = nil
  @shape_option : Godot::OptionButton? = nil
  @auto_rotate_check : Godot::CheckBox? = nil

  @param1_slider : Godot::HSlider? = nil
  @param2_slider : Godot::HSlider? = nil
  @param3_slider : Godot::HSlider? = nil
  @param4_slider : Godot::HSlider? = nil

  @param1_label : Godot::Label? = nil
  @param2_label : Godot::Label? = nil
  @param3_label : Godot::Label? = nil
  @param4_label : Godot::Label? = nil

  @active_material : Godot::ShaderMaterial? = nil
  @array_controls_container : Godot::VBoxContainer? = nil
  @var_array_control : CrShader::VariableArrayControl? = nil
  @auto_rotate : Bool = true
  @rotation_speed : Float32 = 0.8_f32
  @time_elapsed : Float64 = 0.0

  @current_shader_idx : Int32 = 0
  @current_category : String = "All"
  @filtered_indices : Array(Int32) = [] of Int32

  # Comprehensive catalog of 23 shaders
  @presets : Array(ShaderPreset) = [
    # 1. 3D Spatial Materials
    ShaderPreset.new(
      "Spatial Procedural Plasma",
      "res://shaders/basic_spatial.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "3D vertex displacement wave with dynamic spatial lighting and roughness.",
      "wave_speed", "wave_height", "metallic", "roughness"
    ),
    ShaderPreset.new(
      "PSX Retro Vertex Snap",
      "res://shaders/psx_retro.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "PlayStation 1 style fixed-point vertex snapping with affine texture warping.",
      "snap_resolution", "jitter_intensity", "color_precision", "roughness"
    ),
    ShaderPreset.new(
      "Forcefield Energy Shield",
      "res://shaders/gdquest_forcefield_shield.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Hexagonal Fresnel energy barrier with rim glow and depth edge intersections.",
      "shield_speed", "fresnel_power", "rim_glow", "hex_scale"
    ),
    ShaderPreset.new(
      "Toon Animated Water",
      "res://shaders/toon_water.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Stylized animated water surface with wave crest foam and specular highlights.",
      "speed", "wave_intensity", "foam_threshold", "refraction"
    ),
    ShaderPreset.new(
      "Stylized Fire Particles",
      "res://shaders/vfez_fire_particles.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Volumetric flame noise simulation with thermal color gradient ramp.",
      "flame_speed", "flame_intensity", "noise_scale", "dissolve_amount"
    ),

    # 2. Screen Space Post-Processing
    ShaderPreset.new(
      "Retro CRT Scanlines",
      "res://shaders/crt_scanlines.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Curved vintage CRT phosphor monitor with rolling scanlines and RGB shadow mask.",
      "scanline_speed", "scanline_intensity", "barrel_distortion", "vignette_amount"
    ),
    ShaderPreset.new(
      "Kuwahara Painterly Filter",
      "res://shaders/kuwahara.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Multi-window variance filter producing rich oil-painting artistic brush aesthetics.",
      "radius", "sharpness", "window_size", "blend_factor"
    ),
    ShaderPreset.new(
      "Image Effects Kuwahara",
      "res://shaders/image_effects_kuwahara.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "High-precision Acerola anisotropic Kuwahara edge-preserving filter.",
      "radius", "sharpness", "eccentricity", "edge_threshold"
    ),
    ShaderPreset.new(
      "Bayer Matrix Pixel Dither",
      "res://shaders/pixel_dither.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Ordered 4x4 and 8x8 Bayer matrix luminance quantization and dithering filter.",
      "dither_size", "color_depth", "contrast", "luminance_bias"
    ),
    ShaderPreset.new(
      "Film Grain & Chromatic Noise",
      "res://shaders/film_grain.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Analog celluloid film grain simulation with high-frequency temporal noise.",
      "grain_speed", "grain_amount", "grain_size", "chromatic_spread"
    ),
    ShaderPreset.new(
      "Monochrome ASCII Art Matrix",
      "res://shaders/ascii_art.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Real-time terminal ASCII character glyph luminance quantizer.",
      "font_size", "character_count", "edge_threshold", "monochrome_tint"
    ),
    ShaderPreset.new(
      "Chromatic Aberration & Vignette",
      "res://shaders/chromatic_vignette.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Lens optical chromatic dispersion with radial optical falloff vignette.",
      "dispersion_amount", "vignette_radius", "falloff_smoothness", "blur_amount"
    ),
    ShaderPreset.new(
      "Kawase Multi-Pass Bloom",
      "res://shaders/bloom_kawase.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "High-performance dual Kawase bloom filter for radiant glowing light sources.",
      "bloom_intensity", "bloom_threshold", "bloom_radius", "blend_mode"
    ),
    ShaderPreset.new(
      "Sobel Edge Detection Outline",
      "res://shaders/edge_detection_sobel.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Convolution kernel edge extraction for stylized cel-shading and outlines.",
      "edge_thickness", "edge_threshold", "outline_intensity", "background_fade"
    ),
    ShaderPreset.new(
      "Color Grading & Tonemapping",
      "res://shaders/color_grading_tonemap.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Filmic ACES tonemapping with customizable contrast, saturation, and gamma curves.",
      "exposure", "contrast", "saturation", "gamma"
    ),
    ShaderPreset.new(
      "Color Blindness Accessibility",
      "res://shaders/color_blindness.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Simulation filter for Protanopia, Deuteranopia, and Tritanopia deficiency palettes.",
      "simulation_mode", "severity", "brightness_comp", "contrast_boost"
    ),
    ShaderPreset.new(
      "Advanced Palette Swap",
      "res://shaders/advanced_palette_swap.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Palette indexing swap with color distance metrics, lightness, and Bayer dithering.",
      "dither_strength", "input_lightness", "input_contrast", "input_saturation"
    ),
    ShaderPreset.new(
      "Universal Dissolve Transition",
      "res://shaders/universal_transition.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Perlin noise dissolve burn transition with glowing ember border edges.",
      "progress", "edge_width", "feathering", "noise_scale"
    ),
    ShaderPreset.new(
      "Vespera Atmospheric Post-Process",
      "res://shaders/vespera_post_process.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Cinematic volumetric atmosphere simulation with depth haze and god-rays.",
      "haze_density", "depth_falloff", "sun_intensity", "tint_blend"
    ),
    ShaderPreset.new(
      "Dither CRT Hybrid",
      "res://shaders/mreliptik_dither_crt.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Composite retro filter blending phosphor glow with matrix dithering.",
      "scanline_speed", "dither_strength", "phosphor_bloom", "curvature"
    ),

    # 3. Compositor Passes
    ShaderPreset.new(
      "Depth Silhouette Outline",
      "res://shaders/compositor_depth_outline.glsl",
      PipelineMode::Compositor,
      "Compositor Passes",
      "Direct render pipeline compute pass drawing depth-buffer geometric edge silhouettes.",
      "outline_thickness", "depth_threshold", "edge_threshold", "depth_scale"
    ),
    ShaderPreset.new(
      "Pixel Grid & Mosaic",
      "res://shaders/compositor_pixelate.glsl",
      PipelineMode::Compositor,
      "Compositor Passes",
      "Framebuffer compute pass quantizing render targets into pixel cells with grid borders.",
      "pixel_size", "grid_strength", "block_width", "contrast"
    ),
    ShaderPreset.new(
      "GPU Compute Palette Swap",
      "res://shaders/compositor_palette_swap.glsl",
      PipelineMode::Compositor,
      "Compositor Passes",
      "High-speed compute pass mapping framebuffer pixels to target color palette.",
      "dither_strength", "min_dist", "palette_index", "saturation"
    ),
    ShaderPreset.new(
      "Render Buffer Preview",
      "res://shaders/compositor_buffer_preview.glsl",
      PipelineMode::Compositor,
      "Compositor Passes",
      "Diagnostic pipeline pass inspecting raw depth, linearized depth, or luminance channels.",
      "preview_mode", "z_near", "z_far", "lum_bias"
    ),

    # 4. Compute Shaders
    ShaderPreset.new(
      "Acerola Compute Blur",
      "res://shaders/acerola_compute_blur.glsl",
      PipelineMode::Compute,
      "Compute Simulation",
      "GLSL compute kernel computing 2D image convolution blur across compute workgroups.",
      "blur_radius", "blur_strength", "kernel_size", "aspect_ratio"
    ),
    ShaderPreset.new(
      "Conway Game of Life Compute",
      "res://shaders/compute_game_of_life.glsl",
      PipelineMode::Compute,
      "Compute Simulation",
      "GPU-accelerated cellular automata simulation executing on RenderingDevice buffers.",
      "simulation_speed", "cell_size", "alive_threshold", "wrap_edges"
    ),
    ShaderPreset.new(
      "Compute Particle Simulation",
      "res://shaders/compute_particles.glsl",
      PipelineMode::Compute,
      "Compute Simulation",
      "Massively parallel 100,000 particle N-body attractor simulation in GLSL.",
      "gravity_strength", "damping", "particle_speed", "vortex_twist"
    ),
  ]

  def _ready : Void
    Godot.print("==================================================================")
    Godot.print("  [CRShaderViewer] Interactive Showcase Viewer Initialized!")
    Godot.print("  Loaded #{@presets.size} bundled CRShader showcase presets.")
    Godot.print("==================================================================")

    # Locate 3D elements
    if node = get_node_or_null("Pivot3D")
      @pivot = node.as?(Godot::Node3D)
    end

    # Cache all mesh instances
    shape_names = ["Sphere", "Cube", "Cylinder", "Torus", "Prism", "Capsule", "Plane"]
    shape_names.each do |s|
      if node = get_node_or_null("Pivot3D/#{s}Mesh")
        if mesh_inst = node.as?(Godot::MeshInstance3D)
          @mesh_instances[s] = mesh_inst
        end
      end
    end

    # Locate 2D and Post-Process elements
    if node = get_node_or_null("ScreenSpaceLayer/PostProcessRect")
      @post_process_rect = node.as?(Godot::ColorRect)
    end
    if node = get_node_or_null("Preview2D/Sprite2D")
      @sprite_2d = node.as?(Godot::Sprite2D)
    end

    # Locate UI controls
    if node = get_node_or_null("UI/Margin/Panel/VBox/Header/FPSLabel")
      @fps_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow1/CategoryOption")
      @category_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow1/ShaderOption")
      @shader_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow2/ShapeOption")
      @shape_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow2/ModeLabel")
      @mode_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow2/AutoRotateCheck")
      @auto_rotate_check = node.as?(Godot::CheckBox)
    end

    if node = get_node_or_null("UI/Margin/Panel/VBox/Info/ShaderName")
      @shader_name_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/Info/ShaderDesc")
      @desc_label = node.as?(Godot::Label)
    end

    # Locate sliders
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow1/Param1Row/Param1Slider")
      @param1_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow1/Param1Row/Param1Label")
      @param1_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow1/Param2Row/Param2Slider")
      @param2_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow1/Param2Row/Param2Label")
      @param2_label = node.as?(Godot::Label)
    end

    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow2/Param3Row/Param3Slider")
      @param3_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow2/Param3Row/Param3Label")
      @param3_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow2/Param4Row/Param4Slider")
      @param4_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("UI/Margin/Panel/VBox/SlidersRow2/Param4Row/Param4Label")
      @param4_label = node.as?(Godot::Label)
    end

    if node = get_node_or_null("UI/Margin/Panel/VBox")
      @array_controls_container = node.as?(Godot::VBoxContainer)
    end

    setup_ui
    select_shape("Sphere")
    filter_category("All")
    activate_shader(0)
  end

  def setup_ui : Void
    # Setup Category Option
    if cat_opt = @category_option
      cat_opt.call("clear")
      categories = ["All", "Spatial Materials", "Screen Space", "Compositor Passes", "Compute Simulation"]
      categories.each_with_index do |cat, idx|
        cat_opt.call("add_item", cat, idx)
      end
      cat_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        cat_name = categories[idx]? || "All"
        filter_category(cat_name)
      end
    end

    # Setup Mesh Shape Option
    if shape_opt = @shape_option
      shape_opt.call("clear")
      shapes = ["Sphere", "Cube", "Cylinder", "Torus", "Prism", "Capsule", "Plane"]
      shapes.each_with_index do |shape, idx|
        shape_opt.call("add_item", shape, idx)
      end
      shape_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        shape_name = shapes[idx]? || "Sphere"
        select_shape(shape_name)
      end
    end

    # Auto Rotate Toggle
    if check = @auto_rotate_check
      check.connect("toggled") do |args|
        @auto_rotate = args.first?.try(&.as_bool) || false
      end
    end

    # Prev / Next Navigation Buttons
    if btn = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow1/PrevBtn")
      btn.connect("pressed") do |_args|
        navigate_preset(-1)
      end
    end
    if btn = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow1/NextBtn")
      btn.connect("pressed") do |_args|
        navigate_preset(1)
      end
    end

    # Connect parameter sliders
    if s = @param1_slider
      s.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        update_param(1, val.to_f64)
      end
    end
    if s = @param2_slider
      s.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        update_param(2, val.to_f64)
      end
    end
    if s = @param3_slider
      s.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        update_param(3, val.to_f64)
      end
    end
    if s = @param4_slider
      s.connect("value_changed") do |args|
        val = args.first?.try(&.as_f) || 1.0_f32
        update_param(4, val.to_f64)
      end
    end
  end

  def filter_category(cat_name : String) : Void
    @current_category = cat_name
    @filtered_indices.clear

    @presets.each_with_index do |p, idx|
      if cat_name == "All" || p.category == cat_name
        @filtered_indices << idx
      end
    end

    if opt = @shader_option
      opt.call("clear")
      @filtered_indices.each_with_index do |preset_idx, item_idx|
        preset = @presets[preset_idx]
        opt.call("add_item", "#{item_idx + 1}. #{preset.name}", item_idx)
      end
      opt.connect("item_selected") do |args|
        filtered_idx = args.first?.try(&.as_i) || 0
        actual_idx = @filtered_indices[filtered_idx]? || 0
        activate_shader(actual_idx)
      end
    end

    if !@filtered_indices.empty?
      activate_shader(@filtered_indices.first)
    end
  end

  def navigate_preset(offset : Int32) : Void
    return if @filtered_indices.empty?
    curr_sub_idx = @filtered_indices.index(@current_shader_idx) || 0
    new_sub_idx = (curr_sub_idx + offset + @filtered_indices.size) % @filtered_indices.size
    actual_idx = @filtered_indices[new_sub_idx]
    activate_shader(actual_idx)
  end

  def select_shape(shape_name : String) : Void
    @current_shape = shape_name
    @mesh_instances.each do |name, mesh_inst|
      is_active = (name == shape_name)
      mesh_inst.call("set_visible", is_active)
      if is_active && @active_material
        mesh_inst.call("set_surface_override_material", 0, @active_material)
      end
    end
  end

  def activate_shader(index : Int32) : Void
    return if index < 0 || index >= @presets.size
    @current_shader_idx = index
    preset = @presets[index]

    # Update OptionButton selection
    if opt = @shader_option
      if sub_idx = @filtered_indices.index(index)
        opt.call("select", sub_idx)
      end
    end

    # Update Labels
    if lbl = @shader_name_label
      lbl.call("set_text", "Active: #{preset.name} [#{preset.category}]")
    end
    if desc = @desc_label
      desc.call("set_text", preset.description)
    end
    if mode_lbl = @mode_label
      mode_name = case preset.mode
                  when PipelineMode::Material    then "Mode: Material (3D Surface)"
                  when PipelineMode::ScreenSpace then "Mode: Screen Space (Quad Post-Process)"
                  when PipelineMode::Compositor  then "Mode: Compositor Pass"
                  when PipelineMode::Compute     then "Mode: Compute Kernel Simulation"
                  end
      mode_lbl.call("set_text", mode_name)
    end

    # Update slider labels to match preset uniform names
    @param1_label.try &.call("set_text", "#{preset.param1_name.capitalize}:")
    @param2_label.try &.call("set_text", "#{preset.param2_name.capitalize}:")
    @param3_label.try &.call("set_text", "#{preset.param3_name.capitalize}:")
    @param4_label.try &.call("set_text", "#{preset.param4_name.capitalize}:")

    # Pipeline Mode Visibility Dispatch
    case preset.mode
    when PipelineMode::Material
      @pivot.try &.call("set_visible", true)
      @post_process_rect.try &.call("set_visible", false)
      @sprite_2d.try &.call("set_visible", false)
      apply_material_shader(preset.path)

    when PipelineMode::ScreenSpace, PipelineMode::Compositor
      @pivot.try &.call("set_visible", true) # Keep 3D meshes rotating as background scene!
      @post_process_rect.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)
      apply_post_process_shader(preset.path)

    when PipelineMode::Compute
      @pivot.try &.call("set_visible", false)
      @post_process_rect.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)
      apply_compute_shader_preview(preset.path)
    end

    # Dynamic inspector control for variable-size arrays / palettes
    if preset.name.includes?("Palette Swap")
      if container = @array_controls_container
        ctrl = @var_array_control
        if ctrl.nil?
          ctrl = CrShader::VariableArrayControl.new
          ctrl.configure("target_palette", @active_material)
          container.call("add_child", ctrl)
          @var_array_control = ctrl
        else
          ctrl.configure("target_palette", @active_material)
        end
      end
    else
      if ctrl = @var_array_control
        ctrl.get_parent.try(&.call("remove_child", ctrl))
        ctrl.call("queue_free")
        @var_array_control = nil
      end
    end
  end

  def apply_material_shader(path : String) : Void
    res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
    shader = res_loader.call_obj("load", path)
    return unless shader && !shader.pointer.null?

    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat
    mat.call("set_shader", shader)
    @active_material = mat

    # Apply to current active 3D mesh
    if active_mesh = @mesh_instances[@current_shape]?
      active_mesh.call("set_surface_override_material", 0, mat)
    end
    Godot.print("[CRShaderViewer] Applied 3D Material Shader: #{path}")
  rescue ex
    Godot.print("[CRShaderViewer] Error applying material #{path}: #{ex.message}")
  end

  def apply_post_process_shader(path : String) : Void
    res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
    shader = res_loader.call_obj("load", path)
    return unless shader && !shader.pointer.null?

    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat
    mat.call("set_shader", shader)
    @active_material = mat

    @post_process_rect.try &.call("set_material", mat)
    Godot.print("[CRShaderViewer] Applied Post-Process Shader: #{path}")
  rescue ex
    Godot.print("[CRShaderViewer] Error applying post-process #{path}: #{ex.message}")
  end

  def apply_compute_shader_preview(path : String) : Void
    # For compute shaders, render fallback procedural preview material on full screen
    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat

    # Load procedural plasma or blur fallback for visual compute feedback
    res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
    if fallback_shader = res_loader.call_obj("load", "res://shaders/basic_spatial.gdshader")
      mat.call("set_shader", fallback_shader)
    end

    @active_material = mat
    @post_process_rect.try &.call("set_material", mat)
    Godot.print("[CRShaderViewer] Initialized Compute Shader Simulation Preview: #{path}")
  rescue ex
    Godot.print("[CRShaderViewer] Error setting compute preview: #{ex.message}")
  end

  def update_param(slot : Int32, value : Float64) : Void
    preset = @presets[@current_shader_idx]?
    return unless preset && @active_material

    param_name = case slot
                 when 1 then preset.param1_name
                 when 2 then preset.param2_name
                 when 3 then preset.param3_name
                 when 4 then preset.param4_name
                 else        return
                 end

    if mat = @active_material
      mat.call("set_shader_parameter", param_name, value)
    end
  end

  def _process(delta : Float64) : Void
    @time_elapsed += delta

    # Rotate 3D preview meshes if auto-rotate enabled
    if @auto_rotate && (pivot = @pivot)
      pivot.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
      pivot.call("rotate_x", (@rotation_speed * 0.35_f32 * delta.to_f32).to_f64)
    end

    # Real-time performance monitor
    if label = @fps_label
      fps = delta > 0.0 ? (1.0 / delta).round.to_i : 60
      ms = (delta * 1000.0).round(1)
      label.call("set_text", "Performance: #{fps} FPS (#{ms} ms)")
    end
  end
end
