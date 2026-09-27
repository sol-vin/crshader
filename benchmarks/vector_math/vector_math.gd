extends SceneTree

# ==============================================================================
# Godot Vector Math & Color Blending Benchmark
# ==============================================================================
# Measures GDScript vector math, color linear interpolation, and spatial geometry.
# ==============================================================================

func _init():
	var count = 100000
	var user_args = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		count = int(user_args[0])

	var c1 = Color(0.1, 0.4, 0.8, 1.0)
	var c2 = Color(0.9, 0.2, 0.3, 1.0)

	var start_time = Time.get_ticks_usec()
	var total = 0.0

	for i in range(count):
		var factor = float(i % 100) / 100.0
		var blended = c1.lerp(c2, factor)

		var v = Vector3(blended.r * float(i), blended.g * float(i * 2), blended.b * float(i * 3))
		total += v.length()

	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	print("GDScriptVectorMathBenchmark ", count, " iterations: ", str(snappedf(total, 0.01)))
	print("ELAPSED_MS: ", str(snappedf(elapsed_ms, 0.01)))
	quit()
