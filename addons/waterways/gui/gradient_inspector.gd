# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

onready var _color1 : ColorPickerButton = $Color1
onready var _color2 : ColorPickerButton = $Color2

signal value_changed

var _previous
var _locked := false


func _ready() -> void:
	_color1.connect("color_changed", self, "_on_color1_changed")
	_color2.connect("color_changed", self, "_on_color2_changed")


func _on_color1_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color1", color)


func _on_color2_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color2", color)


func set_value(gradient : Transform):
	print("gradient: ", gradient)
	_color1.color = Color(gradient[0].x, gradient[0].y, gradient[0].z)
	_color2.color = Color(gradient[1].x, gradient[1].y, gradient[1].z)


func get_value() -> Transform:
	print("getting")
	var gradient = Transform()
	gradient[0] = Vector3(_color1.color.r, _color1.color.g, _color1.color.b)
	gradient[1] = Vector3(_color2.color.r, _color2.color.g, _color2.color.b)
	return gradient


func _on_clear_pressed():
	var old = get_value()
	set_value(Transform())
	_previous = old
	_on_value_changed(Transform())


func _on_value_changed(_val) -> void:
	if not _locked:
		var value = get_value()
		if value != _previous:
			emit_signal("value_changed", value, _previous)
