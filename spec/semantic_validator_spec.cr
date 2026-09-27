require "./spec_helper"
require "../src/crshader/compiler"

describe "CrShader Semantic Validator & Early Safety" do
  compiler = CrShader::Compiler.new

  it "catches unknown shader_type with fuzzy suggestion early" do
    source = <<-CR
      shader_type :spatials
      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Unknown shader_type ':spatials'/) do
      compiler.compile_source(source)
    end
  end

  it "catches invalid render_mode for shader_type" do
    source = <<-CR
      shader_type :canvas_item
      render_mode :cull_back

      def fragment
        COLOR = vec4(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Render mode 'cull_back' is not valid for 'canvas_item' shaders/) do
      compiler.compile_source(source)
    end
  end

  it "catches typo in render_mode with suggestion" do
    source = <<-CR
      shader_type :spatial
      render_mode :unshdaded

      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Unknown render mode 'unshdaded' for 'spatial' shader/) do
      compiler.compile_source(source)
    end
  end

  it "catches stage incompatible with shader_type" do
    source = <<-CR
      shader_type :spatial

      def sky
        COLOR = vec3(0.5)
      end
    CR

    expect_raises(CrShader::ShaderError, /Stage 'sky' cannot be used in a 'spatial' shader/) do
      compiler.compile_source(source)
    end
  end

  it "catches assigning to built-in in the wrong stage" do
    source = <<-CR
      shader_type :spatial

      def vertex
        ALBEDO = vec3(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Cannot assign to built-in 'ALBEDO' in vertex stage/) do
      compiler.compile_source(source)
    end
  end

  it "catches hint 'source_color' on non-Color/Vec4 uniforms" do
    source = <<-CR
      shader_type :spatial
      uniform speed : Float32 = 1.0, hint: :source_color

      def fragment
        ALBEDO = vec3(speed)
      end
    CR

    expect_raises(CrShader::ShaderError, /Hint 'source_color' is only valid for Color or Vec4 uniforms/) do
      compiler.compile_source(source)
    end
  end

  it "catches hint_range where min >= max" do
    source = <<-CR
      shader_type :spatial
      uniform cutoff : Float32 = 0.5, hint: hint_range(10.0, 1.0)

      def fragment
        ALBEDO = vec3(cutoff)
      end
    CR

    expect_raises(CrShader::ShaderError, /hint_range minimum \(10.0\) must be strictly less than maximum \(1.0\)/) do
      compiler.compile_source(source)
    end
  end

  it "catches hint_range with invalid negative or zero step" do
    source = <<-CR
      shader_type :spatial
      uniform cutoff : Float32 = 0.5, hint: hint_range(0.0, 1.0, 0.0)

      def fragment
        ALBEDO = vec3(cutoff)
      end
    CR

    expect_raises(CrShader::ShaderError, /hint_range step \(0.0\) must be greater than zero/) do
      compiler.compile_source(source)
    end
  end

  it "catches sampler uniforms declared as instance_uniform" do
    source = <<-CR
      shader_type :spatial
      instance_uniform my_tex : Sampler2D

      def fragment
        ALBEDO = vec3(1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Instance uniforms cannot be texture samplers/) do
      compiler.compile_source(source)
    end
  end

  it "catches compute shader with zero or negative local_size" do
    source = <<-CR
      shader_type :compute
      local_size 0, 8, 1

      def main
      end
    CR

    expect_raises(CrShader::ShaderError, /Compute local_size dimensions must all be greater than zero/) do
      compiler.compile_source(source)
    end
  end
end
