require "lapis"
require "../../../src/crshader/editor/variable_array_control"
require "../../../src/crshader/editor/dynamic_uniform_inspector"
require "../../../src/crshader/editor/procedural_textures"
require "../../../src/crshader/editor/split_wipe_controller"
require "../../../src/crshader/editor/sandbox_bridge"

# =============================================================================
# CRShaderViewerApp - Interactive Shader Viewer Demo Controller
# =============================================================================
# Showcases 29+ procedural shaders authored with CRShader.
# Supports 3D polygon meshes (Sphere, Cube, Cylinder, Torus, Prism, Capsule, Plane),
# full-screen post-processing quads, camera compositor passes, compute shader previews,
# dynamic uniform parameter inspector, 3D camera orbit/zoom, and split compare mode.
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
  @camera : Godot::Camera3D? = nil
  @dir_light : Godot::DirectionalLight3D? = nil
  @world_env : Godot::WorldEnvironment? = nil
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
  @lighting_option : Godot::OptionButton? = nil
  @search_edit : Godot::LineEdit? = nil
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
  @dynamic_inspector : CrShader::DynamicUniformInspector? = nil
  @auto_rotate : Bool = true
  @rotation_speed : Float32 = 0.8_f32
  @time_elapsed : Float64 = 0.0

  @current_shader_idx : Int32 = 0
  @current_category : String = "All"
  @search_query : String = ""
  @filtered_indices : Array(Int32) = [] of Int32

  # Camera Orbit & Zoom State
  @is_dragging : Bool = false
  @drag_start_pos : Vector2 = Vector2.new(0_f32, 0_f32)
  @cam_distance : Float32 = 3.4_f32
  @cam_rot_x : Float32 = -0.26_f32
  @cam_rot_y : Float32 = 0.0_f32
  @compare_mode : Bool = false
  @split_wipe : CrShader::SplitWipeController? = nil

  # Comprehensive catalog of 29 shaders
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
      "Stylized Anime Toon PBR",
      "res://shaders/stylized_toon_pbr.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Anime/game PBR toon shading with multi-band diffuse ramps, specular curves, and rim glow.",
      "diffuse_steps", "shadow_threshold", "specular_size", "rim_power"
    ),
    ShaderPreset.new(
      "Water Caustics Ocean",
      "res://shaders/water_caustics_ocean.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Gerstner wave surface with animated dual-layer Voronoi caustics and Beer-Lambert extinction.",
      "wave_speed", "wave_height", "caustics_scale", "caustics_speed"
    ),
    ShaderPreset.new(
      "Dissolve Burn Hologram",
      "res://shaders/dissolve_burn_hologram.gdshader",
      PipelineMode::Material,
      "Spatial Materials",
      "Procedural Voronoi dissolve with incandescent glowing ember edges and holographic scanlines.",
      "dissolve_amount", "noise_scale", "burn_width", "holo_speed"
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
      "Analog VHS Glitch",
      "res://shaders/analog_vhs_glitch.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Authentic CRT/VHS artifacts with scanline jitter, tracking noise bar, and RGB split.",
      "tracking_jitter", "tape_crease_speed", "rgb_shift", "tube_curvature"
    ),
    ShaderPreset.new(
      "Volumetric Fog Raymarching",
      "res://shaders/volumetric_fog_raymarch.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Screen-space volumetric light shafts with depth collision and Henyey-Greenstein scattering.",
      "fog_density", "ray_steps", "scattering_g", "max_distance"
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
      "Sobel Edge Outline",
      "res://shaders/edge_detection_sobel.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Multi-axis gradient convolution edge-detection filter for comic cell-outlines.",
      "threshold", "edge_intensity", "edge_color", "outline_thickness"
    ),
    ShaderPreset.new(
      "Film Grain & Noise",
      "res://shaders/film_grain.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Temporal animated cinematic silver-halide photographic film emulsion noise.",
      "grain_amount", "grain_size", "colored_noise", "lum_bias"
    ),
    ShaderPreset.new(
      "Pixel Art Downscaler",
      "res://shaders/pixel_dither.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Grid pixel quantizer mapping viewports down to retro handheld resolutions.",
      "pixel_scale", "dither_amount", "color_depth", "contrast"
    ),
    ShaderPreset.new(
      "ASCII Terminal Art",
      "res://shaders/ascii_art.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Procedural monospace character glyph matrix reproducing early mainframe displays.",
      "char_size", "color_mode", "green_phosphor", "scanlines"
    ),
    ShaderPreset.new(
      "Kawase Bloom Glow",
      "res://shaders/bloom_kawase.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Dual-filter pyramid downsample and upsample Kawase bloom glow pass.",
      "bloom_threshold", "bloom_intensity", "glow_radius", "blend_mode"
    ),
    ShaderPreset.new(
      "Chromatic Vignette",
      "res://shaders/chromatic_vignette.gdshader",
      PipelineMode::ScreenSpace,
      "Screen Space",
      "Radial optical prism aberration with dark corner camera exposure falloff.",
      "aberration_strength", "vignette_radius", "vignette_softness", "color_fringe"
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
    ShaderPreset.new(
      "Compute Flowfield Particles",
      "res://shaders/compute_flowfield_particles.glsl",
      PipelineMode::Compute,
      "Compute Simulation",
      "100,000+ compute particles driven by 3D Curl Noise flow fields with barrier synchronization.",
      "particle_count", "noise_scale", "flow_speed", "delta_time"
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
    if node = get_node_or_null("Camera3D")
      @camera = node.as?(Godot::Camera3D)
    end
    if node = get_node_or_null("DirectionalLight3D")
      @dir_light = node.as?(Godot::DirectionalLight3D)
    end
    if node = get_node_or_null("WorldEnvironment")
      @world_env = node.as?(Godot::WorldEnvironment)
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

    # Locate container for dynamic parameter inspector
    if node = get_node_or_null("UI/Margin/Panel/VBox")
      @array_controls_container = node.as?(Godot::VBoxContainer)
    end

    discover_disk_presets
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

    # Enhanced Toolbar: Search Bar, Lighting Presets, Compare Button, Reset View
    if header = get_node_or_null("UI/Margin/Panel/VBox/Header")
      # Compare Toggle Button
      compare_btn = Godot.create(Godot::Button)
      if compare_btn
        compare_btn.call("set_text", "⇄ Compare (Space)")
        compare_btn.call("set_tooltip_text", "Toggle between base unshaded mesh and active shader")
        compare_btn.connect("pressed") do |_args|
          toggle_compare_mode
        end
        header.call("add_child", compare_btn)
      end

      # Reset View Button
      reset_cam_btn = Godot.create(Godot::Button)
      if reset_cam_btn
        reset_cam_btn.call("set_text", "👁 Reset View (R)")
        reset_cam_btn.call("set_tooltip_text", "Reset camera orbit and zoom distance")
        reset_cam_btn.connect("pressed") do |_args|
          reset_camera_and_params
        end
        header.call("add_child", reset_cam_btn)
      end

      # Edit in Sandbox Button
      edit_sandbox_btn = Godot.create(Godot::Button)
      if edit_sandbox_btn
        edit_sandbox_btn.call("set_text", "⚡ Edit in Sandbox (E)")
        edit_sandbox_btn.call("set_tooltip_text", "Open this shader in Live Sandbox Studio to edit code")
        edit_sandbox_btn.connect("pressed") do |_args|
          open_in_sandbox
        end
        header.call("add_child", edit_sandbox_btn)
      end

      # Search Input Box
      search_input = Godot.create(Godot::LineEdit)
      if search_input
        search_input.call("set_custom_minimum_size", Vector2.new(160_f32, 0_f32))
        search_input.call("set_placeholder", "🔍 Search Shaders...")
        search_input.connect("text_changed") do |args|
          query = args.first?.try(&.as_s) || ""
          filter_search(query)
        end
        header.call("add_child", search_input)
        @search_edit = search_input
      end
    end

    # Mount SplitWipeController into ScreenSpaceLayer
    if screen_layer = get_node_or_null("ScreenSpaceLayer")
      wipe = CrShader::SplitWipeController.new
      screen_layer.call("add_child", wipe)
      wipe.setup
      wipe.on_split_changed = ->(ratio : Float32) {
        apply_split_wipe(ratio)
      }
      @split_wipe = wipe
    end

    # Mount Lighting Studio Option in ControlsRow2
    if row2 = get_node_or_null("UI/Margin/Panel/VBox/ControlsRow2")
      light_lbl = Godot.create(Godot::Label)
      if light_lbl
        light_lbl.call("set_text", "Studio Light:")
        row2.call("add_child", light_lbl)
      end

      light_opt = Godot.create(Godot::OptionButton)
      if light_opt
        light_presets = ["Studio 3-Point", "Cyberpunk Neon", "Golden Hour Sunset", "Overcast Flat", "Dark Noir"]
        light_presets.each_with_index do |lp, idx|
          light_opt.call("add_item", lp, idx)
        end
        light_opt.connect("item_selected") do |args|
          idx = args.first?.try(&.as_i) || 0
          select_lighting_preset(idx)
        end
        row2.call("add_child", light_opt)
        @lighting_option = light_opt
      end
    end
  end

  def filter_category(cat_name : String) : Void
    @current_category = cat_name
    @filtered_indices.clear

    @presets.each_with_index do |p, idx|
      matches_cat = (cat_name == "All" || p.category == cat_name)
      matches_search = @search_query.empty? || p.name.downcase.includes?(@search_query.downcase) || p.description.downcase.includes?(@search_query.downcase)
      if matches_cat && matches_search
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

  def filter_search(query : String) : Void
    @search_query = query.strip
    filter_category(@current_category)
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

  def select_lighting_preset(idx : Int32) : Void
    light = @dir_light
    return unless light

    case idx
    when 0 # Studio 3-Point
      light.call("set_rotation_degrees", Vector3.new(-45_f32, 45_f32, 0_f32))
      light.call("set_color", Color.new(1.0_f32, 0.98_f32, 0.95_f32, 1.0_f32))
      light.call("set_param", 2, 1.2_f32) # PARAM_ENERGY
    when 1 # Cyberpunk Neon
      light.call("set_rotation_degrees", Vector3.new(-30_f32, -60_f32, 0_f32))
      light.call("set_color", Color.new(0.9_f32, 0.2_f32, 0.8_f32, 1.0_f32))
      light.call("set_param", 2, 1.5_f32)
    when 2 # Golden Hour Sunset
      light.call("set_rotation_degrees", Vector3.new(-15_f32, 80_f32, 0_f32))
      light.call("set_color", Color.new(1.0_f32, 0.6_f32, 0.2_f32, 1.0_f32))
      light.call("set_param", 2, 1.8_f32)
    when 3 # Overcast Flat
      light.call("set_rotation_degrees", Vector3.new(-80_f32, 0_f32, 0_f32))
      light.call("set_color", Color.new(0.85_f32, 0.9_f32, 1.0_f32, 1.0_f32))
      light.call("set_param", 2, 0.8_f32)
    when 4 # Dark Noir
      light.call("set_rotation_degrees", Vector3.new(-60_f32, 120_f32, 0_f32))
      light.call("set_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
      light.call("set_param", 2, 2.5_f32)
    end
  end

  def toggle_compare_mode : Void
    if wipe = @split_wipe
      wipe.set_active(!wipe.is_active)
      return
    end

    @compare_mode = !@compare_mode
    if active_mesh = @mesh_instances[@current_shape]?
      if @compare_mode
        active_mesh.call("set_surface_override_material", 0, nil)
        @post_process_rect.try &.call("set_visible", false)
        @mode_label.try &.call("set_text", "Mode: [COMPARE] Original Surface")
      else
        active_mesh.call("set_surface_override_material", 0, @active_material)
        preset = @presets[@current_shader_idx]?
        if preset && (preset.mode == PipelineMode::ScreenSpace || preset.mode == PipelineMode::Compositor)
          @post_process_rect.try &.call("set_visible", true)
        end
        activate_shader(@current_shader_idx)
      end
    end
  end

  def apply_split_wipe(ratio : Float32) : Void
    preset = @presets[@current_shader_idx]?
    return unless preset

    if preset.mode == PipelineMode::ScreenSpace || preset.mode == PipelineMode::Compositor
      if rect = @post_process_rect
        rect.call("set_anchor_and_offset", 0, ratio.to_f64, 0.0) # ANCHOR_LEFT
      end
    elsif preset.mode == PipelineMode::Material
      if active_mesh = @mesh_instances[@current_shape]?
        if ratio < 0.5_f32
          active_mesh.call("set_surface_override_material", 0, nil)
        else
          active_mesh.call("set_surface_override_material", 0, @active_material)
        end
      end
    end
  end

  def discover_disk_presets : Void
    existing_paths = Set.new(@presets.map(&.path))
    disk_patterns = [
      "examples/shader_viewer/shaders/*.crshader",
      "examples/*.crshader",
      "shaders/*.crshader"
    ]
    disk_patterns.each do |pattern|
      Dir.glob(pattern).each do |p|
        base = File.basename(p, ".crshader")
        gd_path = "res://shaders/#{base}.gdshader"
        next if existing_paths.includes?(gd_path)

        content = begin
                    File.read(p)
                  rescue
                    ""
                  end
        next if content.empty?

        mode = if content.includes?("shader_type :compute")
                 PipelineMode::Compute
               elsif content.includes?("SCREEN_UV") || content.includes?("hint_screen_texture")
                 PipelineMode::ScreenSpace
               elsif content.includes?("compositor_effect")
                 PipelineMode::Compositor
               else
                 PipelineMode::Material
               end

        category = case mode
                   when PipelineMode::Material    then "Spatial Materials"
                   when PipelineMode::ScreenSpace then "Screen Space"
                   when PipelineMode::Compositor  then "Compositor Passes"
                   when PipelineMode::Compute     then "Compute Simulation"
                   end

        name = base.gsub('_', ' ').capitalize
        desc = "Discovered shader preset: #{File.basename(p)}"
        @presets << ShaderPreset.new(name, gd_path, mode, category, desc)
        existing_paths.add(gd_path)
      end
    end
  end

  def cycle_mesh_shape : Void
    shapes = ["Sphere", "Cube", "Cylinder", "Torus", "Prism", "Capsule", "Plane"]
    idx = shapes.index(@current_shape) || 0
    next_idx = (idx + 1) % shapes.size
    next_shape = shapes[next_idx]
    select_shape(next_shape)
    @shape_option.try &.call("select", next_idx)
  end

  def open_in_sandbox : Void
    preset = @presets[@current_shader_idx]?
    return unless preset

    cr_name = preset.path.sub(/\.(gdshader|glsl)$/, ".crshader")
    disk_paths = [
      cr_name.sub("res://shaders/", "examples/shader_viewer/shaders/"),
      cr_name.sub("res://shaders/", "examples/"),
      cr_name.sub("res://shaders/", "shaders/"),
    ]

    found_path = disk_paths.find { |p| File.exists?(p) }
    source = found_path ? File.read(found_path) : ""

    if !source.empty?
      CrShader::SandboxBridge.send_to_sandbox(source, preset.name)
      Godot.print("[CRShaderViewer] Bridged shader to Sandbox: #{preset.name}")

      sandbox_paths = [
        "res://../shader_sandbox/scenes/sandbox.tscn",
        "res://scenes/sandbox.tscn",
        "examples/shader_sandbox/scenes/sandbox.tscn"
      ]
      sandbox_paths.each do |sp|
        begin
          res = get_tree.call("change_scene_to_file", sp).to_i
          return if res == 0
        rescue
        end
      end
    end
  end

  def reset_camera_and_params : Void
    @cam_distance = 3.4_f32
    @cam_rot_x = -0.26_f32
    @cam_rot_y = 0.0_f32
    update_camera_transform
    @dynamic_inspector.try &.reset_all_defaults
  end

  def update_camera_transform : Void
    if cam = @camera
      x = @cam_distance * Math.sin(@cam_rot_y) * Math.cos(@cam_rot_x)
      y = @cam_distance * Math.sin(-@cam_rot_x) + 0.6_f32
      z = @cam_distance * Math.cos(@cam_rot_y) * Math.cos(@cam_rot_x)
      cam.call("set_position", Vector3.new(x.to_f32, y.to_f32, z.to_f32))
      cam.call("look_at", Vector3.new(0_f32, 0.6_f32, 0_f32), Vector3.new(0_f32, 1_f32, 0_f32))
    end
  end

  def activate_shader(index : Int32) : Void
    return if index < 0 || index >= @presets.size
    @current_shader_idx = index
    preset = @presets[index]

    if opt = @shader_option
      if sub_idx = @filtered_indices.index(index)
        opt.call("select", sub_idx)
      end
    end

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

    case preset.mode
    when PipelineMode::Material
      @pivot.try &.call("set_visible", true)
      @post_process_rect.try &.call("set_visible", false)
      @sprite_2d.try &.call("set_visible", false)
      apply_material_shader(preset.path)

    when PipelineMode::ScreenSpace, PipelineMode::Compositor
      @pivot.try &.call("set_visible", true)
      @post_process_rect.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)
      apply_post_process_shader(preset.path)

    when PipelineMode::Compute
      @pivot.try &.call("set_visible", false)
      @post_process_rect.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)
      apply_compute_shader_preview(preset.path)
    end

    # Mount Dynamic Uniform Inspector
    if container = @array_controls_container
      inspector = @dynamic_inspector
      if inspector.nil?
        inspector = CrShader::DynamicUniformInspector.new
        container.call("add_child", inspector)
        @dynamic_inspector = inspector
      end

      # Locate .crshader source file on disk
      cr_name = preset.path.sub(/\.(gdshader|glsl)$/, ".crshader")
      disk_paths = [
        cr_name.sub("res://shaders/", "examples/shader_viewer/shaders/"),
        cr_name.sub("res://shaders/", "examples/"),
        cr_name.sub("res://shaders/", "shaders/"),
      ]

      found_path = disk_paths.find { |p| File.exists?(p) }
      if found_path
        inspector.configure_from_source(File.read(found_path), @active_material)
      else
        inspector.clear_controls
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
    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat

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

  def _unhandled_input(event : Godot::InputEvent) : Void
    if event.is_a?(Godot::InputEventMouseButton)
      btn_idx = event.call("get_button_index").to_i
      is_pressed = event.call("is_pressed").as_bool

      if is_pressed
        if btn_idx == 4 # WHEEL_UP
          @cam_distance = Math.max(1.2_f32, @cam_distance - 0.25_f32)
          update_camera_transform
        elsif btn_idx == 5 # WHEEL_DOWN
          @cam_distance = Math.min(8.0_f32, @cam_distance + 0.25_f32)
          update_camera_transform
        elsif btn_idx == 1 # MOUSE_BUTTON_LEFT
          @is_dragging = true
          @drag_start_pos = event.call("get_position").as_v2
        end
      else
        if btn_idx == 1
          @is_dragging = false
        end
      end
    elsif event.is_a?(Godot::InputEventMouseMotion) && @is_dragging
      pos = event.call("get_position").as_v2
      diff = pos - @drag_start_pos
      @drag_start_pos = pos

      @cam_rot_y += diff.x * 0.008_f32
      @cam_rot_x = Math.max(-1.4_f32, Math.min(1.4_f32, @cam_rot_x + diff.y * 0.008_f32))
      update_camera_transform
    elsif event.is_a?(Godot::InputEventKey) && event.call("is_pressed").as_bool
      key = event.call("get_keycode").to_i
      if key == 32 # KEY_SPACE
        toggle_compare_mode
      elsif key >= 49 && key <= 53 # Keys '1' to '5' for Lighting Presets
        select_lighting_preset(key - 49)
        @lighting_option.try &.call("select", key - 49)
      elsif key == 77 # KEY_M: Cycle mesh shape
        cycle_mesh_shape
      elsif key == 69 # KEY_E: Open in sandbox
        open_in_sandbox
      elsif key == 80 # KEY_P: Toggle auto-rotate
        @auto_rotate = !@auto_rotate
        @auto_rotate_check.try &.call("set_pressed", @auto_rotate)
      elsif key == 4194319 || key == 74 # KEY_LEFT or 'J'
        navigate_preset(-1)
      elsif key == 4194321 || key == 75 # KEY_RIGHT or 'K'
        navigate_preset(1)
      elsif key == 82 # KEY_R
        reset_camera_and_params
      end
    end
  end

  def _process(delta : Float64) : Void
    @time_elapsed += delta

    if @auto_rotate && (pivot = @pivot) && !@is_dragging
      pivot.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
      pivot.call("rotate_x", (@rotation_speed * 0.35_f32 * delta.to_f32).to_f64)
    end

    if label = @fps_label
      fps = delta > 0.0 ? (1.0 / delta).round.to_i : 60
      ms = (delta * 1000.0).round(1)
      label.call("set_text", "Performance: #{fps} FPS (#{ms} ms)")
    end
  end
end
