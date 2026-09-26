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
end
