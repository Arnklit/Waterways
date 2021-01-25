# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

onready var _color1 : ColorPickerButton = $Color1
onready var _color2 : ColorPickerButton = $Color2


func _ready() -> void:
	_color1.connect("color_changed", self, "_on_color1_changed")
	_color2.connect("color_changed", self, "_on_color2_changed")


func _on_color1_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color1", color)


func _on_color2_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color2", color)


func set_value(gradient : Transform):
	_color1.color = Color(gradient[0].x, gradient[0].y, gradient[0].z)
	_color2.color = Color(gradient[1].x, gradient[1].y, gradient[1].z)


func get_value() -> Transform:
	var gradient = Transform()
	gradient[0] = Vector3(_color1.color.r, _color1.color.g, _color1.color.b)
	gradient[1] = Vector3(_color2.color.r, _color2.color.g, _color2.color.b)
	return gradient
