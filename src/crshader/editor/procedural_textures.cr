require "lapis"

module CrShader
  # =============================================================================
  # ProceduralTextures - Dynamic Procedural Texture Generator
  # =============================================================================
  # Generates vector-sharp, calibration textures dynamically at runtime
  # using Godot's SVG loader and ImageTexture pipeline. This eliminates
  # external asset dependencies while allowing instant visual preview for
  # Sampler2D uniforms in the Sandbox and Viewer.
  class ProceduralTextures
    @@cache = Hash(String, Godot::Texture2D).new

    PRESETS = [
      "Godot Icon",
      "Checkerboard",
      "UV Gradient",
      "Flat Normal (0,0,1)",
      "Color Bars",
      "Concentric Target"
    ]

    def self.presets : Array(String)
      PRESETS
    end

    def self.get(name : String) : Godot::Texture2D?
      if cached = @@cache[name]?
        return cached
      end

      tex = create_texture(name)
      if tex
        @@cache[name] = tex
      end
      tex
    end

    def self.clear_cache : Void
      @@cache.clear
    end

    private def self.create_texture(name : String) : Godot::Texture2D?
      case name
      when "Godot Icon"
        load_icon_or_fallback
      when "Checkerboard"
        create_from_svg(svg_checkerboard)
      when "UV Gradient"
        create_from_svg(svg_uv_gradient)
      when "Flat Normal (0,0,1)"
        create_from_svg(svg_flat_normal)
      when "Color Bars"
        create_from_svg(svg_color_bars)
      when "Concentric Target"
        create_from_svg(svg_concentric_target)
      else
        create_from_svg(svg_checkerboard)
      end
    end

    private def self.load_icon_or_fallback : Godot::Texture2D?
      res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
      if res_loader && !res_loader.pointer.null?
        paths = ["res://icon.svg", "icon.svg", "res://icon.png"]
        paths.each do |p|
          begin
            res = res_loader.call_obj("load", p)
            if res && !res.pointer.null? && res.is_a?(Godot::Texture2D)
              return res
            end
          rescue
          end
        end
      end
      create_from_svg(svg_checkerboard)
    end

    def self.create_from_svg(svg : String) : Godot::Texture2D?
      img = Godot.create(Godot::Image)
      return nil unless img

      err = img.load_svg_from_string(svg)
      if err.value == 0 # OK
        return Godot::ImageTexture.create_from_image(img)
      end
      nil
    rescue
      nil
    end

    # SVG Generator Helpers

    def self.svg_checkerboard(tiles : Int32 = 8, size : Int32 = 256) : String
      step = size // tiles
      String.build do |io|
        io << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{size}\" height=\"#{size}\">\n"
        io << "  <rect width=\"100%\" height=\"100%\" fill=\"#1e1e24\"/>\n"
        tiles.times do |y|
          tiles.times do |x|
            if (x + y).even?
              io << "  <rect x=\"#{x * step}\" y=\"#{y * step}\" width=\"#{step}\" height=\"#{step}\" fill=\"#e0e0e0\"/>\n"
            end
          end
        end
        io << "</svg>"
      end
    end

    def self.svg_uv_gradient(size : Int32 = 256) : String
      <<-SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}">
        <defs>
          <linearGradient id="gx" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#000000" stop-opacity="1"/>
            <stop offset="100%" stop-color="#ff0000" stop-opacity="1"/>
          </linearGradient>
          <linearGradient id="gy" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#000000" stop-opacity="0"/>
            <stop offset="100%" stop-color="#00ff00" stop-opacity="1"/>
          </linearGradient>
        </defs>
        <rect width="100%" height="100%" fill="url(#gx)"/>
        <rect width="100%" height="100%" fill="url(#gy)" style="mix-blend-mode: screen;"/>
      </svg>
      SVG
    end

    def self.svg_flat_normal(size : Int32 = 256) : String
      # Tangent-space neutral normal: (0, 0, 1) -> RGB (128, 128, 255) = #8080ff
      <<-SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}">
        <rect width="100%" height="100%" fill="#8080ff"/>
      </svg>
      SVG
    end

    def self.svg_color_bars(size : Int32 = 256) : String
      colors = ["#ffffff", "#ffff00", "#00ffff", "#00ff00", "#ff00ff", "#ff0000", "#0000ff"]
      w = size / colors.size
      String.build do |io|
        io << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{size}\" height=\"#{size}\">\n"
        colors.each_with_index do |col, idx|
          x = (idx * w).round.to_i
          width = (w + 1).round.to_i
          io << "  <rect x=\"#{x}\" y=\"0\" width=\"#{width}\" height=\"#{size}\" fill=\"#{col}\"/>\n"
        end
        io << "</svg>"
      end
    end

    def self.svg_concentric_target(size : Int32 = 256) : String
      center = size / 2.0
      String.build do |io|
        io << "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{size}\" height=\"#{size}\">\n"
        io << "  <rect width=\"100%\" height=\"100%\" fill=\"#111118\"/>\n"
        radii = [110, 90, 70, 50, 30, 10]
        radii.each_with_index do |r, i|
          fill = i.even? ? "#3b82f6" : "#1e293b"
          io << "  <circle cx=\"#{center}\" cy=\"#{center}\" r=\"#{r}\" fill=\"#{fill}\" stroke=\"#93c5fd\" stroke-width=\"2\"/>\n"
        end
        # Crosshair lines
        io << "  <line x1=\"0\" y1=\"#{center}\" x2=\"#{size}\" y2=\"#{center}\" stroke=\"#ef4444\" stroke-width=\"2\"/>\n"
        io << "  <line x1=\"#{center}\" y1=\"0\" x2=\"#{center}\" y2=\"#{size}\" stroke=\"#ef4444\" stroke-width=\"2\"/>\n"
        io << "</svg>"
      end
    end
  end
end
