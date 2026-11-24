require "./spec_helper"
require "../src/crshader"

describe CrShader::Templates do
  it "provides templates across all 7 shader modes" do
    CrShader::Templates.modes.size.should eq(7)
    CrShader::Templates.all.size.should be >= 30

    CrShader::Templates.modes.each do |mode|
      entries = CrShader::Templates.for_mode(mode)
      entries.should_not be_empty
      entries.first.name.should start_with("Default")
      entries.any? { |e| e.name == "Empty" }.should be_true
    end
  end

  it "compiles every single built-in template cleanly with zero errors" do
    compiler = CrShader::Compiler.new
    CrShader::Templates.all.each do |entry|
      rendered = entry.render("res://shaders/sample_effect.crshader")
      rendered.should_not contain("{{STEM}}")
      rendered.lines.first.should_not start_with(" ")

      outputs = compiler.compile_emit_targets(
        rendered,
        filename: "/tmp/crshader_template_spec/sample_effect.crshader",
        write_disk: false
      )
      outputs.should_not be_empty
      outputs.each do |_out_path, target, code|
        code.strip.should_not be_empty
        case entry.mode
        when CrShader::Templates::Mode::Compute
          target.should eq(CrShader::ShaderTarget::GLSL)
          code.should contain("#version 450")
        when CrShader::Templates::Mode::ShaderInclude
          target.should eq(CrShader::ShaderTarget::GDShaderInc)
          code.should contain("#ifndef")
          code.should contain("SAMPLE_EFFECT")
        else
          target.should eq(CrShader::ShaderTarget::GDShader)
          code.should contain("shader_type ")
        end
      end
    end
  end

  it "resolves templates by id, name, mode slug, and CLI aliases" do
    CrShader::Templates.find("spatial_toon").not_nil!.mode.should eq(CrShader::Templates::Mode::Spatial)
    CrShader::Templates.find("canvas_ui_sdf_card").not_nil!.mode.should eq(CrShader::Templates::Mode::CanvasItem)
    CrShader::Templates.find("particles_vortex_swarm").not_nil!.mode.should eq(CrShader::Templates::Mode::Particles)
    CrShader::Templates.find("sky_sunset_stars").not_nil!.mode.should eq(CrShader::Templates::Mode::Sky)
    CrShader::Templates.find("fog_rolling_mist").not_nil!.mode.should eq(CrShader::Templates::Mode::Fog)
    CrShader::Templates.find("compute_compositor_depth_outline").not_nil!.mode.should eq(CrShader::Templates::Mode::Compute)
    CrShader::Templates.find("include_oop_struct").not_nil!.mode.should eq(CrShader::Templates::Mode::ShaderInclude)
    CrShader::Templates.find("canvas").not_nil!.id.should eq("canvas_default")
  end

  it "scaffolds new .crshader files from templates via CLI `crshader new`" do
    tmp_dir = File.join(Dir.tempdir, "crshader_cli_new_#{Process.pid}_#{Random.rand(100000)}")
    Dir.mkdir_p(tmp_dir)
    begin
      out_file = File.join(tmp_dir, "hero_shield.crshader")
      CrShader::CLI.run(["new", out_file, "-t", "spatial_hologram_shield"])
      File.exists?(out_file).should be_true
      generated = File.read(out_file)
      generated.should contain("shader_type :spatial")
      generated.should contain("emission_pulse")

      compiled = CrShader::Compiler.new.compile_source(generated, filename: out_file)
      compiled.should contain("shader_type spatial;")
    ensure
      FileUtils.rm_rf(tmp_dir)
    end
  end
end
