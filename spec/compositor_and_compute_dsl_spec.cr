require "./spec_helper"
require "../src/crshader/compiler"

describe "CrShader Compositor & Compute DSL Helpers" do
  compiler = CrShader::Compiler.new

  it "desugars compositor_effect with access and process_pixel into GLSL compute" do
    source = <<-CR
      compositor_effect :post_transparent do
        access :color, :depth

        property intensity : Float32 = 1.0, range: 0.0..2.0

        process_pixel do |coord, color|
          color.rgb *= intensity
        end
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("#version 450")
    code.should contain("layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;")
    code.should contain("layout(rgba32f, set = 0, binding = 0) uniform image2D color_image;")
    code.should contain("layout(r32f, set = 0, binding = 1) uniform image2D depth_image;")
    code.should contain("coord = ivec2(gl_GlobalInvocationID.xy)")
    code.should contain("(coord.x >= size.x) || (coord.y >= size.y)")
    code.should contain("color = imageLoad(color_image, coord)")
    code.should contain("imageStore(color_image, coord, color)")
  end

  it "desugars compute_kernel with kernel_1d and bounds checking" do
    source = <<-CR
      compute_kernel 64, 1, 1 do
        storage_buffer :particles, set: 0, binding: 0 do
          field positions : Array(Vec4)
        end

        push_constants do
          field count : UInt32
          field delta : Float32
        end

        kernel_1d :count do |idx|
          particles.positions[idx].y += delta
        end
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("#version 450")
    code.should contain("layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;")
    code.should contain("layout(set = 0, binding = 0, std430) buffer Particles {")
    code.should contain("layout(push_constant, std430) uniform PushConstants {")
    code.should contain("idx = gl_GlobalInvocationID.x")
    code.should contain("idx >= count")
  end

  it "desugars compute_kernel with kernel_2d and bounds checking" do
    source = <<-CR
      compute_kernel 8, 8, 1 do
        storage_image :input_tex, format: :rgba32f, set: 0, binding: 0

        kernel_2d :input_tex do |coord|
          val = imageLoad(input_tex, coord)
          imageStore(input_tex, coord, val * 0.5)
        end
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("#version 450")
    code.should contain("layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;")
    code.should contain("layout(rgba32f, set = 0, binding = 0) uniform image2D input_tex;")
    code.should contain("coord = ivec2(gl_GlobalInvocationID.xy)")
    code.should contain("imageSize(input_tex)")
  end

  it "supports synchronization barrier builtins in compute shaders" do
    source = <<-CR
      compute_kernel 16, 16, 1 do
        def main
          barrier_execution
          barrier_memory
          barrier_image
          barrier_buffer
        end
      end
    CR

    code = compiler.compile_source(source)
    code.should contain("barrier();")
    code.should contain("memoryBarrier();")
    code.should contain("memoryBarrierImage();")
    code.should contain("memoryBarrierBuffer();")
  end
end
