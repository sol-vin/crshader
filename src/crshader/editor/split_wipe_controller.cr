require "lapis"

module CrShader
  # =============================================================================
  # SplitWipeController - Interactive Before/After Split-Screen Comparator
  # =============================================================================
  # Provides an interactive split-screen wipe across the viewport, allowing users
  # to dynamically compare raw/unshaded inputs against active shaders in real-time.
  # Includes:
  # - A draggable divider line across the screen with visual handle
  # - Split ratio tracking [0.0 = 100% Original, 1.0 = 100% Shaded]
  # - Quick presets (25%, 50%, 75%, Full)
  # - Visual labels: "◀ Original" and "Shaded ▶"
  @[Tool]
  node SplitWipeController < Control do
    property split_ratio : Float32 = 0.5_f32
    property is_active : Bool = false
    property on_split_changed : Proc(Float32, Void)? = nil

    @slider : Godot::HSlider? = nil
    @divider_line : Godot::ColorRect? = nil
    @label_left : Godot::Label? = nil
    @label_right : Godot::Label? = nil
    @is_dragging : Bool = false

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def setup : Void
      call("set_anchors_preset", 15) # PRESET_FULL_RECT
      call("set_mouse_filter", 2)    # MOUSE_FILTER_IGNORE by default so viewport is clickable

      # Floating Wipe Bar Container at the bottom of the viewport
      bar_container = Godot.create(Godot::PanelContainer)
      if bar_container
        bar_container.call("set_anchors_preset", 7) # PRESET_BOTTOM_WIDE
        bar_container.call("set_custom_minimum_size", Vector2.new(0_f32, 42_f32))

        hbox = Godot.create(Godot::HBoxContainer)
        if hbox
          hbox.call("add_theme_constant_override", "separation", 10)

          # Toggle Checkbox
          toggle_btn = Godot.create(Godot::Button)
          if toggle_btn
            toggle_btn.call("set_text", "⇄ Split Wipe")
            toggle_btn.call("set_toggle_mode", true)
            toggle_btn.call("set_pressed", @is_active)
            toggle_btn.connect("toggled") do |args|
              active = args.first?.try(&.as_bool) || false
              set_active(active)
            end
            hbox.call("add_child", toggle_btn)
          end

          # Left Label: Original
          lbl_orig = Godot.create(Godot::Label)
          if lbl_orig
            lbl_orig.call("set_text", "◀ Original")
            lbl_orig.call("add_theme_color_override", "font_color", Color.new(0.7_f32, 0.7_f32, 0.7_f32, 1.0_f32))
            hbox.call("add_child", lbl_orig)
            @label_left = lbl_orig
          end

          # Split Slider
          slider = Godot.create(Godot::HSlider)
          if slider
            slider.call("set_h_size_flags", 3)
            slider.call("set_min", 0.0)
            slider.call("set_max", 1.0)
            slider.call("set_step", 0.01)
            slider.call("set_value", @split_ratio.to_f64)
            slider.connect("value_changed") do |args|
              val = args.first?.try(&.as_f) || 0.5_f64
              set_ratio(val.to_f32)
            end
            hbox.call("add_child", slider)
            @slider = slider
          end

          # Right Label: Shaded
          lbl_shad = Godot.create(Godot::Label)
          if lbl_shad
            lbl_shad.call("set_text", "Shaded ▶")
            lbl_shad.call("add_theme_color_override", "font_color", Color.new(0.4_f32, 0.9_f32, 1.0_f32, 1.0_f32))
            hbox.call("add_child", lbl_shad)
            @label_right = lbl_shad
          end

          # Quick 50% Reset Button
          center_btn = Godot.create(Godot::Button)
          if center_btn
            center_btn.call("set_text", "50/50")
            center_btn.call("set_tooltip_text", "Center split at 50%")
            center_btn.connect("pressed") do |_args|
              set_ratio(0.5_f32)
            end
            hbox.call("add_child", center_btn)
          end

          bar_container.call("add_child", hbox)
        end
        call("add_child", bar_container)
      end

      # Vertical Divider Line
      divider = Godot.create(Godot::ColorRect)
      if divider
        divider.call("set_color", Color.new(0.35_f32, 0.75_f32, 1.0_f32, 0.85_f32))
        divider.call("set_custom_minimum_size", Vector2.new(2_f32, 0_f32))
        divider.call("set_anchors_preset", 9) # PRESET_LEFT_WIDE
        divider.call("set_visible", @is_active)
        call("add_child", divider)
        @divider_line = divider
      end

      update_divider_position
    end

    def set_active(active : Bool) : Void
      @is_active = active
      @divider_line.try &.call("set_visible", active)
      @on_split_changed.try &.call(active ? @split_ratio : 1.0_f32)
    end

    def set_ratio(ratio : Float32) : Void
      @split_ratio = Math.max(0_f32, Math.min(1_f32, ratio))
      @slider.try &.call("set_value", @split_ratio.to_f64)
      update_divider_position
      if @is_active
        @on_split_changed.try &.call(@split_ratio)
      end
    end

    def update_divider_position : Void
      divider = @divider_line
      return unless divider

      # Position divider line at ratio * viewport_width
      viewport_size = get_viewport_rect.size
      x_pos = viewport_size.x * @split_ratio
      divider.call("set_position", Vector2.new(x_pos - 1_f32, 0_f32))
      divider.call("set_size", Vector2.new(2_f32, viewport_size.y))
    end
  end
end
