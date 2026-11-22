require "./spec_helper"

describe "CrShader TreeShaker Regression & Dead-Import Elimination" do
  it "preserves helper functions called inside .each, .times, case, unless, and local typed arrays" do
    source = <<-CR
      shader_type :canvas_item

      def loop_tap(idx : Int32) : Float32
        return float(idx) * 0.125
      end

      def times_tap(step : Int32) : Float32
        return float(step) * 0.25
      end

      def switch_branch_fn(v : Float32) : Float32
        return v * 2.0
      end

      def unless_guard_fn(v : Float32) : Float32
        return clamp(v, 0.0, 1.0)
      end

      def unused_dead_fn(v : Float32) : Float32
        return v + 99.0
      end

      def fragment
        acc = 0.0
        (0...4).each do |i|
          acc += loop_tap(i)
        end

        3.times do |t|
          acc += times_tap(t)
        end

        mode = 1
        case mode
        when 1
          acc = switch_branch_fn(acc)
        else
          acc = 0.0
        end

        unless acc < 0.0
          acc = unless_guard_fn(acc)
        end

        COLOR = vec4(vec3(acc), 1.0)
      end
    CR

    code = CrShader.compile(source)
    code.should contain("float loop_tap(int idx)")
    code.should contain("float times_tap(int step)")
    code.should contain("float switch_branch_fn(float v)")
    code.should contain("float unless_guard_fn(float v)")
    code.should_not contain("unused_dead_fn")
  end

  it "prunes unused structs, constants, and functions imported from std/outline while keeping transitive dependencies" do
    source = <<-CR
      shader_type :spatial
      render_mode :unshaded

      require "std/outline"

      def fragment
        packed = pack_outline_meta(5_u32, 2_u32)
        sample = decode_outline_pixel(vec4(0.8, 0.2, 0.1, packed))
        ALBEDO = sample.rgb * float(sample.surface_id) * 0.1
      end
    CR

    code = CrShader.compile(source)
    # Used functions & transitively required constants/structs must remain
    code.should contain("struct PixelOutlineSample {")
    code.should contain("float pack_outline_meta(")
    code.should contain("PixelOutlineSample decode_outline_pixel(")
    code.should contain("uint float_to_bits_u32(")
    code.should contain("OUTLINE_ID_TAG_BITS")

    # Unused parts of std/outline must be stripped cleanly
    code.should_not contain("struct OutlineDecision {")
    code.should_not contain("OUTLINE_DIRS_24")
    code.should_not contain("sample_morphological_stroke")
    code.should_not contain("apply_win98_bevel")
  end
end
