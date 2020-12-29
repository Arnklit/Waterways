tool
extends HBoxContainer

var _object;

func set_node(object) -> void:
	_object = object
	$Color1.color = _object.mat_albedo1
	$Color2.color = _object.mat_albedo2
	$Gradient.material.set_shader_param("color1", $Color1.color)
	$Gradient.material.set_shader_param("color2", $Color2.color)


func _on_color1_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color1", color)
	_object.set_albedo1(color)


func _on_color2_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color2", color)
	_object.set_albedo2(color)
