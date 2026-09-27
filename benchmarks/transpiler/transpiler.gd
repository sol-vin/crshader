extends SceneTree

# ==============================================================================
# Godot Multi-Stage Pipeline GDScript Transpiler Benchmark
# ==============================================================================
# Measures GDScript transpilation across spatial, canvas_item, particles, sky.
# ==============================================================================

var TYPE_MAP = {
	"Vec2": "vec2",
	"Vec3": "vec3",
	"Vec4": "vec4",
	"Float32": "float",
	"Int32": "int",
	"Bool": "bool",
	"Color": "vec4"
}

func transpile_crshader(source: String) -> String:
	var out = []
	var lines = source.split("\n")
	var in_func = false

	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed.begins_with("shader_type"):
			var parts = trimmed.split(":")
			if parts.size() > 1:
				out.append("shader_type " + parts[1].strip_edges() + ";")
		elif trimmed.begins_with("render_mode"):
			var modes = trimmed.substr(11).replace(":", "").strip_edges()
			out.append("render_mode " + modes + ";")
		elif trimmed.begins_with("uniform"):
			var u = trimmed.substr(7).strip_edges()
			var colon_idx = u.find(":")
			if colon_idx != -1:
				var u_name = u.substr(0, colon_idx).strip_edges()
				var rest = u.substr(colon_idx + 1).strip_edges()
				var eq_idx = rest.find("=")
				var type_str = "float"
				if eq_idx != -1:
					type_str = rest.substr(0, eq_idx).strip_edges()
				else:
					type_str = rest
				var gd_type = TYPE_MAP.get(type_str, "float")
				out.append("uniform " + gd_type + " " + u_name + ";")
		elif trimmed.begins_with("varying"):
			var v = trimmed.substr(7).strip_edges()
			var v_parts = v.split(":")
			if v_parts.size() > 1:
				var v_name = v_parts[0].strip_edges()
				var v_type = TYPE_MAP.get(v_parts[1].strip_edges(), "vec3")
				out.append("varying " + v_type + " " + v_name + ";")
		elif trimmed.begins_with("def "):
			in_func = true
			var fn_name = trimmed.substr(4).strip_edges()
			out.append("void " + fn_name + "() {")
		elif trimmed == "end":
			if in_func:
				out.append("}")
				in_func = false
		else:
			out.append("\t" + trimmed + ";")

	return "\n".join(out)

func _init():
	var count = 50
	var user_args = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		count = int(user_args[0])

	var spatial_src = """
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
"""

	var canvas_src = """
shader_type :canvas_item
render_mode :blend_mix

uniform vignette_radius : Float32 = 0.75
uniform vignette_softness : Float32 = 0.45

def fragment
	dist = distance(UV, vec2(0.5, 0.5))
	vignette = smoothstep(vignette_radius, vignette_radius - vignette_softness, dist)
	COLOR = vec4(COLOR.rgb * vignette, COLOR.a)
end
"""

	var particles_src = """
shader_type :particles

uniform gravity : Vec3 = vec3(0.0, -9.8, 0.0)
uniform spread : Float32 = 2.0

def start
	VELOCITY = vec3(sin(INDEX * 1.5) * spread, 5.0, cos(INDEX * 1.5) * spread)
end

def process
	VELOCITY = VELOCITY + gravity * DELTA
end
"""

	var sky_src = """
shader_type :sky

uniform sky_color : Color = Color.new(0.3, 0.6, 0.9, 1.0)
uniform horizon_color : Color = Color.new(0.8, 0.7, 0.6, 1.0)

def sky
	factor = clamp(EYEDIR.y, 0.0, 1.0)
	COLOR = mix(horizon_color.rgb, sky_color.rgb, factor)
end
"""

	# Warmup
	var _w1 = transpile_crshader(spatial_src)
	var _w2 = transpile_crshader(canvas_src)
	var _w3 = transpile_crshader(particles_src)
	var _w4 = transpile_crshader(sky_src)

	var start_time = Time.get_ticks_usec()
	var total_bytes = 0

	for i in range(count):
		var s1 = transpile_crshader(spatial_src)
		var s2 = transpile_crshader(canvas_src)
		var s3 = transpile_crshader(particles_src)
		var s4 = transpile_crshader(sky_src)
		total_bytes += s1.length() + s2.length() + s3.length() + s4.length()

	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	print("GDScriptPipelineBenchmark ", count * 4, " shaders: ", total_bytes, " bytes")
	print("ELAPSED_MS: ", str(snappedf(elapsed_ms, 0.01)))
	quit()
