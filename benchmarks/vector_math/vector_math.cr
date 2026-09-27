# ==============================================================================
# CrShader Vector Math & Color Blending Benchmark
# ==============================================================================
# Measures Crystal vector math, color linear interpolation, and spatial geometry.
# ==============================================================================

require "lapis"

count = (ARGV[0]? || "100000").to_i

start_time = Time.instant
total = 0.0_f64

c1 = Godot::Color.new(0.1_f32, 0.4_f32, 0.8_f32, 1.0_f32)
c2 = Godot::Color.new(0.9_f32, 0.2_f32, 0.3_f32, 1.0_f32)

count.times do |i|
  factor = (i % 100).to_f32 / 100.0_f32
  blended = c1.lerp(c2, factor)

  v = Godot::Vector3.new(blended.r * i.to_f32, blended.g * (i * 2).to_f32, blended.b * (i * 3).to_f32)
  total += v.length.to_f64
end

elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "CrShaderVectorMathBenchmark #{count} iterations: #{total.round(2)}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
