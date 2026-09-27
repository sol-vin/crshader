require "lapis"
require "../../../src/crshader/compiler"
require "../../../src/crshader/editor/variable_array_control"
require "../../../src/crshader/editor/dynamic_uniform_inspector"
require "../../../src/crshader/editor/procedural_textures"
require "../../../src/crshader/editor/sandbox_bridge"

# =============================================================================
# CrShaderSandboxApp - Interactive Split-Screen Shader Sandbox & Live Studio
# =============================================================================
# Side-by-side live shader coding environment:
# Left pane: Code editor with syntax highlighting, 25+ reference samples,
# template presets, debounced live auto-compilation, inline error navigation,
# DSL snippet inserter, and generated GDShader preview.
# Right pane: Live 2D/3D viewport with 7 polygon meshes, screen-space quads,
# background patterns, texture slots, and dynamic uniform parameter inspector.
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
  @left_pane : Godot::Control? = nil
  @dir_light : Godot::DirectionalLight3D? = nil

  @auto_rotate : Bool = true
  @rotation_speed : Float32 = 0.8_f32
  @time_elapsed : Float64 = 0.0

  @current_sample_pristine : String = ""
  @sample_files = Array(String).new
  @inspector_vbox : Godot::VBoxContainer? = nil
  @dynamic_inspector : CrShader::DynamicUniformInspector? = nil

  # Live Coding & Debounced Compilation
  @auto_compile : Bool = true
  @dirty : Bool = false
  @debounce_time : Float64 = 0.35_f64
  @last_error_line : Int32 = 0

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

    # Locate Inspector container
    if node = get_node_or_null("Split/RightPane/VBox/InspectorPanel/VBox")
      @inspector_vbox = node.as?(Godot::VBoxContainer)
    end

    if node = get_node_or_null("Split/LeftPane")
      @left_pane = node.as?(Godot::Control)
    end
    if node = get_node_or_null("Split/RightPane/VBox/ViewportContainer/SubViewport/DirectionalLight3D")
      @dir_light = node.as?(Godot::DirectionalLight3D)
    end

    if sl = @status_label
      sl.call("set_mouse_filter", 0) # MOUSE_FILTER_STOP
      sl.connect("gui_input") do |_args|
        jump_to_error(@last_error_line) if @last_error_line > 0
      end
    end

    setup_syntax_highlighting
    setup_ui
    populate_samples
    select_shape("Sphere")
    set_sandbox_mode(SandboxMode::Spatial)

    # Check if a shader was bridged from Viewer
    if CrShader::SandboxBridge.has_pending?
      pending_src, pending_title = CrShader::SandboxBridge.consume_pending
      if pending_src && !pending_src.empty?
        @current_sample_pristine = pending_src
        @source_edit.try &.call("set_text", pending_src)
        compile_code
        set_status("Loaded from Viewer: #{pending_title || "Shader"}", is_error: false)
      end
    else
      # Initial template load
      load_template("New 3D Spatial")
    end
  end

  def setup_syntax_highlighting : Void
    edit = @source_edit
    return unless edit

    highlighter = Godot.create(Godot::CodeHighlighter)
    return unless highlighter

    kw_color = Color.new(0.85_f32, 0.45_f32, 0.9_f32, 1.0_f32)
    type_color = Color.new(0.35_f32, 0.75_f32, 1.0_f32, 1.0_f32)
    builtin_color = Color.new(1.0_f32, 0.75_f32, 0.3_f32, 1.0_f32)
    fn_color = Color.new(0.45_f32, 0.85_f32, 0.6_f32, 1.0_f32)
    comment_color = Color.new(0.5_f32, 0.55_f32, 0.6_f32, 1.0_f32)
    string_color = Color.new(0.95_f32, 0.85_f32, 0.4_f32, 1.0_f32)
    num_color = Color.new(0.8_f32, 0.6_f32, 1.0_f32, 1.0_f32)

    keywords = [
      "shader", "shader_type", "render_mode", "setup_gdshader",
      "uniform", "instance_uniform", "global_uniform", "varying", "const",
      "buffer", "push_constant", "shared", "image2d", "local_size", "require",
      "group", "subgroup", "field",
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

    # 3. Live Auto-Compile & Snippet Toolbar
    if toolbar2 = get_node_or_null("Split/LeftPane/VBox/Toolbar2")
      # Auto-Compile CheckBox
      auto_check = Godot.create(Godot::CheckBox)
      if auto_check
        auto_check.call("set_text", "Auto-Compile")
        auto_check.call("set_pressed", true)
        auto_check.connect("toggled") do |args|
          @auto_compile = args.first?.try(&.as_bool) || false
        end
        toolbar2.call("add_child", auto_check)
      end

      # Snippets Dropdown
      snippet_opt = Godot.create(Godot::OptionButton)
      if snippet_opt
        snippet_opt.call("add_item", "⚡ Insert Snippet...", 0)
        snippets = [
          "Uniform (Float Range)",
          "Uniform (Color)",
          "Uniform (Texture)",
          "Uniform (Palette)",
          "Stage (Fragment)",
          "Stage (Vertex)",
          "Compositor Effect",
          "Compute Kernel",
          "Stylized Toon PBR",
          "Require (std/dither)",
          "Require (std/curl_noise)",
          "Require (std/color_spaces)",
          "Require (std/atmosphere)",
          "Require (std/glitch)",
          "Generate Node"
        ]
        snippets.each_with_index do |sn, idx|
          snippet_opt.call("add_item", sn, idx + 1)
        end
        snippet_opt.connect("item_selected") do |args|
          idx = args.first?.try(&.as_i) || 0
          if idx > 0
            insert_snippet(snippets[idx - 1])
            snippet_opt.call("select", 0)
          end
        end
        toolbar2.call("add_child", snippet_opt)
      end
    end

    # Connect compile & reset buttons
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

    if toolbar2 = get_node_or_null("Split/LeftPane/VBox/Toolbar2")
      copy_btn = Godot.create(Godot::Button)
      if copy_btn
        copy_btn.call("set_text", "📋 Copy GDShader")
        copy_btn.call("set_tooltip_text", "Copy generated GDShader code to clipboard")
        copy_btn.connect("pressed") do |_args|
          copy_target_code
        end
        toolbar2.call("add_child", copy_btn)
      end

      f11_btn = Godot.create(Godot::Button)
      if f11_btn
        f11_btn.call("set_text", "⛶ (F11)")
        f11_btn.call("set_tooltip_text", "Toggle fullscreen viewport preview")
        f11_btn.connect("pressed") do |_args|
          toggle_fullscreen_viewport
        end
        toolbar2.call("add_child", f11_btn)
      end
    end

    # Mount Lighting Studio Option in ViewportToolbar
    if vp_tb = get_node_or_null("Split/RightPane/VBox/ViewportToolbar")
      light_lbl = Godot.create(Godot::Label)
      if light_lbl
        light_lbl.call("set_text", "Light:")
        vp_tb.call("add_child", light_lbl)
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
        vp_tb.call("add_child", light_opt)
      end
    end

    # Back to Viewer button if launched via Bridge
    if CrShader::SandboxBridge.from_viewer? && (tb1 = get_node_or_null("Split/LeftPane/VBox/Toolbar1"))
      back_btn = Godot.create(Godot::Button)
      if back_btn
        back_btn.call("set_text", "◀ Viewer")
        back_btn.call("set_tooltip_text", "Return to Showcase Viewer")
        back_btn.connect("pressed") do |_args|
          return_to_viewer
        end
        tb1.call("add_child", back_btn)
      end
    end

    # Source Edit text change for live debounce
    if edit = @source_edit
      edit.connect("text_changed") do |_args|
        @dirty = true
        @debounce_time = 0.35_f64
      end
    end

    # Viewport Toolbars
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
  end

  def insert_snippet(name : String) : Void
    code_to_insert = case name
                     when "Uniform (Float Range)"
                       "property speed : Float32 = 1.0, range: 0.0..5.0, step: 0.1\n"
                     when "Uniform (Color)"
                       "property tint : Color = Color.hex(\"#3498db\"), hint: :source_color\n"
                     when "Uniform (Texture)"
                       "sampler :albedo_map, filter: :linear, repeat: :enable\n"
                     when "Uniform (Palette)"
                       "uniform target_palette : ColorPalette = resource(\"res://default_palettes/cottonville.tres\")\n"
                     when "Stage (Fragment)"
                       "stage :fragment do\n  COLOR = vec4(UV.x, UV.y, 0.5, 1.0)\nend\n"
                     when "Stage (Vertex)"
                       "stage :vertex do\n  VERTEX.y += sin(TIME * 2.0 + VERTEX.x) * 0.1\nend\n"
                     when "Compositor Effect"
                       "compositor_effect :post_transparent do\n  access :color\n  process_pixel do |coord, color|\n    output_pixel(coord, vec4(1.0 - color.rgb, color.a))\n  end\nend\n"
                     when "Compute Kernel"
                       "compute_kernel 8, 8, 1 do\n  kernel_2d(512, 512) do\n    # Auto bounds guarded thread work\n  end\nend\n"
                     when "Stylized Toon PBR"
                       "render_mode :diffuse_toon, :specular_toon\nproperty albedo : Color = Color.hex(\"#e67e22\"), hint: :source_color\nproperty roughness : Float32 = 0.2, range: 0.0..1.0, step: 0.05\n\nstage :fragment do\n  ALBEDO = albedo.rgb\n  ROUGHNESS = roughness\nend\n"
                     when "Require (std/dither)"
                       "require \"std/dither\"\n"
                     when "Require (std/curl_noise)"
                       "require \"std/curl_noise\"\n"
                     when "Require (std/color_spaces)"
                       "require \"std/color_spaces\"\n"
                     when "Require (std/atmosphere)"
                       "require \"std/atmosphere\"\n"
                     when "Require (std/glitch)"
                       "require \"std/glitch\"\n"
                     when "Generate Node"
                       "generate_node :mesh3d, \"GeneratedShaderMesh\"\n"
                     else
                       ""
                     end

    if edit = @source_edit
      curr_line = edit.call("get_caret_line").as_i
      edit.call("insert_line_at", curr_line, code_to_insert)
      @dirty = true
      @debounce_time = 0.2_f64
    end
  end

  def populate_samples : Void
    opt = @sample_option
    return unless opt

    opt.call("clear")
    @sample_files.clear

    sample_paths = [
      "examples/shader_sandbox/samples/*.crshader",
      "samples/*.crshader",
      "examples/*.crshader"
    ]

    all_files = Set(String).new
    sample_paths.each do |p|
      Dir.glob(p).each { |f| all_files.add(f) }
    end

    opt.call("add_item", "Load Reference Sample...", 0)
    sorted_files = all_files.to_a.sort
    sorted_files.each_with_index do |f, idx|
      @sample_files << f
      base_name = File.basename(f, ".crshader").gsub('_', ' ').capitalize
      opt.call("add_item", "#{idx + 1}. #{base_name}", idx + 1)
    end

    opt.connect("item_selected") do |args|
      idx = args.first?.try(&.as_i) || 0
      if idx > 0 && idx <= @sample_files.size
        load_sample_file(@sample_files[idx - 1])
      end
    end
  end

  def load_sample_file(path : String) : Void
    return unless File.exists?(path)
    content = File.read(path)
    @current_sample_pristine = content

    # Auto detect mode from shader content
    if content.includes?("shader_type :compute")
      set_sandbox_mode(SandboxMode::Compute)
    elsif content.includes?("SCREEN_UV") || content.includes?("hint_screen_texture")
      set_sandbox_mode(SandboxMode::ScreenSpace)
    elsif content.includes?("shader_type :canvas_item")
      set_sandbox_mode(SandboxMode::CanvasItem)
    else
      set_sandbox_mode(SandboxMode::Spatial)
    end

    @source_edit.try &.call("set_text", content)
    compile_code
    set_status("Loaded sample: #{File.basename(path)}", is_error: false)
  end

  def load_template(name : String) : Void
    code = case name
           when "New 3D Spatial"
             set_sandbox_mode(SandboxMode::Spatial)
             <<-CR
               shader_type :spatial
               render_mode :cull_disabled, :depth_draw_opaque

               setup_gdshader

               uniform albedo : Color = Color.new(0.2, 0.6, 0.95, 1.0), hint: :source_color
               uniform roughness : Float32 = 0.3, hint: hint_range(0.0, 1.0)
               uniform metallic : Float32 = 0.2, hint: hint_range(0.0, 1.0)
               uniform wave_speed : Float32 = 2.0, hint: range(0.1, 5.0, 0.1)
               uniform wave_height : Float32 = 0.15, hint: range(0.0, 0.5, 0.01)

               def vertex()
                 offset = sin(TIME * wave_speed + VERTEX.x * 2.0) * wave_height
                 VERTEX.y = VERTEX.y + offset
               end

               def fragment()
                 ALBEDO = albedo.rgb
                 ROUGHNESS = roughness
                 METALLIC = metallic
               end
             CR

           when "New 2D CanvasItem"
             set_sandbox_mode(SandboxMode::CanvasItem)
             <<-CR
               shader_type :canvas_item
               render_mode :unshaded

               uniform tint : Color = Color.new(1.0, 0.8, 0.3, 1.0), hint: :source_color
               uniform speed : Float32 = 3.0, hint: range(0.1, 10.0, 0.1)
               uniform pulse_scale : Float32 = 0.2, hint: range(0.0, 0.5, 0.02)

               def fragment()
                 tex = texture(TEXTURE, UV)
                 pulse = sin(TIME * speed) * pulse_scale + (1.0 - pulse_scale)
                 COLOR = tex * tint * pulse
               end
             CR

           when "New Screen Space"
             set_sandbox_mode(SandboxMode::ScreenSpace)
             <<-CR
               shader_type :canvas_item
               render_mode :unshaded

               require "std/math"
               require "std/post_processing"

               uniform screen_tex : Sampler2D, hint: :screen_texture, filter: :linear
               uniform vignette_radius : Float32 = 0.75, hint: range(0.1, 1.0, 0.05)
               uniform vignette_softness : Float32 = 0.45, hint: range(0.05, 0.8, 0.05)

               def fragment()
                 col = texture(screen_tex, SCREEN_UV)
                 vig = vignette(SCREEN_UV, vignette_radius, vignette_softness)
                 COLOR = vec4(col.rgb * vig, 1.0)
               end
             CR

           when "New Compute"
             set_sandbox_mode(SandboxMode::Compute)
             <<-CR
               shader_type :compute

               local_size 8, 8, 1

               image2d output_image, format: :rgba32f, set: 0, binding: 0

               def main()
                 pos = ivec2(gl_GlobalInvocationID.xy)
                 color = vec4(float(pos.x) / 512.0, float(pos.y) / 512.0, 0.5, 1.0)
                 imageStore(output_image, pos, color)
               end
             CR

           else
             return
           end

    @current_sample_pristine = code
    @source_edit.try &.call("set_text", code)
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

      # Clear error styling on CodeEdit
      if @last_error_line > 0 && edit
        edit.call("set_line_as_executing", @last_error_line - 1, false)
        edit.call("set_line_background_color", @last_error_line - 1, Color.new(0_f32, 0_f32, 0_f32, 0_f32))
        @last_error_line = 0
      end

      @target_edit.try &.call("set_text", target_code)
      set_status("✔ Compiled successfully in #{elapsed_ms}ms (#{target_code.lines.size} lines)", is_error: false)

      apply_compiled_shader(target_code)

      # Dynamically synthesize parameter controls for all uniforms
      if program = compiler.last_program
        if container = @inspector_vbox
          inspector = @dynamic_inspector
          if inspector.nil?
            inspector = CrShader::DynamicUniformInspector.new
            container.call("add_child", inspector)
            @dynamic_inspector = inspector
          end
          inspector.configure(program, @active_material)
        end
      end
    rescue ex : CrShader::ShaderError
      line_num = ex.line_number || 1
      @last_error_line = line_num
      if edit
        edit.call("set_line_as_executing", line_num - 1, true)
        edit.call("set_line_background_color", line_num - 1, Color.new(0.6_f32, 0.15_f32, 0.15_f32, 0.35_f32))
      end
      set_status("✖ Line #{line_num}: #{ex.message} (Click to jump)", is_error: true)
      jump_to_error(line_num)
    rescue ex
      set_status("✖ #{ex.message}", is_error: true)
    end
  end

  def jump_to_error(line : Int32) : Void
    if edit = @source_edit
      edit.call("set_caret_line", Math.max(0, line - 1))
      edit.call("set_caret_column", 0)
      edit.call("center_viewport_to_caret")
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

  private def set_status(msg : String, is_error : Bool = false) : Void
    if lbl = @status_label
      lbl.call("set_text", msg)
      col = is_error ? Color.new(1.0_f32, 0.35_f32, 0.35_f32, 1.0_f32) : Color.new(0.4_f32, 0.9_f32, 0.5_f32, 1.0_f32)
      lbl.call("add_theme_color_override", "font_color", col)
    end
  end

  def _process(delta : Float64) : Void
    @time_elapsed += delta

    # Debounced live recompile
    if @auto_compile && @dirty
      @debounce_time -= delta
      if @debounce_time <= 0.0
        @dirty = false
        compile_code
      end
    end

    if @auto_rotate && (pivot = @pivot) && @current_mode == SandboxMode::Spatial
      pivot.call("rotate_y", (@rotation_speed * delta.to_f32).to_f64)
      pivot.call("rotate_x", (@rotation_speed * 0.35_f32 * delta.to_f32).to_f64)
    end
  end

  def toggle_fullscreen_viewport : Void
    if lp = @left_pane
      is_vis = lp.call("is_visible").as_bool
      lp.call("set_visible", !is_vis)
      set_status(is_vis ? "Preview Mode (F11 to restore editor)" : "Editor restored", is_error: false)
    end
  end

  def select_lighting_preset(idx : Int32) : Void
    light = @dir_light
    return unless light

    case idx
    when 0 # Studio 3-Point
      light.call("set_rotation_degrees", Vector3.new(-45_f32, 45_f32, 0_f32))
      light.call("set_color", Color.new(1.0_f32, 0.98_f32, 0.95_f32, 1.0_f32))
      light.call("set_param", 2, 1.2_f32)
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

  def copy_target_code : Void
    code = @target_edit.try(&.call("get_text").to_s) || ""
    if !code.empty?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      if ds && !ds.pointer.null?
        ds.call("clipboard_set", code)
        set_status("✔ GDShader copied to clipboard!", is_error: false)
      end
    end
  end

  def copy_source_code : Void
    code = @source_edit.try(&.call("get_text").to_s) || ""
    if !code.empty?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      if ds && !ds.pointer.null?
        ds.call("clipboard_set", code)
        set_status("✔ CRShader source copied to clipboard!", is_error: false)
      end
    end
  end

  def return_to_viewer : Void
    viewer_paths = [
      "res://../shader_viewer/scenes/viewer.tscn",
      "res://scenes/viewer.tscn",
      "examples/shader_viewer/scenes/viewer.tscn"
    ]
    viewer_paths.each do |vp|
      begin
        return if get_tree.call("change_scene_to_file", vp).to_i == 0
      rescue
      end
    end
  end

  def _unhandled_input(event : Godot::InputEvent) : Void
    if event.is_a?(Godot::InputEventKey) && event.call("is_pressed").as_bool
      key = event.call("get_keycode").to_i
      ctrl = begin
               event.call("is_ctrl_pressed").as_bool
             rescue
               false
             end
      shift = begin
                event.call("is_shift_pressed").as_bool
              rescue
                false
              end

      if key == 4194342 # KEY_F11
        toggle_fullscreen_viewport
      elsif ctrl && key == 83 # KEY_S
        if shift
          copy_source_code
        else
          compile_code
        end
      elsif ctrl && key == 67 && shift # KEY_C + Shift
        copy_target_code
      elsif ctrl && key == 82 # KEY_R
        if !@current_sample_pristine.empty?
          @source_edit.try &.call("set_text", @current_sample_pristine)
          compile_code
          set_status("↺ Restored sample source.", is_error: false)
        end
      end
    end
  end
end
