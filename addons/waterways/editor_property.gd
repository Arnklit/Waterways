# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorProperty

const GradientInspector = preload("./gui/gradient_inspector.gd")

var _ui : GradientInspector
var _updating := false

func _init() -> void:
	_ui = preload("res://addons/waterways/gui/gradient_inspector.tscn").instantiate() as Control
	add_child(_ui) 
	set_bottom_editor(_ui)
	(_ui.get_node("Color1") as ColorPickerButton).color_changed.connect(gradient_changed)
	(_ui.get_node("Color2") as ColorPickerButton).color_changed.connect(gradient_changed)


func gradient_changed(_val) -> void:
	print("gradient changed")
	if _updating:
		return
	var value = _ui.get_value()
	emit_changed(get_edited_property(), value)


func _update_property() -> void:
	print("update_property in editor_property.gd")
	var new_value = get_edited_object()[get_edited_property()]
	_updating = true
	_ui.set_value(new_value)
	_updating = false
