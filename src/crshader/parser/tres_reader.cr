require "compiler/crystal/syntax"

module CrShader
  # Holds parsed data extracted from a Godot 4 ColorPalette resource (.tres)
  # Reference: https://docs.godotengine.org/en/stable/classes/class_colorpalette.html
  class TresData
    property resource_type : String
    property colors : Array(Tuple(Float32, Float32, Float32, Float32))

    def initialize(
      @resource_type : String = "ColorPalette",
      @colors : Array(Tuple(Float32, Float32, Float32, Float32)) = [] of Tuple(Float32, Float32, Float32, Float32)
    )
    end

    def size : Int32
      @colors.size
    end

    def elem_type : String
      "Color"
    end

    # Converts parsed colors into Crystal AST nodes for default array embedding
    def to_ast_nodes : Array(Crystal::ASTNode)
      @colors.map do |r, g, b, a|
        Crystal::Call.new(
          Crystal::Path.new("Color"),
          "new",
          [
            Crystal::NumberLiteral.new(r.to_s, :f32),
            Crystal::NumberLiteral.new(g.to_s, :f32),
            Crystal::NumberLiteral.new(b.to_s, :f32),
            Crystal::NumberLiteral.new(a.to_s, :f32)
          ] of Crystal::ASTNode
        ).as(Crystal::ASTNode)
      end
    end
  end

  # Reader and Serializer for Godot 4 ColorPalette .tres resources
  # Operates directly on ColorPalette schemas containing PackedColorArray.
  class TresReader
    COLOR_REGEX = /Color\(\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)\s*,\s*([-\d.eE]+)(?:\s*,\s*([-\d.eE]+))?\s*\)/

    # Resolves a Godot res:// or relative path to an existing filesystem path
    def self.resolve_path(path : String, base_dir : String? = nil) : String?
      clean = path.sub(%r{^res://}, "").gsub('\\', '/')

      candidates = [] of String
      candidates << File.expand_path(clean, base_dir) if base_dir
      candidates << clean
      candidates << File.expand_path(clean)
      candidates << File.join("default_palettes", File.basename(clean))
      candidates << File.join("addons", "crshader", "default_palettes", File.basename(clean))
      candidates << File.join("examples", "shader_viewer", "default_palettes", File.basename(clean))
      candidates << File.join("examples", "shader_sandbox", "default_palettes", File.basename(clean))

      candidates.find { |c| File.exists?(c) }
    end

    # Reads ColorPalette .tres resource
    def self.read(path : String, base_dir : String? = nil) : TresData?
      resolved = resolve_path(path, base_dir)
      return nil unless resolved && File.exists?(resolved)

      content = File.read(resolved)
      parse_string(content)
    end

    # Parses Godot 4 ColorPalette text resource (.tres)
    # Extracts the PackedColorArray with type safety
    def self.parse_string(content : String) : TresData
      data = TresData.new
      target_slice = ""
      if m = content.match(/(?:^|\n)\s*colors\s*=\s*([^\n]+)/)
        target_slice = m[1]
      elsif content.includes?("Color(")
        target_slice = content
      end

      if !target_slice.empty?
        target_slice.scan(COLOR_REGEX) do |cm|
          r = cm[1].to_f32? || 0.0_f32
          g = cm[2].to_f32? || 0.0_f32
          b = cm[3].to_f32? || 0.0_f32
          a = cm[4]?.try(&.to_f32?) || 1.0_f32
          data.colors << {r, g, b, a}
        end
      end
      data
    end

    # Writes a Godot 4 ColorPalette .tres resource
    def self.write_color_palette(path : String, colors : Array(Tuple(Float32, Float32, Float32, Float32))) : Bool
      dir = File.dirname(path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir) || dir.empty? || dir == "."

      io = IO::Memory.new
      io << "[gd_resource type=\"ColorPalette\" format=3]\n\n"
      io << "[resource]\n"
      io << "colors = PackedColorArray("
      colors.each_with_index do |(r, g, b, a), idx|
        io << ", " if idx > 0
        io << "Color(#{r.round(6)}, #{g.round(6)}, #{b.round(6)}, #{a.round(6)})"
      end
      io << ")\n"

      File.write(path, io.to_s)
      true
    rescue
      false
    end
  end
end
