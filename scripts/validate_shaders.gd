extends SceneTree

func _init():
	var log_file = FileAccess.open("res://validation_log.txt", FileAccess.WRITE)
	log_file.store_line("[ValidateShaders] Starting headless Godot shader validation...")
	var dir = DirAccess.open("res://examples")
	if not dir:
		log_file.store_line("[ValidateShaders] ERROR: Could not open res://examples")
		log_file.close()
		quit(1)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var validated_count = 0
	var failed_count = 0

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gdshader"):
			var res_path = "res://examples/" + file_name
			log_file.store_line("[ValidateShaders] Loading and validating: " + res_path)
			var shader_res = ResourceLoader.load(res_path, "Shader")
			if shader_res and shader_res is Shader:
				var code = shader_res.code
				if code.is_empty():
					log_file.store_line("[ValidateShaders] FAILED: Shader code is empty for " + res_path)
					failed_count += 1
				else:
					# Explicitly compile via RenderingServer
					var rid = RenderingServer.shader_create()
					RenderingServer.shader_set_code(rid, code)
					RenderingServer.free_rid(rid)

					# Also assign to a ShaderMaterial
					var mat = ShaderMaterial.new()
					mat.shader = shader_res
					log_file.store_line("[ValidateShaders] SUCCESS: Validated " + file_name + " (" + str(code.length()) + " bytes)")
					validated_count += 1
			else:
				log_file.store_line("[ValidateShaders] FAILED: Could not load Shader resource: " + res_path)
				failed_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	var summary = "[ValidateShaders] Summary: " + str(validated_count) + " shader(s) validated successfully, " + str(failed_count) + " failed."
	log_file.store_line(summary)
	log_file.close()
	print(summary)
	if failed_count > 0:
		quit(1)
	else:
		quit(0)
