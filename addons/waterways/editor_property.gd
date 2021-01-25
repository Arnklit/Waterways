# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorProperty


var updating = false
var _ui: Control


func _init():
	_ui = preload("res://addons/waterways/gui/gradient_inspector.tscn").instance()
	add_child(_ui) 
	set_bottom_editor(_ui)
	_ui.get_node("Color1").connect("color_changed", self, "_color1_changed")
	_ui.get_node("Color2").connect("color_changed", self, "_color2_changed")


func _color1_changed(value):
	if updating: 
		return
	emit_changed(get_edited_property(), value, "Transform[0]")


func _color2_changed(value):
	if updating: 
		return
	emit_changed(get_edited_property(), value, "Transform[1]")


func update_property():
	var new_value = get_edited_object()[get_edited_property()]
	updating = true
	print("update_property NEW VALUE:")
	print(var2str(new_value))
	_ui.get_node("Color1").color = new_value
	_ui.get_node("Color2").color = new_value
	updating = false
