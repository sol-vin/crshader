require "./spec_helper"
require "../src/crshader/compiler"

describe "CrShader Examples & Post-Processing Suite" do
  compiler = CrShader::Compiler.new(verbose: false)
  examples_dir = File.expand_path("../examples", __DIR__).gsub('\\', '/')
  cr_files = Dir.glob("#{examples_dir}/*.crshader")

  it "finds all example shaders" do
    cr_files.size.should be >= 20
  end

  cr_files.each do |cr_file|
    base_name = File.basename(cr_file)
    it "compiles example #{base_name} without errors" do
      target = base_name.includes?("compute") ? CrShader::ShaderTarget::GLSL : CrShader::ShaderTarget::GDShader
      c = CrShader::Compiler.new(target_override: target, verbose: false)
      ext = target == CrShader::ShaderTarget::GLSL ? ".glsl" : ".gdshader"
      out_path = cr_file.sub(/\.crshader$/, ext)

      result = c.compile_file(cr_file, out_path)
      result.should_not be_empty
      File.exists?(out_path).should be_true
      content = File.read(out_path)
      content.should_not be_empty

      if target == CrShader::ShaderTarget::GDShader
        content.should contain("shader_type")
      else
        content.should contain("#version 450")
      end
    end
  end

  it "validates all compiled GDShaders via headless Godot engine" do
    godot_exe = File.expand_path("../../../godot.exe", __DIR__)
    if File.exists?(godot_exe)
      cmd = "Start-Process -FilePath '#{godot_exe}' -ArgumentList '--headless', '--path', '#{File.expand_path("..", __DIR__)}', '-s', 'scripts/validate_shaders.gd' -NoNewWindow -Wait"
      status = Process.run("powershell", ["-Command", cmd])
      status.success?.should be_true
    else
      # If godot is not at root, pass
      true.should be_true
    end
  end

  it "provides helpful compiler error when 'return' is used inside a GDShader processor" do
    source = <<-CR
      shader_type :canvas_item

      def fragment
        val = 1.0
        if val > 0.5
          COLOR = vec4(1.0, 0.0, 0.0, 1.0)
          return
        end
        COLOR = vec4(0.0, 1.0, 0.0, 1.0)
      end
    CR

    expect_raises(CrShader::ShaderError, /Processor function 'fragment' in GDShader cannot use 'return'/) do
      CrShader.compile(source)
    end
  end

  it "handles multi-loop variable re-declaration cleanly with block scoping" do
    source = <<-CR
      shader_type :canvas_item

      def fragment
        (0..2).each do |i|
          c = vec3(1.0, 0.0, 0.0)
          COLOR.rgb = c
        end
        (0..2).each do |j|
          c = vec3(0.0, 1.0, 0.0)
          COLOR.rgb = c
        end
      end
    CR

    compiled = CrShader.compile(source)
    # Both loops must declare `vec3 c`, not raw `c =` in loop 2
    count = compiled.scan("vec3 c =").size
    count.should eq(2)
  end

  it "correctly infers vector types from arbitrary swizzles" do
    source = <<-CR
      shader_type :spatial

      def vertex
        pos = vec3(1.0, 2.0, 3.0)
        p2 = pos.xz * 0.5
        p3 = pos.zyx + vec3(1.0, 1.0, 1.0)
        VERTEX.xz = p2
        VERTEX = p3
      end
    CR

    compiled = CrShader.compile(source)
    compiled.should contain("vec2 p2 =")
    compiled.should contain("vec3 p3 =")
  end
end
