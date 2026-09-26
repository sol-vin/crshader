require "./spec_helper"

describe CrShader::MacroEngine do
  it "unrolls loops using macro with {% for %}" do
    source = <<-CR
      macro unroll_adds(count)
        {% for i in 0...count %}
          total = total + {{i}}
        {% end %}
      end

      def vertex()
        total = 0
        unroll_adds(3)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("total = (total + 0)")
    output.should contain("total = (total + 1)")
    output.should contain("total = (total + 2)")
  end

  it "evaluates {% if %} in macros" do
    source = <<-CR
      macro apply_mode(use_custom)
        {% if use_custom %}
          col = vec3(1.0, 0.0, 0.0)
        {% else %}
          col = vec3(0.0, 1.0, 0.0)
        {% end %}
      end

      def fragment()
        apply_mode(true)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("vec3(1.0, 0.0, 0.0)")
    output.should_not contain("vec3(0.0, 1.0, 0.0)")
  end

  it "unrolls a multi-tap sampling kernel for blur" do
    source = <<-CR
      shader_type :canvas_item

      macro gaussian_tap_5(tex, uv, step, out_var)
        {{out_var}} = vec4(0.0)
        {% for offset in [-2, -1, 0, 1, 2] %}
          {{out_var}} += texture({{tex}}, {{uv}} + vec2(float({{offset}}), 0.0) * {{step}}) * 0.2
        {% end %}
      end

      def fragment()
        col = vec4(0.0)
        gaussian_tap_5(TEXTURE, UV, 0.01, col)
        COLOR = col
      end
    CR

    output = CrShader.compile(source)
    output.should contain("texture(TEXTURE, (UV + (vec2(float(-2), 0.0) * 0.01)))")
    output.should contain("texture(TEXTURE, (UV + (vec2(float(0), 0.0) * 0.01)))")
    output.should contain("texture(TEXTURE, (UV + (vec2(float(2), 0.0) * 0.01)))")
  end

  it "generates uniform declarations from a top-level macro" do
    source = <<-CR
      shader_type :spatial

      macro create_light_uniforms(count)
        {% for i in 1..count %}
          uniform light_{{i}}_intensity : Float32 = 1.0
        {% end %}
      end

      create_light_uniforms(3)

      def fragment()
        total = light_1_intensity + light_2_intensity + light_3_intensity
        ALBEDO = vec3(total)
      end
    CR

    output = CrShader.compile(source)
    output.should contain("uniform float light_1_intensity = 1.0;")
    output.should contain("uniform float light_2_intensity = 1.0;")
    output.should contain("uniform float light_3_intensity = 1.0;")
  end

  it "iterates over array literal in macro for" do
    source = <<-CR
      shader_type :spatial

      macro sum_octaves(freqs)
        acc = 0.0
        {% for f in freqs %}
          acc += sin(TIME * float({{f}}))
        {% end %}
      end

      def vertex()
        sum_octaves([1, 2, 4, 8])
        VERTEX.y += acc
      end
    CR

    output = CrShader.compile(source)
    output.should contain("acc += sin((TIME * float(1)))")
    output.should contain("acc += sin((TIME * float(2)))")
    output.should contain("acc += sin((TIME * float(4)))")
    output.should contain("acc += sin((TIME * float(8)))")
  end

  it "handles macros with default arguments" do
    source = <<-CR
      shader_type :canvas_item

      macro scale_color(col, factor = 2.0)
        {{col}} * {{factor}}
      end

      def fragment()
        c1 = scale_color(COLOR)
        c2 = scale_color(COLOR, 0.5)
        COLOR = c1 + c2
      end
    CR

    output = CrShader.compile(source)
    output.should contain("(COLOR * 2.0)")
    output.should contain("(COLOR * 0.5)")
  end
end
