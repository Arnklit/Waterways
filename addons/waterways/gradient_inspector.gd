extends EditorInspectorPlugin

const inspectorGUI = preload("res://addons/waterways/gui/gradient_inspector.tscn")

func can_handle(object: Object) -> bool:
	return true


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	
	if type == TYPE_COLOR_ARRAY:
		add_property_editor(path, inspectorGUI.new())
	
		return true
	else:
		return false
