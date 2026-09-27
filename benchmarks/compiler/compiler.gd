extends SceneTree

# ==============================================================================
# GDScript Shader Compiler & Transpiler Benchmark
# ==============================================================================
# Implements 1-to-1 equivalent parsing, type-lowering and code emission in GDScript
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
	var count = 200
	var user_args = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		count = int(user_args[0])

	var shader_source = """
shader_type :spatial
render_mode :cull_disabled, :depth_draw_opaque

uniform albedo : Color = Color.new(0.8, 0.2, 0.3, 1.0)
uniform roughness : Float32 = 0.4
uniform metallic : Float32 = 0.1
uniform wave_speed : Float32 = 2.0
uniform wave_height : Float32 = 0.15

varying v_world_normal : Vec3

def vertex
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz
	offset = sin(TIME * wave_speed + VERTEX.x * 2.0) * wave_height
	VERTEX.y = VERTEX.y + offset
end

def fragment
	ALBEDO = albedo.rgb
	ROUGHNESS = roughness
	METALLIC = metallic
end
"""

	# Warmup
	var _w = transpile_crshader(shader_source)

	var start_time = Time.get_ticks_usec()
	var total_bytes = 0

	for i in range(count):
		var res = transpile_crshader(shader_source)
		total_bytes += res.length()

	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	print("GDShaderCompilerBenchmark ", count, " iterations: ", total_bytes, " bytes")
	print("ELAPSED_MS: ", str(snappedf(elapsed_ms, 0.01)))
	quit()
