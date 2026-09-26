require "./spec_helper"

describe "CrShader Advanced Features" do
  it "transpiles runtime iteration loops to C-style for loops" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        sum = 0.0
        (0...10).each do |i|
          sum = sum + float(i)
        end
        5.times do |j|
          sum = sum + 1.0
        end
        (0..4).each do |k|
          sum = sum + 2.0
        end
        ALBEDO = vec3(sum, sum, sum)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("for (int i = 0; i < 10; i++) {")
    output.should contain("for (int j = 0; j < 5; j++) {")
    output.should contain("for (int k = 0; k <= 4; k++) {")
  end

  it "transpiles ternary and expression if" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        val = 0.5
        col = (val > 0.2) ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)
        ALBEDO = col
      end
    CR

    output = CrShader.compile(source)
    output.should contain("vec3 col = ")
    output.should contain("? (vec3(1.0, 0.0, 0.0)) : (vec3(0.0, 1.0, 0.0))")
  end

  it "transpiles case / when to switch / case" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        mode = 1
        val = 0.0
        case mode
        when 0
          val = 1.0
        when 1
          val = 2.0
        else
          val = 3.0
        end
        ALBEDO = vec3(val, val, val)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("switch (mode) {")
    output.should contain("case 0:")
    output.should contain("case 1:")
    output.should contain("default:")
  end

  it "transpiles object-oriented texture methods" do
    source = <<-CR
      shader_type :spatial

      uniform tex : Sampler2D

      def fragment()
        col = tex.sample(UV)
        lod_col = tex.sample_lod(UV, 2.0)
        s = tex.size
        ALBEDO = col.rgb
      end
    CR

    output = CrShader.compile(source)
    output.should contain("texture(tex, UV)")
    output.should contain("textureLod(tex, UV, 2.0)")
    output.should contain("textureSize(tex, 0)")
  end

  it "supports InOut and Out parameter types" do
    source = <<-CR
      shader_type :spatial

      def modify_tangents(n : InOut(Vec3), t : Out(Vec3))
        n = normalize(n)
        t = vec3(1.0, 0.0, 0.0)
      end

      def fragment()
        n = NORMAL
        t = vec3(0.0, 0.0, 0.0)
        modify_tangents(n, t)
        ALBEDO = n
      end
    CR

    output = CrShader.compile(source)
    output.should contain("void modify_tangents(inout vec3 n, out vec3 t) {")
  end

  it "supports instance and global uniforms with array sizes" do
    source = <<-CR
      shader_type :spatial

      instance_uniform highlight : Bool = false
      global_uniform wind_vector : Vec3 = Vec3.new(1.0, 0.0, 0.0)
      uniform palette : Array(Vec4, 8)

      def fragment()
        if highlight
          ALBEDO = palette[0].rgb
        else
          ALBEDO = wind_vector
        end
      end
    CR

    output = CrShader.compile(source)
    output.should contain("instance uniform bool highlight = false;")
    output.should contain("global uniform vec3 wind_vector = vec3(1.0, 0.0, 0.0);")
    output.should contain("uniform vec4 palette[8];")
  end

  it "supports particle shader stages start and process" do
    source = <<-CR
      shader_type :particles

      def start()
        VELOCITY = vec3(0.0, 1.0, 0.0)
      end

      def process()
        VELOCITY.y += DELTA * -9.8
      end
    CR

    output = CrShader.compile(source)
    output.should contain("shader_type particles;")
    output.should contain("void start() {")
    output.should contain("void process() {")
  end

  it "supports block-style shader and stage DSL" do
    source = <<-CR
      shader :spatial do
        render_mode :cull_disabled

        uniform speed : Float32 = 2.0

        vertex do
          VERTEX.y += sin(TIME * speed)
        end

        fragment do
          ALBEDO = vec3(0.8, 0.2, 0.3)
        end
      end
    CR

    output = CrShader.compile(source)
    output.should contain("shader_type spatial;")
    output.should contain("render_mode cull_disabled;")
    output.should contain("uniform float speed = 2.0;")
    output.should contain("void vertex() {")
    output.should contain("void fragment() {")
  end

  it "supports compute shared memory and image declarations" do
    source = <<-CR
      shader_type :compute
      local_size 64, 1, 1

      shared cache : Array(UInt32, 256)
      image2d output_img, format: :rgba32f, set: 0, binding: 1

      def main()
        cache[gl_LocalInvocationIndex] = gl_GlobalInvocationID.x
        barrier()
      end
    CR

    output = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    output.should contain("shared uint cache[256];")
    output.should contain("layout(rgba32f, set = 0, binding = 1) uniform image2D output_img;")
    output.should contain("barrier();")
  end

  it "supports variable-sized constant arrays dynamically sized at compile time" do
    source = <<-CR
      shader_type :canvas_item

      uniform my_var_array = []
      uniform my_palette = [vec4(1.0, 0.0, 0.0, 1.0), vec4(0.0, 1.0, 0.0, 1.0), vec4(0.0, 0.0, 1.0, 1.0)]

      def fragment()
        total = vec4(0.0)
        (0...my_palette.size).each do |i|
          total += my_palette[i]
        end
        COLOR = total + my_var_array[0]
      end
    CR

    output = CrShader.compile(source)
    output.should contain("const int my_var_array_size = 16;")
    output.should contain("uniform vec4 my_var_array[16];")
    output.should contain("const int my_palette_size = 3;")
    output.should contain("uniform vec4 my_palette[3];")
    output.should contain("for (int i = 0; i < my_palette.length(); i++) {")
    output.should contain("total += my_palette[i];")
  end

  it "supports variable-sized constant arrays in compute GLSL shaders" do
    source = <<-CR
      shader_type :compute
      local_size 8, 8, 1

      uniform weights = [0.25, 0.5, 0.25]

      def main()
        w = weights[0]
      end
    CR

    output = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    output.should contain("const int weights_size = 3;")
    output.should contain("layout(set = 1, binding = 0) uniform float weights[3];")
  end
end
