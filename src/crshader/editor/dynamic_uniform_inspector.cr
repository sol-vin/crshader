require "lapis"
require "../ast/shader_ast"
require "../parser/dsl_parser"
require "./variable_array_control"
require "./procedural_textures"

module CrShader
  include Godot

  # =============================================================================
  # DynamicUniformInspector - Live Godot 4 Uniform Parameter Inspector
  # =============================================================================
  # Analyzes any compiled ShaderProgram or .crshader uniform list and dynamically
  # synthesizes the appropriate UI controls:
  # - Float/Int with hint_range -> HSlider + synced display + reset + LFO animate button
  # - Color / vec4 (source_color) -> ColorPickerButton
  # - Bool -> CheckBox
  # - Enums (hint_enum) -> OptionButton
  # - Vec2 / Vec3 / Vec4 -> Multi-component sub-sliders (X, Y, Z, W)
  # - Sampler2D -> Texture slot swapper with procedural textures
  # - Color arrays / Palettes -> VariableArrayControl
  # - Groups / Subgroups -> Titled separator headers
  # All changes sync in real-time to active_material.set_shader_parameter().
  @[Tool]
  node DynamicUniformInspector < VBoxContainer do
    struct LFOState
      getter base_val : Float64
      getter min_v : Float64
      getter max_v : Float64
      getter speed : Float64
      getter slider : Godot::HSlider
      getter val_label : Godot::Label?

      def initialize(
        @base_val : Float64,
        @min_v : Float64,
        @max_v : Float64,
        @speed : Float64,
        @slider : Godot::HSlider,
        @val_label : Godot::Label? = nil
      )
      end
    end

    property active_material : Godot::ShaderMaterial? = nil
    property default_values = Hash(String, Float64).new
    property current_program : ShaderProgram? = nil
    property lfos = Hash(String, LFOState).new
    property elapsed_time : Float64 = 0.0

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def configure(program : ShaderProgram, material : Godot::ShaderMaterial?) : Void
      clear_controls
      @active_material = material
      @current_program = program
      @default_values.clear
      @lfos.clear

      # Top toolbar for parameter count, copy DSL, and quick reset
      header = Godot.create(Godot::HBoxContainer)
      if header
        title = Godot.create(Godot::Label)
        if title
          title.call("set_text", "⚙ Uniform Parameters (#{program.uniforms.size})")
          title.call("add_theme_font_size_override", "font_size", 12)
          title.call("add_theme_color_override", "font_color", Color.new(0.7_f32, 0.85_f32, 1.0_f32, 1.0_f32))
          header.call("add_child", title)
        end

        spacer = Godot.create(Godot::Control)
        if spacer
          spacer.call("set_h_size_flags", 3)
          header.call("add_child", spacer)
        end

        # Copy DSL Button
        copy_btn = Godot.create(Godot::Button)
        if copy_btn
          copy_btn.call("set_text", "📋 Copy DSL")
          copy_btn.call("set_tooltip_text", "Copy current uniform parameters as Crystal DSL")
          copy_btn.connect("pressed") do |_args|
            copy_uniforms_dsl
          end
          header.call("add_child", copy_btn)
        end

        # Reset All Button
        reset_all_btn = Godot.create(Godot::Button)
        if reset_all_btn
          reset_all_btn.call("set_text", "↺ Reset All")
          reset_all_btn.call("set_tooltip_text", "Reset all parameters to default values")
          reset_all_btn.connect("pressed") do |_args|
            reset_all_defaults
          end
          header.call("add_child", reset_all_btn)
        end

        call("add_child", header)
      end

      # Populate controls by group
      current_group : String? = nil
      program.uniforms.each do |u|
        # Render group header
        if u.group && u.group != current_group
          current_group = u.group
          grp_label = Godot.create(Godot::Label)
          if grp_label
            grp_label.call("set_text", "─── #{current_group} ───")
            grp_label.call("add_theme_font_size_override", "font_size", 11)
            grp_label.call("add_theme_color_override", "font_color", Color.new(0.6_f32, 0.7_f32, 0.8_f32, 1.0_f32))
            call("add_child", grp_label)
          end
        end

        ctrl = create_widget_for_uniform(u)
        call("add_child", ctrl) if ctrl
      end
    end

    def configure_from_source(source : String, material : Godot::ShaderMaterial?) : Void
      parser = DslParser.new
      begin
        program = parser.parse(source)
        configure(program, material)
      rescue ex
        # Handle syntax error gracefully
      end
    end

    def clear_controls : Void
      @lfos.clear
      get_children.each do |c|
        call("remove_child", c)
        c.call("queue_free")
      end
    end

    private def create_widget_for_uniform(u : UniformDecl) : Godot::Control?
      # 1. Palette / Variable array
      if u.is_array? || u.name.includes?("palette")
        ctrl = VariableArrayControl.new
        ctrl.configure(u.name, @active_material)
        return ctrl
      end

      # 2. Sampler2D Texture Slot
      t_down = u.type_name.downcase
      if t_down.starts_with?("sampler2d")
        return create_texture_widget(u)
      end

      # 3. Color picker
      if u.type_name == "Color" || u.hints.includes?("source_color") || u.hints.includes?("hint_color")
        return create_color_widget(u)
      end

      # 4. Multi-component vectors
      if t_down == "vec2" || t_down == "ivec2" || t_down == "uvec2"
        return create_vector_widget(u, 2)
      elsif t_down == "vec3" || t_down == "ivec3" || t_down == "uvec3"
        return create_vector_widget(u, 3)
      elsif t_down == "vec4" || t_down == "ivec4" || t_down == "uvec4"
        return create_vector_widget(u, 4)
      end

      # 5. Boolean toggle
      if t_down == "bool"
        return create_bool_widget(u)
      end

      # 6. Int enum or option
      if t_down == "int" || t_down == "int32"
        enum_hint = u.hints.find { |h| h.starts_with?("hint_enum") }
        if enum_hint
          return create_enum_widget(u, enum_hint)
        end
      end

      # 7. Numeric Slider (Float or Int)
      create_slider_widget(u)
    end

    private def create_texture_widget(u : UniformDecl) : Godot::Control
      row = Godot.create(Godot::HBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless row

      row.call("add_theme_constant_override", "separation", 6)

      lbl = Godot.create(Godot::Label)
      if lbl
        lbl.call("set_custom_minimum_size", Vector2.new(110_f32, 0_f32))
        lbl.call("set_text", "#{u.name.capitalize}:")
        row.call("add_child", lbl)
      end

      opt = Godot.create(Godot::OptionButton)
      if opt
        opt.call("set_h_size_flags", 3)
        presets = ProceduralTextures.presets
        presets.each_with_index do |preset_name, idx|
          opt.call("add_item", "🖼 #{preset_name}", idx)
        end

        opt.connect("item_selected") do |args|
          selected_idx = args.first?.try(&.as_i) || 0
          preset_name = presets[selected_idx]? || presets.first
          tex = ProceduralTextures.get(preset_name)
          if tex && @active_material
            @active_material.try &.call("set_shader_parameter", u.name, tex)
          end
        end
        row.call("add_child", opt)
      end

      row
    end

    private def create_vector_widget(u : UniformDecl, components : Int32) : Godot::Control
      vbox = Godot.create(Godot::VBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless vbox

      vbox.call("add_theme_constant_override", "separation", 4)

      # Title
      header = Godot.create(Godot::HBoxContainer)
      if header
        lbl = Godot.create(Godot::Label)
        if lbl
          lbl.call("set_text", "#{u.name.capitalize} (Vec#{components}):")
          lbl.call("add_theme_font_size_override", "font_size", 11)
          lbl.call("add_theme_color_override", "font_color", Color.new(0.65_f32, 0.8_f32, 1.0_f32, 1.0_f32))
          header.call("add_child", lbl)
        end
        vbox.call("add_child", header)
      end

      row = Godot.create(Godot::HBoxContainer)
      return vbox unless row
      row.call("add_theme_constant_override", "separation", 8)

      labels = ["X", "Y", "Z", "W"]
      colors = [
        Color.new(0.9_f32, 0.35_f32, 0.35_f32, 1.0_f32), # Red
        Color.new(0.4_f32, 0.85_f32, 0.4_f32, 1.0_f32), # Green
        Color.new(0.35_f32, 0.65_f32, 1.0_f32, 1.0_f32), # Blue
        Color.new(0.85_f32, 0.85_f32, 0.85_f32, 1.0_f32) # Alpha
      ]

      vals = [0.0_f64, 0.0_f64, 0.0_f64, 0.0_f64]

      components.times do |i|
        sub_box = Godot.create(Godot::HBoxContainer)
        next unless sub_box
        sub_box.call("set_h_size_flags", 3)
        sub_box.call("add_theme_constant_override", "separation", 2)

        sub_lbl = Godot.create(Godot::Label)
        if sub_lbl
          sub_lbl.call("set_text", labels[i])
          sub_lbl.call("add_theme_color_override", "font_color", colors[i])
          sub_lbl.call("add_theme_font_size_override", "font_size", 10)
          sub_box.call("add_child", sub_lbl)
        end

        spin = Godot.create(Godot::HSlider)
        if spin
          spin.call("set_h_size_flags", 3)
          spin.call("set_min", -10.0)
          spin.call("set_max", 10.0)
          spin.call("set_step", 0.05)
          spin.call("set_value", 0.0)

          spin.connect("value_changed") do |args|
            new_v = args.first?.try(&.as_f.to_f64) || 0.0_f64
            vals[i] = new_v
            sync_vector_parameter(u.name, components, vals)
          end
          sub_box.call("add_child", spin)
        end

        row.call("add_child", sub_box)
      end

      vbox.call("add_child", row)
      vbox
    end

    private def sync_vector_parameter(name : String, components : Int32, vals : Array(Float64)) : Void
      mat = @active_material
      return unless mat

      case components
      when 2
        mat.call("set_shader_parameter", name, Vector2.new(vals[0].to_f32, vals[1].to_f32))
      when 3
        mat.call("set_shader_parameter", name, Vector3.new(vals[0].to_f32, vals[1].to_f32, vals[2].to_f32))
      when 4
        mat.call("set_shader_parameter", name, Color.new(vals[0].to_f32, vals[1].to_f32, vals[2].to_f32, vals[3].to_f32))
      end
    end

    private def create_slider_widget(u : UniformDecl) : Godot::Control
      row = Godot.create(Godot::HBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless row

      row.call("add_theme_constant_override", "separation", 6)

      # Label
      lbl = Godot.create(Godot::Label)
      if lbl
        lbl.call("set_custom_minimum_size", Vector2.new(110_f32, 0_f32))
        lbl.call("set_text", "#{u.name.capitalize}:")
        row.call("add_child", lbl)
      end

      min_v = 0.0_f64
      max_v = 1.0_f64
      step_v = 0.01_f64

      u.hints.each do |h|
        if m = h.match(/hint_range\(\s*([-\d.]+)\s*,\s*([-\d.]+)(?:\s*,\s*([-\d.]+))?\s*\)/)
          min_v = m[1].to_f64
          max_v = m[2].to_f64
          step_v = m[3]?.try(&.to_f64) || ((max_v - min_v) / 100.0)
        end
      end

      def_v = u.default_value.try { |v| v.to_s.gsub(/_f32|_f64/, "").to_f64? } || min_v
      @default_values[u.name] = def_v

      slider = Godot.create(Godot::HSlider)
      val_label = Godot.create(Godot::Label)

      if slider
        slider.call("set_h_size_flags", 3)
        slider.call("set_min", min_v)
        slider.call("set_max", max_v)
        slider.call("set_step", step_v)
        slider.call("set_value", def_v)

        slider.connect("value_changed") do |args|
          new_v = args.first?.try(&.as_f) || 0.0_f64
          val_label.try &.call("set_text", sprintf("%.2f", new_v))
          @active_material.try &.call("set_shader_parameter", u.name, new_v.to_f32)
        end
        row.call("add_child", slider)
      end

      if val_label
        val_label.call("set_custom_minimum_size", Vector2.new(45_f32, 0_f32))
        val_label.call("set_text", sprintf("%.2f", def_v))
        row.call("add_child", val_label)
      end

      # LFO Animate toggle button
      if slider
        lfo_btn = Godot.create(Godot::Button)
        if lfo_btn
          lfo_btn.call("set_text", "〰")
          lfo_btn.call("set_tooltip_text", "Toggle automated LFO oscillation animation")
          lfo_btn.connect("pressed") do |_args|
            if @lfos.has_key?(u.name)
              @lfos.delete(u.name)
              lfo_btn.call("set_text", "〰")
            else
              @lfos[u.name] = LFOState.new(def_v, min_v, max_v, 2.0_f64, slider, val_label)
              lfo_btn.call("set_text", "▶")
            end
          end
          row.call("add_child", lfo_btn)
        end
      end

      # Reset button
      reset_btn = Godot.create(Godot::Button)
      if reset_btn
        reset_btn.call("set_text", "↺")
        reset_btn.call("set_tooltip_text", "Reset to default (#{def_v})")
        reset_btn.connect("pressed") do |_args|
          slider.try &.call("set_value", def_v)
          @lfos.delete(u.name)
        end
        row.call("add_child", reset_btn)
      end

      row
    end

    private def create_color_widget(u : UniformDecl) : Godot::Control
      row = Godot.create(Godot::HBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless row

      row.call("add_theme_constant_override", "separation", 6)

      lbl = Godot.create(Godot::Label)
      if lbl
        lbl.call("set_custom_minimum_size", Vector2.new(110_f32, 0_f32))
        lbl.call("set_text", "#{u.name.capitalize}:")
        row.call("add_child", lbl)
      end

      picker = Godot.create(Godot::ColorPickerButton)
      if picker
        picker.call("set_h_size_flags", 3)
        initial_color = Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
        picker.call("set_pick_color", initial_color)

        picker.connect("color_changed") do |args|
          if new_color = args.first?
            @active_material.try &.call("set_shader_parameter", u.name, new_color)
          end
        end
        row.call("add_child", picker)
      end

      row
    end

    private def create_bool_widget(u : UniformDecl) : Godot::Control
      row = Godot.create(Godot::HBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless row

      check = Godot.create(Godot::CheckBox)
      if check
        check.call("set_text", u.name.capitalize)
        def_checked = u.default_value.try(&.to_s) == "true"
        check.call("set_pressed", def_checked)

        check.connect("toggled") do |args|
          is_on = args.first?.try(&.as_bool) || false
          @active_material.try &.call("set_shader_parameter", u.name, is_on)
        end
        row.call("add_child", check)
      end

      row
    end

    private def create_enum_widget(u : UniformDecl, enum_hint : String) : Godot::Control
      row = Godot.create(Godot::HBoxContainer)
      return Godot.create(Godot::Control).not_nil! unless row

      lbl = Godot.create(Godot::Label)
      if lbl
        lbl.call("set_custom_minimum_size", Vector2.new(110_f32, 0_f32))
        lbl.call("set_text", "#{u.name.capitalize}:")
        row.call("add_child", lbl)
      end

      opt = Godot.create(Godot::OptionButton)
      if opt
        opt.call("set_h_size_flags", 3)
        if m = enum_hint.match(/hint_enum\((.+)\)/)
          items = m[1].split(',').map(&.strip.gsub(/['"]/, ""))
          items.each_with_index do |item_str, idx|
            opt.call("add_item", item_str, idx)
          end
        end

        opt.connect("item_selected") do |args|
          selected_idx = args.first?.try(&.as_i) || 0
          @active_material.try &.call("set_shader_parameter", u.name, selected_idx)
        end
        row.call("add_child", opt)
      end

      row
    end

    def reset_all_defaults : Void
      @lfos.clear
      @default_values.each do |param_name, def_v|
        @active_material.try &.call("set_shader_parameter", param_name, def_v.to_f32)
      end
    end

    def copy_uniforms_dsl : Void
      program = @current_program
      return unless program

      lines = [] of String
      lines << "# CRShader Parameter Snapshot"
      program.uniforms.each do |u|
        val = @default_values[u.name]? || u.default_value || "nil"
        lines << "property #{u.name} : #{u.type_name} = #{val}"
      end

      text = lines.join("\n")
      # DisplayServer.singleton.clipboard_set
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      if ds && !ds.pointer.null?
        ds.call("clipboard_set", text)
        Godot.print("[CRShader] Copied uniform parameters snapshot to clipboard.")
      end
    rescue
    end

    def _process(delta : Float64) : Void
      return if @lfos.empty?
      @elapsed_time += delta

      @lfos.each do |param_name, lfo|
        amp = (lfo.max_v - lfo.min_v) * 0.45
        center = (lfo.max_v + lfo.min_v) * 0.5
        v = center + Math.sin(@elapsed_time * lfo.speed) * amp

        lfo.slider.call("set_value", v)
        lfo.val_label.try &.call("set_text", sprintf("%.2f", v))
        @active_material.try &.call("set_shader_parameter", param_name, v.to_f32)
      end
    end
  end
end
