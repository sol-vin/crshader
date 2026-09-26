require "./spec_helper"

describe "GDShader Generation" do
  it "transpiles the user prompt example code" do
    source = <<-CR
      shader_type :spatial

      def vertex()
        color = Color.new(0.1, 0.1, 0.1)
        position = Vec3.new(rand(), rand(), rand())
      end
    CR

    output = CrShader.compile(source)
    output.should contain("shader_type spatial;")
    output.should contain("void vertex() {")
    output.should contain("vec4 color = vec4(0.1, 0.1, 0.1, 1.0);")
    output.should contain("vec3 position = vec3(rand(), rand(), rand());")
  end

  it "handles helper constructors like color() and vec3()" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        c = color(0.5, 0.5, 0.5)
        p = vec3(1.0, 2.0, 3.0)
        ALBEDO = c.rgb
      end
    CR

    output = CrShader.compile(source)
    output.should contain("vec4 c = vec4(0.5, 0.5, 0.5, 1.0);")
    output.should contain("vec3 p = vec3(1.0, 2.0, 3.0);")
    output.should contain("ALBEDO = c.rgb;")
  end

  it "maps control flow structures" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        val = 0.5
        if val > 0.3
          val = 1.0
        else
          val = 0.0
        end
        while val < 5.0
          val = val + 1.0
        end
      end
    CR

    output = CrShader.compile(source)
    output.should contain("float val = 0.5;")
    output.should contain("if ((val > 0.3)) {")
    output.should contain("val = 1.0;")
    output.should contain("} else {")
    output.should contain("val = 0.0;")
    output.should contain("while ((val < 5.0)) {")
  end

  it "maps method calls to GLSL built-ins" do
    source = <<-CR
      shader_type :spatial

      def fragment()
        v = vec3(0.1, 0.2, 0.3)
        len = v.length
        n = v.normalize
        clamped = len.clamp(0.0, 1.0)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("length(v)")
    output.should contain("normalize(v)")
    output.should contain("clamp(len, 0.0, 1.0)")
  end
end
