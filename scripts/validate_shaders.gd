extends SceneTree

func _initialize():
	var log_file = FileAccess.open("res://validation_log.txt", FileAccess.WRITE)
	log_file.store_line("[ValidateShaders] Starting headless Godot GDShader + SPIR-V GLSL validation...")
	var dir = DirAccess.open("res://examples")
	if not dir:
		log_file.store_line("[ValidateShaders] ERROR: Could not open res://examples")
		log_file.close()
		quit(1)
		return

	var local_rd : RenderingDevice = RenderingServer.get_rendering_device()
	var owns_local_rd := false
	if local_rd == null:
		local_rd = RenderingServer.create_local_rendering_device()
		owns_local_rd = (local_rd != null)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var validated_gd_count = 0
	var validated_glsl_count = 0
	var failed_count = 0

	while file_name != "":
		if not dir.current_is_dir():
			var res_path = "res://examples/" + file_name
			if file_name.ends_with(".gdshader"):
				log_file.store_line("[ValidateShaders] Validating GDShader: " + res_path)
				var shader_res = ResourceLoader.load(res_path, "Shader")
				if shader_res and shader_res is Shader:
					var code = shader_res.code
					if code.is_empty() or code.find("shader_type compute;") != -1:
						log_file.store_line("[ValidateShaders] FAILED: Invalid GDShader code in " + res_path)
						failed_count += 1
					else:
						var rid = RenderingServer.shader_create()
						RenderingServer.shader_set_code(rid, code)
						RenderingServer.free_rid(rid)

						var mat = ShaderMaterial.new()
						mat.shader = shader_res
						log_file.store_line("[ValidateShaders] SUCCESS (GDShader): " + file_name + " (" + str(code.length()) + " bytes)")
						validated_gd_count += 1
				else:
					log_file.store_line("[ValidateShaders] FAILED: Could not load Shader resource: " + res_path)
					failed_count += 1

			elif file_name.ends_with(".glsl") and local_rd != null:
				log_file.store_line("[ValidateShaders] Validating GLSL Compute SPIR-V: " + res_path)
				var glsl_code = FileAccess.get_file_as_string(res_path)
				if glsl_code.is_empty():
					log_file.store_line("[ValidateShaders] FAILED: Empty GLSL file: " + res_path)
					failed_count += 1
				else:
					var src = RDShaderSource.new()
					src.source_compute = glsl_code
					var spirv = local_rd.shader_compile_spirv_from_source(src, false)
					var err = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
					if not err.is_empty():
						log_file.store_line("[ValidateShaders] FAILED SPIR-V (" + file_name + "):\n" + err)
						printerr("[ValidateShaders] SPIR-V compile error in " + file_name + ":\n" + err)
						failed_count += 1
					else:
						var s_rid = local_rd.shader_create_from_spirv(spirv, file_name)
						if s_rid.is_valid():
							local_rd.free_rid(s_rid)
							log_file.store_line("[ValidateShaders] SUCCESS (SPIR-V): " + file_name + " (" + str(glsl_code.length()) + " bytes)")
							validated_glsl_count += 1
						else:
							log_file.store_line("[ValidateShaders] FAILED shader_create_from_spirv: " + file_name)
							failed_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	if owns_local_rd and local_rd != null:
		local_rd.free()

	var summary = "[ValidateShaders] Summary: " + str(validated_gd_count) + " GDShader(s), " + str(validated_glsl_count) + " GLSL SPIR-V kernel(s) validated, " + str(failed_count) + " failed."
	log_file.store_line(summary)
	log_file.close()
	print(summary)
	if failed_count > 0:
		quit(1)
	else:
		quit(0)
