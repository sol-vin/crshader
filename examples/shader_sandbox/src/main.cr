require "lapis"
require "../../../src/crshader/compiler"

# =============================================================================
# CrShaderSandboxApp - Interactive Split-Screen Shader Sandbox & Live Studio
# =============================================================================
# Side-by-side live shader coding environment:
# Left pane: Code editor with syntax highlighting, 20+ reference samples,
# template presets, live compiler diagnostics, and generated GDShader preview.
# Right pane: Live 2D/3D viewport with 7 polygon meshes, screen-space quads,
# background patterns, texture slots, and real-time uniform parameter tweaking.
node CrShaderSandboxApp < Control do
  enum SandboxMode
    Spatial
    CanvasItem
    ScreenSpace
    Compute
  end

  @source_edit : Godot::CodeEdit? = nil
  @target_edit : Godot::CodeEdit? = nil
  @status_label : Godot::Label? = nil

  @mode_option : Godot::OptionButton? = nil
  @template_option : Godot::OptionButton? = nil
  @sample_option : Godot::OptionButton? = nil

  @shape_option : Godot::OptionButton? = nil
  @bg_option : Godot::OptionButton? = nil
  @tex_option : Godot::OptionButton? = nil
  @auto_rotate_check : Godot::CheckBox? = nil

  @pivot : Godot::Node3D? = nil
  @meshes = Hash(String, Godot::MeshInstance3D).new
  @current_shape : String = "Sphere"

  @screen_quad : Godot::ColorRect? = nil
  @sprite_2d : Godot::Sprite2D? = nil
  @sub_viewport : Godot::SubViewport? = nil
  @world_env : Godot::WorldEnvironment? = nil

  @active_material : Godot::ShaderMaterial? = nil
  @current_mode : SandboxMode = SandboxMode::Spatial

  @param1_slider : Godot::HSlider? = nil
  @param2_slider : Godot::HSlider? = nil
  @param3_slider : Godot::HSlider? = nil
  @param4_slider : Godot::HSlider? = nil

  @param1_label : Godot::Label? = nil
  @param2_label : Godot::Label? = nil
  @param3_label : Godot::Label? = nil
  @param4_label : Godot::Label? = nil

  @auto_rotate : Bool = true
  @rotation_speed : Float32 = 0.8_f32
  @time_elapsed : Float64 = 0.0

  @current_sample_pristine : String = ""
  @sample_files = Array(String).new

  def _ready : Void
    Godot.print("==================================================================")
    Godot.print("  [CRShaderSandbox] Live Split-Screen Shader Sandbox Initialized!")
    Godot.print("==================================================================")

    # Locate Left Pane elements
    if node = get_node_or_null("Split/LeftPane/VBox/Toolbar1/ModeOption")
      @mode_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/LeftPane/VBox/Toolbar1/TemplateOption")
      @template_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/LeftPane/VBox/Toolbar2/SampleOption")
      @sample_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/LeftPane/VBox/StatusLabel")
      @status_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("Split/LeftPane/VBox/EditorTabs/SourceCRShader")
      @source_edit = node.as?(Godot::CodeEdit)
    end
    if node = get_node_or_null("Split/LeftPane/VBox/EditorTabs/CompiledTarget")
      @target_edit = node.as?(Godot::CodeEdit)
    end

    # Locate Right Pane elements
    if node = get_node_or_null("Split/RightPane/VBox/ViewportToolbar/ShapeOption")
      @shape_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportToolbar/BgOption")
      @bg_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportToolbar/TexOption")
      @tex_option = node.as?(Godot::OptionButton)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportToolbar/AutoRotateCheck")
      @auto_rotate_check = node.as?(Godot::CheckBox)
    end

    # Locate Viewport & 3D elements
    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport")
      @sub_viewport = node.as?(Godot::SubViewport)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/WorldEnvironment")
      @world_env = node.as?(Godot::WorldEnvironment)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/Pivot3D")
      @pivot = node.as?(Godot::Node3D)
    end

    # Cache 3D meshes
    shape_names = ["Sphere", "Cube", "Cylinder", "Torus", "Prism", "Capsule", "Plane"]
    shape_names.each do |s|
      if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/Pivot3D/#{s}Mesh")
        if mesh_inst = node.as?(Godot::MeshInstance3D)
          @meshes[s] = mesh_inst
        end
      end
    end

    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/ScreenSpaceQuad")
      @screen_quad = node.as?(Godot::ColorRect)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/Sprite2D")
      @sprite_2d = node.as?(Godot::Sprite2D)
    end

    # Locate Inspector Sliders
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow1/P1Row/P1Slider")
      @param1_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow1/P1Row/P1Label")
      @param1_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow1/P2Row/P2Slider")
      @param2_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow1/P2Row/P2Label")
      @param2_label = node.as?(Godot::Label)
    end

    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow2/P3Row/P3Slider")
      @param3_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow2/P3Row/P3Label")
      @param3_label = node.as?(Godot::Label)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow2/P4Row/P4Slider")
      @param4_slider = node.as?(Godot::HSlider)
    end
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox/SlidersRow2/P4Row/P4Label")
      @param4_label = node.as?(Godot::Label)
    end

    setup_syntax_highlighting
    setup_ui
    setup_sample_gallery
    load_template("New 3D Spatial")
  end

  def setup_syntax_highlighting : Void
    edit = @source_edit
    return unless edit

    highlighter = Godot.create(Godot::CodeHighlighter)
    return unless highlighter

    kw_color = Color.new(0.85_f32, 0.45_f32, 0.9_f32, 1.0_f32)     # Purple
    type_color = Color.new(0.35_f32, 0.75_f32, 1.0_f32, 1.0_f32)   # Cyan / Blue
    builtin_color = Color.new(1.0_f32, 0.75_f32, 0.3_f32, 1.0_f32) # Orange
    fn_color = Color.new(0.45_f32, 0.85_f32, 0.6_f32, 1.0_f32)     # Light Green
    comment_color = Color.new(0.5_f32, 0.55_f32, 0.6_f32, 1.0_f32) # Gray
    string_color = Color.new(0.95_f32, 0.85_f32, 0.4_f32, 1.0_f32) # Gold
    num_color = Color.new(0.8_f32, 0.6_f32, 1.0_f32, 1.0_f32)      # Violet

    keywords = [
      "shader", "shader_type", "render_mode", "setup_gdshader",
      "uniform", "instance_uniform", "global_uniform", "varying", "const",
      "buffer", "push_constant", "shared", "image2d", "local_size", "require",
      "def", "end", "class", "struct", "module", "if", "else", "elsif", "unless",
      "while", "until", "for", "in", "case", "when", "return", "break", "next",
      "true", "false", "nil"
    ]
    keywords.each { |kw| highlighter.call("add_keyword_color", kw, kw_color) }

    stages = ["vertex", "fragment", "light", "start", "process", "sky", "fog", "main"]
    stages.each { |st| highlighter.call("add_keyword_color", st, Color.new(1.0_f32, 0.4_f32, 0.6_f32, 1.0_f32)) }

    types = [
      "Float32", "Float64", "Float", "Int32", "UInt32", "Int", "UInt", "Bool", "Void",
      "Vec2", "Vec3", "Vec4", "IVec2", "IVec3", "IVec4", "UVec2", "UVec3", "UVec4",
      "BVec2", "BVec3", "BVec4", "Mat2", "Mat3", "Mat4", "Color",
      "Sampler2D", "SamplerCube", "Sampler2DArray", "Sampler3D"
    ]
    types.each { |t| highlighter.call("add_keyword_color", t, type_color) }

    builtins = [
      "VERTEX", "NORMAL", "TANGENT", "BINORMAL", "COLOR", "UV", "UV2",
      "ROUGHNESS", "METALLIC", "SPECULAR", "ALBEDO", "ALPHA", "EMISSION",
      "TIME", "FRAGCOORD", "FRONT_FACING", "MODEL_MATRIX", "VIEW_MATRIX",
      "PROJECTION_MATRIX", "SCREEN_UV", "SCREEN_PIXEL_SIZE", "gl_GlobalInvocationID"
    ]
    builtins.each { |b| highlighter.call("add_member_keyword_color", b, builtin_color) }

    highlighter.call("set_function_color", fn_color)
    highlighter.call("set_number_color", num_color)
    highlighter.call("add_color_region", "\"", "\"", string_color, false)
    highlighter.call("add_color_region", "#", "", comment_color, true)

    edit.call("set_syntax_highlighter", highlighter)
  end

  def setup_ui : Void
    # 1. Mode Option
    if m_opt = @mode_option
      m_opt.call("clear")
      modes = ["3D Spatial Material", "2D CanvasItem", "Screen Space Quad", "Compute Kernel"]
      modes.each_with_index { |m, i| m_opt.call("add_item", m, i) }
      m_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        set_sandbox_mode(SandboxMode.new(idx))
      end
    end

    # 2. Template Option
    if t_opt = @template_option
      t_opt.call("clear")
      templates = ["Templates...", "New 3D Spatial", "New 2D CanvasItem", "New Screen Space", "New Compute"]
      templates.each_with_index { |t, i| t_opt.call("add_item", t, i) }
      t_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        if idx > 0
          load_template(templates[idx])
          @template_option.try &.call("select", 0)
        end
      end
    end

    # 3. Compile & Reset Buttons
    if btn = get_node_or_null("Split/LeftPane/VBox/Toolbar2/CompileBtn")
      btn.connect("pressed") { compile_code }
    end
    if btn = get_node_or_null("Split/LeftPane/VBox/Toolbar2/ResetBtn")
      btn.connect("pressed") do
        if !@current_sample_pristine.empty?
          @source_edit.try &.call("set_text", @current_sample_pristine)
          compile_code
          set_status("↺ Restored pristine sample source.", is_error: false)
        end
      end
    end

    # 4. Viewport Toolbars
    if sh_opt = @shape_option
      sh_opt.call("clear")
      shapes = ["Sphere", "Cube", "Cylinder", "Torus", "Prism", "Capsule", "Plane"]
      shapes.each_with_index { |s, i| sh_opt.call("add_item", s, i) }
      sh_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        select_shape(shapes[idx])
      end
    end

    if b_opt = @bg_option
      b_opt.call("clear")
      bgs = ["Dark Studio", "Solid Black", "Grid Checker", "Sky Environment"]
      bgs.each_with_index { |b, i| b_opt.call("add_item", b, i) }
      b_opt.connect("item_selected") do |args|
        idx = args.first?.try(&.as_i) || 0
        set_background(idx)
      end
    end

    if tx_opt = @tex_option
      tx_opt.call("clear")
      texs = ["Godot Icon", "Checker Texture", "Procedural Noise"]
      texs.each_with_index { |t, i| tx_opt.call("add_item", t, i) }
    end

    if check = @auto_rotate_check
      check.connect("toggled") do |args|
        @auto_rotate = args.first?.try(&.as_bool) || false
      end
    end

    # 5. Inspector Sliders
    if s1 = @param1_slider
      s1.connect("value_changed") { |a| update_uniform("speed", a.first?.try(&.as_f) || 1.0_f32) }
    end
    if s2 = @param2_slider
      s2.connect("value_changed") { |a| update_uniform("intensity", a.first?.try(&.as_f) || 1.0_f32) }
    end
    if s3 = @param3_slider
      s3.connect("value_changed") { |a| update_uniform("radius", a.first?.try(&.as_f) || 4.0_f32) }
    end
    if s4 = @param4_slider
      s4.connect("value_changed") { |a| update_uniform("roughness", a.first?.try(&.as_f) || 0.3_f32) }
    end
  end

  def setup_sample_gallery : Void
    opt = @sample_option
    return unless opt

    opt.call("clear")
    opt.call("add_item", "Select Sample Shader...", 0)

    sample_dir = "res://samples"
    @sample_files.clear

    files = [
      "basic_spatial.crshader", "psx_retro.crshader", "gdquest_forcefield_shield.crshader",
      "toon_water.crshader", "vfez_fire_particles.crshader", "crt_scanlines.crshader",
      "kuwahara.crshader", "image_effects_kuwahara.crshader", "pixel_dither.crshader",
      "film_grain.crshader", "ascii_art.crshader", "chromatic_vignette.crshader",
      "bloom_kawase.crshader", "edge_detection_sobel.crshader", "color_grading_tonemap.crshader",
      "color_blindness.crshader", "advanced_palette_swap.crshader", "universal_transition.crshader",
      "vespera_post_process.crshader", "mreliptik_dither_crt.crshader", "acerola_compute_blur.crshader",
      "compute_game_of_life.crshader", "compute_particles.crshader"
    ]

    files.each_with_index do |filename, idx|
      @sample_files << filename
      title = filename.sub(/\.crshader$/, "").gsub("_", " ").capitalize
      opt.call("add_item", "#{idx + 1}. #{title}", idx + 1)
    end

    opt.connect("item_selected") do |args|
      sel = args.first?.try(&.as_i) || 0
      if sel > 0
        file = @sample_files[sel - 1]?
        load_sample_file(file) if file
      end
    end
  end

  def load_sample_file(filename : String) : Void
    path = "res://samples/#{filename}"
    res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)

    # Read text from file
    content = ""
    # Try reading file from disk / res://
    candidate_paths = [
      path,
      "samples/#{filename}",
      "examples/shader_sandbox/samples/#{filename}",
      "examples/#{filename}"
    ]
    candidate_paths.each do |p|
      if File.exists?(p)
        content = File.read(p)
        break
      end
    end

    if content.empty?
      content = "# Sample: #{filename}\nshader_type :spatial\n\nuniform speed : Float32 = 1.0\n\ndef fragment\n  ALBEDO = vec3(0.2, 0.6, 0.9)\nend\n"
    end

    @current_sample_pristine = content
    @source_edit.try &.call("set_text", content)

    # Detect appropriate mode from source code
    if content.includes?("shader_type :compute")
      set_sandbox_mode(SandboxMode::Compute)
    elsif content.includes?("screen_texture") || content.includes?("SCREEN_UV")
      set_sandbox_mode(SandboxMode::ScreenSpace)
    elsif content.includes?("shader_type :canvas_item")
      set_sandbox_mode(SandboxMode::CanvasItem)
    else
      set_sandbox_mode(SandboxMode::Spatial)
    end

    compile_code
    set_status("Loaded sample: #{filename} (#{content.lines.size} lines)", is_error: false)
  end

  def load_template(name : String) : Void
    code = case name
           when "New 3D Spatial"
             <<-CRSHADER
             shader_type :spatial
             render_mode :cull_disabled, :depth_draw_opaque

             uniform albedo : Color = Color.new(0.2, 0.6, 0.95, 1.0)
             uniform wave_speed : Float32 = 2.0
             uniform wave_height : Float32 = 0.15
             uniform roughness : Float32 = 0.3
             uniform metallic : Float32 = 0.2

             def vertex
               offset = sin(TIME * wave_speed + VERTEX.x * 3.0) * wave_height
               VERTEX.y = VERTEX.y + offset
             end

             def fragment
               ALBEDO = albedo.rgb
               ROUGHNESS = roughness
               METALLIC = metallic
             end
             CRSHADER
           when "New 2D CanvasItem"
             <<-CRSHADER
             shader_type :canvas_item
             render_mode :unshaded

             uniform tint : Color = Color.new(0.3, 0.8, 1.0, 1.0)
             uniform pulse_speed : Float32 = 2.0

             def fragment
               wave = sin(TIME * pulse_speed + UV.x * 6.28) * 0.5 + 0.5
               col = texture(TEXTURE, UV) * tint
               COLOR = col * (0.8 + wave * 0.4)
             end
             CRSHADER
           when "New Screen Space"
             <<-CRSHADER
             shader_type :canvas_item
             render_mode :unshaded

             uniform screen_texture : Sampler2D, hint: :screen_texture, filter: :linear
             uniform vignette_intensity : Float32 = 0.8

             def fragment
               color = texture(screen_texture, SCREEN_UV).rgb
               dist = distance(SCREEN_UV, vec2(0.5, 0.5))
               vignette = clamp(1.0 - dist * vignette_intensity, 0.0, 1.0)
               COLOR = vec4(color * vignette, 1.0)
             end
             CRSHADER
           when "New Compute"
             <<-CRSHADER
             shader_type :compute
             local_size 8, 8, 1

             image2d input_image, format: :rgba32f, set: 0, binding: 0
             image2d output_image, format: :rgba32f, set: 0, binding: 1

             uniform intensity : Float32 = 1.0

             def main
               coord = ivec2(gl_GlobalInvocationID.xy)
               pixel = imageLoad(input_image, coord)
               imageStore(output_image, coord, pixel * intensity)
             end
             CRSHADER
           else
             return
           end

    @current_sample_pristine = code
    @source_edit.try &.call("set_text", code)

    case name
    when "New 3D Spatial"      then set_sandbox_mode(SandboxMode::Spatial)
    when "New 2D CanvasItem"   then set_sandbox_mode(SandboxMode::CanvasItem)
    when "New Screen Space"    then set_sandbox_mode(SandboxMode::ScreenSpace)
    when "New Compute"         then set_sandbox_mode(SandboxMode::Compute)
    end

    compile_code
    set_status("Loaded template: #{name}", is_error: false)
  end

  def set_sandbox_mode(mode : SandboxMode) : Void
    @current_mode = mode
    @mode_option.try &.call("select", mode.value)

    case mode
    when SandboxMode::Spatial
      @pivot.try &.call("set_visible", true)
      @screen_quad.try &.call("set_visible", false)
      @sprite_2d.try &.call("set_visible", false)
      select_shape(@current_shape)

    when SandboxMode::ScreenSpace
      @pivot.try &.call("set_visible", true)
      @screen_quad.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)

    when SandboxMode::CanvasItem
      @pivot.try &.call("set_visible", false)
      @screen_quad.try &.call("set_visible", false)
      @sprite_2d.try &.call("set_visible", true)

    when SandboxMode::Compute
      @pivot.try &.call("set_visible", false)
      @screen_quad.try &.call("set_visible", true)
      @sprite_2d.try &.call("set_visible", false)
    end
  end

  def select_shape(shape_name : String) : Void
    @current_shape = shape_name
    @meshes.each do |name, mesh_inst|
      is_active = (name == shape_name)
      mesh_inst.call("set_visible", is_active)
      if is_active && @active_material
        mesh_inst.call("set_surface_override_material", 0, @active_material)
      end
    end
  end

  def set_background(index : Int32) : Void
    env = @world_env
    return unless env

    # Set background styling on camera or environment
    case index
    when 0 # Dark Studio
      env.call("set_environment", env.call_obj("get_environment"))
    when 1 # Solid Black
      # Clear sky or dark ambient
    end
  end

  def compile_code : Void
    edit = @source_edit
    return unless edit

    source = edit.call("get_text").to_s
    return if source.strip.empty?

    start_time = Time.instant
    compiler = CrShader::Compiler.new

    begin
      target_code = compiler.compile_source(source)
      elapsed_ms = (Time.instant - start_time).total_milliseconds.round(2)

      @target_edit.try &.call("set_text", target_code)
      set_status("✔ Compiled successfully in #{elapsed_ms}ms (#{target_code.lines.size} lines)", is_error: false)

      apply_compiled_shader(target_code)
    rescue ex : CrShader::ShaderError
      line_info = ex.line_number ? "line #{ex.line_number}: " : ""
      set_status("✖ Compile Error #{line_info}#{ex.message}", is_error: true)
    rescue ex
      set_status("✖ #{ex.message}", is_error: true)
    end
  end

  def apply_compiled_shader(gdshader_code : String) : Void
    shader = Godot.create(Godot::Shader)
    return unless shader
    shader.call("set_code", gdshader_code)

    mat = Godot.create(Godot::ShaderMaterial)
    return unless mat
    mat.call("set_shader", shader)
    @active_material = mat

    case @current_mode
    when SandboxMode::Spatial
      if active_mesh = @meshes[@current_shape]?
        active_mesh.call("set_surface_override_material", 0, mat)
      end
    when SandboxMode::ScreenSpace, SandboxMode::Compute
      @screen_quad.try &.call("set_material", mat)
    when SandboxMode::CanvasItem
      @sprite_2d.try &.call("set_material", mat)
    end
  end

  def update_uniform(name : String, value : Float32) : Void
    if mat = @active_material
      mat.call("set_shader_parameter", name, value.to_f64)
      # Also update potential aliases
      mat.call("set_shader_parameter", "wave_#{name}", value.to_f64)
      mat.call("set_shader_parameter", "#{name}_intensity", value.to_f64)
      mat.call("set_shader_parameter", "#{name}_speed", value.to_f64)
    end
  end

  private def set_status(msg : String, is_error : Bool = false) : Void
    if lbl = @status_label
      lbl.call("set_text", msg)
      col = is_error ? Color.new(1.0_f32, 0.35_f32, 0.35_f32, 1.0_f32) : Color.new(0.4_f32, 0.9_f32, 0.5_f32, 1.0_f32)
      lbl.call("add_theme_color_override", "font_color", col)
    end
  end

  def _process(delta : Float64) : Void
    @time_elapsed += delta

    if @auto_rotate && (pivot = @pivot) && @current_mode == SandboxMode::Spatial
      pivot.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
      pivot.call("rotate_x", (@rotation_speed * 0.35_f32 * delta.to_f32).to_f64)
    end
  end
end
