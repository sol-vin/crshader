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
      is_glsl = base_name.includes?("compute") || base_name.starts_with?("compositor_")
      target = is_glsl ? CrShader::ShaderTarget::GLSL : CrShader::ShaderTarget::GDShader
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

      # Keep examples/shader_viewer/shaders synced when a matching shader exists
      viewer_cr = File.join(examples_dir, "shader_viewer/shaders", base_name)
      if File.exists?(viewer_cr)
        viewer_out = viewer_cr.sub(/\.crshader$/, ext)
        c.compile_file(viewer_cr, viewer_out)
      end
    end
  end

  it "validates all compiled GDShaders and GLSL SPIR-V shaders via headless Godot engine" do
    repo_root = File.expand_path("..", __DIR__)
    candidates = [
      File.expand_path("../godot.exe", __DIR__),
      File.expand_path("../../godot.exe", __DIR__),
      File.expand_path("../../../godot.exe", __DIR__),
    ]
    godot_exe = candidates.find { |p| File.exists?(p) }
    if godot_exe
      log_path = File.join(repo_root, "validation_log.txt")
      File.delete(log_path) if File.exists?(log_path)

      err_io = IO::Memory.new
      status = Process.run(
        godot_exe,
        ["--no-window", "--audio-driver", "Dummy", "--path", repo_root, "-s", "scripts/validate_shaders.gd"],
        output: Process::Redirect::Close,
        error: err_io
      )
      if !status.success? && !File.exists?(log_path)
        err_io.clear
        status = Process.run(
          godot_exe,
          ["--headless", "--path", repo_root, "-s", "scripts/validate_shaders.gd"],
          output: Process::Redirect::Close,
          error: err_io
        )
      end

      log_text = File.exists?(log_path) ? File.read(log_path) : ""
      err_text = err_io.to_s
      File.delete(log_path) if File.exists?(log_path)
      status.success?.should be_true, "Godot shader validation failed:\n#{log_text}\n#{err_text}"
      err_text.includes?("SHADER ERROR:").should be_false, "Godot reported SHADER ERROR on STDERR:\n#{err_text}"
    else
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
