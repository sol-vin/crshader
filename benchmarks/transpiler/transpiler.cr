# ==============================================================================
# CrShader Multi-Stage Pipeline Transpiler Benchmark
# ==============================================================================
# Measures CrShader transpilation across spatial, canvas_item, particles, and sky.
# ==============================================================================

require "../../src/crshader/compiler"

count = (ARGV[0]? || "50").to_i

spatial_src = <<-CRSHADER
  shader_type :spatial
  render_mode :cull_disabled

  uniform tint : Color = Color.new(0.2, 0.4, 0.9, 1.0)
  uniform wave : Float32 = 1.5

  def vertex
    VERTEX.y = VERTEX.y + sin(TIME * wave + VERTEX.x) * 0.1
  end

  def fragment
    ALBEDO = tint.rgb
    METALLIC = 0.8
    ROUGHNESS = 0.2
  end
CRSHADER

canvas_src = <<-CRSHADER
  shader_type :canvas_item
  render_mode :blend_mix

  uniform vignette_radius : Float32 = 0.75
  uniform vignette_softness : Float32 = 0.45

  def fragment
    dist = distance(UV, vec2(0.5, 0.5))
    vignette = smoothstep(vignette_radius, vignette_radius - vignette_softness, dist)
    COLOR = vec4(COLOR.rgb * vignette, COLOR.a)
  end
CRSHADER

particles_src = <<-CRSHADER
  shader_type :particles

  uniform gravity : Vec3 = vec3(0.0, -9.8, 0.0)
  uniform spread : Float32 = 2.0

  def start
    VELOCITY = vec3(sin(INDEX * 1.5) * spread, 5.0, cos(INDEX * 1.5) * spread)
  end

  def process
    VELOCITY = VELOCITY + gravity * DELTA
  end
CRSHADER

sky_src = <<-CRSHADER
  shader_type :sky

  uniform sky_color : Color = Color.new(0.3, 0.6, 0.9, 1.0)
  uniform horizon_color : Color = Color.new(0.8, 0.7, 0.6, 1.0)

  def sky
    factor = clamp(EYEDIR.y, 0.0, 1.0)
    COLOR = mix(horizon_color.rgb, sky_color.rgb, factor)
  end
CRSHADER

compiler = CrShader::Compiler.new(target_override: CrShader::ShaderTarget::GDShader)

# Warmup
compiler.compile_source(spatial_src)
compiler.compile_source(canvas_src)
compiler.compile_source(particles_src)
compiler.compile_source(sky_src)

start_time = Time.instant
total_bytes = 0_i64

count.times do
  r1 = compiler.compile_source(spatial_src)
  r2 = compiler.compile_source(canvas_src)
  r3 = compiler.compile_source(particles_src)
  r4 = compiler.compile_source(sky_src)
  total_bytes += r1.bytesize + r2.bytesize + r3.bytesize + r4.bytesize
end

elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "CrShaderPipelineBenchmark #{count * 4} shaders: #{total_bytes} bytes"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
