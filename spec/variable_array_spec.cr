require "./spec_helper"

describe "CrShader Variable Arrays and ColorPalette .tres Embedding" do
  it "transpiles uniform with resource(...) reference to ColorPalette .tres" do
    source = <<-CR
      shader_type :canvas_item

      uniform palette = resource("res://default_palettes/cottonville.tres")

      def fragment()
        col = palette[0]
        COLOR = col
      end
    CR

    output = CrShader.compile(source)
    output.should contain("const int palette_size = 16;")
    output.should contain("uniform vec4 palette[16];")
    output.should contain("vec4 col = palette[0];")
  end

  it "transpiles uniform with PackedColorArray literal" do
    source = <<-CR
      shader_type :canvas_item

      uniform palette = PackedColorArray[
        Color.new(0.1, 0.2, 0.3, 1.0),
        Color.new(0.4, 0.5, 0.6, 1.0)
      ]

      def fragment()
        COLOR = palette[1]
      end
    CR

    output = CrShader.compile(source)
    output.should contain("const int palette_size = 2;")
    output.should contain("uniform vec4 palette[2];")
  end

  it "transpiles uniform with named resource argument" do
    source = <<-CR
      shader_type :canvas_item

      uniform target_palette : Array(Color), resource: "res://default_palettes/cottonville.tres"

      def fragment()
        total = vec4(0.0)
        (0...target_palette.size).each do |i|
          total += target_palette[i]
        end
        COLOR = total
      end
    CR

    output = CrShader.compile(source)
    output.should contain("const int target_palette_size = 16;")
    output.should contain("uniform vec4 target_palette[16];")
    output.should contain("for (int i = 0; i < target_palette.length(); i++) {")
    output.should contain("total += target_palette[i];")
  end
end
