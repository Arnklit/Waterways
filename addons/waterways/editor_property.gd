# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorProperty

var _ui : Control
var _updating := false

func _init() -> void:
	_ui = preload("res://addons/waterways/gui/gradient_inspector.tscn").instance()
	add_child(_ui) 
	set_bottom_editor(_ui)
	_ui.get_node("Color1").connect("color_changed", self, "gradient_changed")
	_ui.get_node("Color2").connect("color_changed", self, "gradient_changed")


func gradient_changed(_val) -> void:
	if _updating:
		return
	var value = _ui.get_value()
	emit_changed(get_edited_property(), value)


func update_property() -> void:
	var new_value = get_edited_object()[get_edited_property()]
	_updating = true
	_ui.set_value(new_value)
	_updating = false
