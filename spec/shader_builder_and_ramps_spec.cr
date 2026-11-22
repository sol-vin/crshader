require "./spec_helper"

describe "Programmatic ShaderBuilder, Inline Gradients/Curves & ProceduralLUT" do
  it "builds, mutates, and forks shaders programmatically via CrShader.build" do
    base_builder = CrShader.build(:spatial) do |s|
      s.render_mode :cull_back, :diffuse_burley
      s.uniform :base_tint, :Color, default: "Color.hex(\"#3b82f6\")", hint: :source_color
      s.gradient :heat_ramp, [{0.0_f32, "#101828"}, {0.6_f32, "#f97316"}, {1.0_f32, "#fef08a"}], space: :oklab
      s.curve :falloff_curve, [{0.0_f32, 0.0_f32}, {0.5_f32, 0.8_f32}, {1.0_f32, 1.0_f32}], interp: :smooth
      s.fragment <<-CR
        t = falloff_curve(clamp(UV.y, 0.0, 1.0))
        ALBEDO = heat_ramp(t).rgb * base_tint.rgb
      CR
    end

    base_code = base_builder.compile
    base_code.should contain("vec4 heat_ramp(float t)")
    base_code.should contain("float falloff_curve(float t)")
    base_code.should contain("4.07674") # Oklab -> linear sRGB inverse matrix
    base_code.should_not contain("dissolve_amount")

    # Fork must not mutate `base_builder`
    forked = base_builder.fork do |s|
      s.add_uv_warp(10.0_f32, 0.03_f32)
      s.add_rim_glow
      s.add_dissolve
      s.add_color_tint(:extra_tint, "#fde047")
    end

    forked_code = forked.compile
    forked_code.should contain("warp_freq")
    forked_code.should contain("rim_color")
    forked_code.should contain("dissolve_amount")
    forked_code.should contain("extra_tint")

    # Re-verify original builder stayed pristine
    base_builder.compile.should_not contain("dissolve_amount")
  end

  it "supports :srgb, :linear, and :oklab gradients plus :linear, :smooth, and :step curves" do
    source = <<-CR
      shader_type :canvas_item

      gradient :step_pal, {
        0.0 => "#ff0000",
        0.5 => "#00ff00",
        1.0 => "#0000ff",
      }, space: :srgb, interp: :step

      curve :stair_curve, {
        0.0 => 0.0,
        0.5 => 0.5,
        1.0 => 1.0,
      }, interp: :step

      def fragment
        t = stair_curve(UV.x)
        COLOR = step_pal(t)
      end
    CR

    out_code = CrShader.compile(source)
    out_code.should contain("vec4 step_pal(float t)")
    out_code.should contain("step(0.500000, tc)")
    out_code.should contain("float stair_curve(float t)")
  end

  it "evaluates and bakes 1D RGBA8 / Float32 LUT buffers via ProceduralLUT" do
    bytes = CrShader::ProceduralLUT.sample_gradient_bytes(
      {0.0 => "#000000", 1.0 => "#ffffff"},
      width: 64,
      space: :oklab,
      interp: :linear
    )
    bytes.size.should eq(64 * 4)
    # Start stop is black (0, 0, 0, 255)
    bytes[0].should eq(0_u8)
    bytes[1].should eq(0_u8)
    bytes[2].should eq(0_u8)
    bytes[3].should eq(255_u8)
    # End stop is white (255, 255, 255, 255)
    bytes[-4].should eq(255_u8)
    bytes[-3].should eq(255_u8)
    bytes[-2].should eq(255_u8)
    bytes[-1].should eq(255_u8)

    curve_vals = CrShader::ProceduralLUT.sample_curve_floats(
      [{0.0_f32, 0.0_f32}, {0.5_f32, 1.0_f32}, {1.0_f32, 0.25_f32}],
      width: 5,
      interp: :linear
    )
    curve_vals.size.should eq(5)
    curve_vals[0].should be_close(0.0_f32, 0.001_f32)
    curve_vals[2].should be_close(1.0_f32, 0.001_f32)
    curve_vals[4].should be_close(0.25_f32, 0.001_f32)
  end
end
