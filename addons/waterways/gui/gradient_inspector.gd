# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

var _object;

func set_node(object) -> void:
	_object = object
	_object.connect("albedo_set", self, "_on_set")
	$Color1.color = _object.mat_albedo[0]
	$Color2.color = _object.mat_albedo[1]
	$Gradient.material.set_shader_param("color1", $Color1.color)
	$Gradient.material.set_shader_param("color2", $Color2.color)


func _on_color1_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color1", color)
	_object.set_albedo1(color)


func _on_color2_changed(color: Color) -> void:
	$Gradient.material.set_shader_param("color2", color)
	_object.set_albedo2(color)


func _on_set(colors) -> void:
	$Color1.color = colors[0]
	$Color2.color = colors[1]
	_on_color1_changed(colors[0])
	_on_color2_changed(colors[1])
