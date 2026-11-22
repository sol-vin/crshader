@tool
extends EditorPlugin

var _impl: Node = null


func _ensure_impl() -> bool:
	if _impl != null and is_instance_valid(_impl):
		return true
	_impl = null
	if ClassDB.class_exists(&"CrShaderPlugin"):
		_impl = ClassDB.instantiate(&"CrShaderPlugin")
		if _impl != null:
			if _impl.has_method(&"set_host_editor_plugin"):
				_impl.call(&"set_host_editor_plugin", self)
			if is_inside_tree():
				add_child(_impl)
			return true
	return false


func _enter_tree() -> void:
	_ensure_impl()


func _exit_tree() -> void:
	if _impl != null and is_instance_valid(_impl):
		if _impl.get_parent() == self:
			remove_child(_impl)
		_impl.free()
	_impl = null


func _handles(object: Object) -> bool:
	if _ensure_impl() and _impl.has_method(&"handles_object"):
		return bool(_impl.call(&"handles_object", object))
	return false


func _edit(object: Object) -> void:
	if _ensure_impl() and _impl.has_method(&"edit_object"):
		_impl.call(&"edit_object", object)


func _make_visible(visible: bool) -> void:
	if _ensure_impl() and _impl.has_method(&"make_shader_editor_visible"):
		_impl.call(&"make_shader_editor_visible", visible)


func _save_external_data() -> void:
	if _ensure_impl() and _impl.has_method(&"save_open_shaders"):
		_impl.call(&"save_open_shaders")


func _apply_changes() -> void:
	if _ensure_impl() and _impl.has_method(&"save_open_shaders"):
		_impl.call(&"save_open_shaders")
