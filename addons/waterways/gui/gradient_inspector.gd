# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends HBoxContainer

@onready var color1 := $Color1 as ColorPickerButton
@onready var color2 := $Color2 as ColorPickerButton
@onready var gradient := $Gradient as ColorRect


func set_value(new_gradient : Projection):
	color1.color = Color(new_gradient[0].x, new_gradient[0].y, new_gradient[0].z)
	color2.color = Color(new_gradient[1].x, new_gradient[1].y, new_gradient[1].z)
	gradient.material.set_shader_parameter("color1", color1.color)
	gradient.material.set_shader_parameter("color2", color2.color)


func get_value() -> Projection:
	var gradient := Projection()
	gradient[0] = Vector3(color1.color.r, color1.color.g, color1.color.b)
	gradient[1] = Vector3(color2.color.r, color2.color.g, color2.color.b)
	return gradient
