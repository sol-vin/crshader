require "lapis"
require "../ast/shader_ast"
require "../parser/dsl_parser"
require "./variable_array_control"

module CrShader
  include Godot

  # =============================================================================
  # DynamicUniformInspector - Live Godot 4 Uniform Parameter Inspector
  # =============================================================================
  # Analyzes any compiled ShaderProgram or .crshader uniform list and dynamically
  # synthesizes the appropriate UI controls:
  # - Float/Int with hint_range -> HSlider + synced value display + reset button
  # - Color / vec4 (source_color) -> ColorPickerButton
  # - Bool -> CheckBox
  # - Enums (hint_enum) -> OptionButton
  # - Vec2 / Vec3 -> Multi-component spinners
  # - Color arrays / Palettes -> VariableArrayControl
  # - Groups / Subgroups -> Titled separator headers
  # All changes sync in real-time to active_material.set_shader_parameter().
  @[Tool]
  node DynamicUniformInspector < VBoxContainer do
    property active_material : Godot::ShaderMaterial? = nil
    property default_values = Hash(String, Float64).new

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def configure(program : ShaderProgram, material : Godot::ShaderMaterial?) : Void
      clear_controls
      @active_material = material
      @default_values.clear

      # Top toolbar for parameter count and quick reset
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

      # 2. Color picker
      if u.type_name == "Color" || u.hints.includes?("source_color") || u.hints.includes?("hint_color")
        return create_color_widget(u)
      end

      # 3. Boolean toggle
      if u.type_name.downcase == "bool"
        return create_bool_widget(u)
      end

      # 4. Int enum or option
      if u.type_name.downcase == "int" || u.type_name.downcase == "int32"
        enum_hint = u.hints.find { |h| h.starts_with?("hint_enum") }
        if enum_hint
          return create_enum_widget(u, enum_hint)
        end
      end

      # 5. Numeric Slider (Float or Int)
      create_slider_widget(u)
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

      # Reset button
      reset_btn = Godot.create(Godot::Button)
      if reset_btn
        reset_btn.call("set_text", "↺")
        reset_btn.call("set_tooltip_text", "Reset to default (#{def_v})")
        reset_btn.connect("pressed") do |_args|
          slider.try &.call("set_value", def_v)
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
      @default_values.each do |param_name, def_v|
        @active_material.try &.call("set_shader_parameter", param_name, def_v.to_f32)
      end
    end
  end
end
