require "./spec_helper"

describe "GLSL Compute Generation" do
  it "transpiles compute shaders with buffers and workgroups" do
    source = <<-CR
      shader_type :compute
      local_size 32, 1, 1

      buffer InputBuffer, set: 0, binding: 0, std: :std430, restrict: true do
        field values : Array(Float32)
      end

      def main()
        id = gl_GlobalInvocationID.x
        input_buffer.values[id] = input_buffer.values[id] * 2.0
      end
    CR

    output = CrShader.compile(source, target: CrShader::ShaderTarget::GLSL)
    output.should contain("#version 450")
    output.should contain("layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;")
    output.should contain("layout(set = 0, binding = 0, std430) restrict buffer InputBuffer {")
    output.should contain("float values[];")
    output.should contain("} input_buffer;")
    output.should contain("void main() {")
    output.should contain("gl_GlobalInvocationID.x")
  end
end
