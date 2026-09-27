# ==============================================================================
# CrShader Compiler Benchmark
# ==============================================================================
# Benchmarks CrShader DSL parsing, AST transformations, and GDShader emission.
# ==============================================================================

require "../src/crshader/compiler"

count = (ARGV[0]? || "200").to_i

shader_source = <<-CRSHADER
  shader_type :spatial
  render_mode :cull_disabled, :depth_draw_opaque

  uniform albedo : Color = Color.new(0.8, 0.2, 0.3, 1.0), hint: :source_color
  uniform roughness : Float32 = 0.4, hint: hint_range(0.0, 1.0)
  uniform metallic : Float32 = 0.1, hint: hint_range(0.0, 1.0)
  uniform wave_speed : Float32 = 2.0
  uniform wave_height : Float32 = 0.15
  uniform screen_tex : Sampler2D, hint: :screen_texture, filter: :linear

  varying v_world_normal : Vec3
  varying v_world_pos : Vec3

  def vertex
    v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz
    offset = sin(TIME * wave_speed + VERTEX.x * 2.0) * wave_height
    VERTEX.y = VERTEX.y + offset
  end

  def fragment
    ALBEDO = albedo.rgb
    ROUGHNESS = roughness
    METALLIC = metallic
    EMISSION = vec3(0.05, 0.05, 0.05)
  end
CRSHADER

compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)

# Warmup run
_warmup = compiler.compile_source(shader_source)

start_time = Time.instant
total_bytes = 0_i64

count.times do
  result = compiler.compile_source(shader_source)
  total_bytes += result.bytesize
end

elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "CrShaderCompilerBenchmark #{count} iterations: #{total_bytes} bytes emitted"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
