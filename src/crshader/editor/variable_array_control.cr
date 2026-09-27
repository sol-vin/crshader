require "lapis"
require "../parser/tres_reader"

module CrShader
  include Godot

  # =============================================================================
  # VariableArrayControl - Custom Inspector Control for Variable-Size Shader Arrays
  # =============================================================================
  # Provides an interactive in-inspector widget for editing uniform arrays
  # (especially Color arrays/palettes) with ColorPickerButton swatches, dynamic
  # resize [+]/[-], preset selection across 30+ default palettes, and live material sync.
  @[Tool]
  node VariableArrayControl < PanelContainer do
    property param_name : String = "palette"
    property active_material : Godot::ShaderMaterial? = nil
    property colors : Array(Godot::Color) = [] of Godot::Color

    @title_label : Godot::Label? = nil
    @swatches_container : Godot::HFlowContainer? = nil
    @preset_option : Godot::OptionButton? = nil

    # Preset catalog of all 33 bundled palettes
    PRESET_NAMES = [
      "1-up", "archivist", "blekohpop31", "blocky-realm", "chis-a",
      "cloud-9", "comike-computer", "cottonville", "dairy-treat", "delphinium-17",
      "dirty-laundry", "extra-24", "fogfire", "fowl20", "gd-15",
      "hyperplink2", "no-failed", "ochre-ruin", "pastel-16-cnh", "pen-x-pen-plus",
      "pixel-8", "reddy-for-marshmallows", "rgr-blueprint4", "screen-burn-monitor",
      "silkpukian-24", "soggy-sepia-crt-20", "someday-ill-get-it", "summer",
      "tachycardia", "tiny-c64", "vanitas", "vignette", "vinculum"
    ]

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def configure(param_name : String, material : Godot::ShaderMaterial?, initial_colors : Array(Godot::Color)? = nil) : Void
      @param_name = param_name
      @active_material = material
      if initial_colors && !initial_colors.empty?
        @colors = initial_colors.dup
      else
        @colors = [
          Godot::Color.new(0.05_f32, 0.05_f32, 0.05_f32, 1.0_f32),
          Godot::Color.new(0.30_f32, 0.30_f32, 0.30_f32, 1.0_f32),
          Godot::Color.new(0.65_f32, 0.65_f32, 0.65_f32, 1.0_f32),
          Godot::Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32)
        ]
      end

      setup_ui
      sync_to_material
    end

    def setup_ui : Void
      # Clear existing children
      get_children.each do |c|
        call("remove_child", c)
        c.call("queue_free")
      end

      margin = Godot.create(Godot::MarginContainer)
      return unless margin
      margin.call("add_theme_constant_override", "margin_left", 6)
      margin.call("add_theme_constant_override", "margin_top", 4)
      margin.call("add_theme_constant_override", "margin_right", 6)
      margin.call("add_theme_constant_override", "margin_bottom", 4)
      call("add_child", margin)

      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("add_theme_constant_override", "separation", 6)
      margin.call("add_child", vbox)

      # --- Header Toolbar ---
      header = Godot.create(Godot::HBoxContainer)
      if header
        header.call("add_theme_constant_override", "separation", 6)

        title = Godot.create(Godot::Label)
        if title
          title.call("set_text", "🎨 #{@param_name.capitalize} (#{@colors.size}):")
          title.call("add_theme_font_size_override", "font_size", 12)
          title.call("add_theme_color_override", "font_color", Godot::Color.new(0.9_f32, 0.95_f32, 0.7_f32, 1.0_f32))
          header.call("add_child", title)
          @title_label = title
        end

        # Preset OptionButton
        presets = Godot.create(Godot::OptionButton)
        if presets
          presets.call("set_h_size_flags", 3) # SIZE_EXPAND_FILL
          presets.call("add_item", "Load Palette...", 0)
          PRESET_NAMES.each_with_index do |pname, idx|
            presets.call("add_item", pname.capitalize, idx + 1)
          end
          presets.connect("item_selected") do |args|
            selected_idx = args.first?.try(&.as_i) || 0
            if selected_idx > 0 && selected_idx <= PRESET_NAMES.size
              load_preset(PRESET_NAMES[selected_idx - 1])
            end
          end
          header.call("add_child", presets)
          @preset_option = presets
        end

        # [+] Add Color Button
        add_btn = Godot.create(Godot::Button)
        if add_btn
          add_btn.call("set_text", "+")
          add_btn.call("set_tooltip_text", "Add color swatch")
          add_btn.connect("pressed") do |_args|
            add_color
          end
          header.call("add_child", add_btn)
        end

        # [-] Remove Color Button
        pop_btn = Godot.create(Godot::Button)
        if pop_btn
          pop_btn.call("set_text", "-")
          pop_btn.call("set_tooltip_text", "Remove last color swatch")
          pop_btn.connect("pressed") do |_args|
            pop_color
          end
          header.call("add_child", pop_btn)
        end

        vbox.call("add_child", header)
      end

      # --- Swatches Flow Container ---
      flow = Godot.create(Godot::HFlowContainer)
      if flow
        flow.call("add_theme_constant_override", "h_separation", 4)
        flow.call("add_theme_constant_override", "v_separation", 4)
        vbox.call("add_child", flow)
        @swatches_container = flow
        rebuild_swatches
      end
    end

    def rebuild_swatches : Void
      flow = @swatches_container
      return unless flow

      flow.get_children.each do |c|
        flow.call("remove_child", c)
        c.call("queue_free")
      end

      @colors.each_with_index do |col, idx|
        btn = Godot.create(Godot::ColorPickerButton)
        next unless btn
        btn.call("set_custom_minimum_size", Vector2.new(28.0_f32, 24.0_f32))
        btn.call("set_pick_color", col)
        btn.call("set_edit_alpha", true)
        btn.call("set_tooltip_text", "Color [#{idx}]: ##{col.to_html(false)}")

        btn.connect("color_changed") do |args|
          new_color = args.first?.try(&.as_color)
          if new_color
            @colors[idx] = new_color
            btn.call("set_tooltip_text", "Color [#{idx}]: ##{new_color.to_html(false)}")
            sync_to_material
          end
        end

        flow.call("add_child", btn)
      end

      if lbl = @title_label
        lbl.call("set_text", "🎨 #{@param_name.capitalize} (#{@colors.size}):")
      end
    end

    def add_color : Void
      last_col = @colors.last? || Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      @colors << last_col
      rebuild_swatches
      sync_to_material
    end

    def pop_color : Void
      return if @colors.size <= 1
      @colors.pop
      rebuild_swatches
      sync_to_material
    end

    def load_preset(preset_name : String) : Void
      path = "res://default_palettes/#{preset_name}.tres"
      data = TresReader.read(path)
      return unless data && !data.colors.empty?

      @colors = data.colors.map do |r, g, b, a|
        Godot::Color.new(r, g, b, a)
      end

      rebuild_swatches
      sync_to_material
      Godot.print("[VariableArrayControl] Loaded palette '#{preset_name}' (#{@colors.size} colors) for uniform '#{@param_name}'")
    end

    def sync_to_material : Void
      mat = @active_material
      return unless mat && !mat.pointer.null?

      packed = Godot::PackedColorArray.new(@colors)
      mat.call("set_shader_parameter", @param_name, packed)
    end
  end
end
