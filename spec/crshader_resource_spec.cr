require "./spec_helper"

describe "CRShader Transparent Loading & Resource Features" do
  it "compiles spatial crshader in-memory without creating files on disk" do
    source = <<-CRSHADER
      shader_type :spatial
      render_mode :cull_back, :diffuse_burley

      uniform albedo_color : Color = Color.new(1.0, 0.5, 0.2, 1.0)
      uniform roughness_val : Float32 = 0.5

      fragment do
        ALBEDO = albedo_color.rgb
        ROUGHNESS = roughness_val
      end
    CRSHADER

    compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)
    transpiled = compiler.compile_source(source)

    transpiled.should contain("shader_type spatial;")
    transpiled.should contain("render_mode cull_back, diffuse_burley;")
    transpiled.should contain("uniform vec4 albedo_color = vec4(1.0, 0.5, 0.2, 1.0);")
    transpiled.should contain("ALBEDO = albedo_color.rgb;")
  end

  it "compiles compute crshader in-memory for GLSL target" do
    source = <<-CRSHADER
      shader_type :compute
      local_size 8, 8, 1

      buffer DataBuffer, binding: 0 do
        field data : Array(Float32)
      end

      def main()
        gid = gl_GlobalInvocationID.x
        data_buffer.data[gid] = data_buffer.data[gid] * 2.0
      end
    CRSHADER

    compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GLSL)
    transpiled = compiler.compile_source(source)

    transpiled.should contain("#version 450")
    transpiled.should contain("layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;")
    transpiled.should contain("layout(set = 0, binding = 0, std430) buffer DataBuffer")
    transpiled.should contain("float data[];")
    transpiled.should contain("data_buffer.data[gid] = (data_buffer.data[gid] * 2.0);")
  end

  it "transparently handles variable sized constant arrays in-memory" do
    source = <<-CRSHADER
      shader_type :canvas_item

      uniform palette = [
        Color.new(0.0, 0.0, 0.0, 1.0),
        Color.new(0.5, 0.5, 0.5, 1.0),
        Color.new(1.0, 1.0, 1.0, 1.0)
      ]

      fragment do
        let col = palette[0]
        COLOR = col
      end
    CRSHADER

    compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)
    transpiled = compiler.compile_source(source)

    transpiled.should contain("const int palette_size = 3;")
    transpiled.should contain("uniform vec4 palette[3];")
    transpiled.should_not contain("uniform vec4 palette[3] =")
  end
end
