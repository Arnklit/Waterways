# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorProperty


var _ui: Control


func _init():
	_ui = preload("res://addons/waterways/gui/gradient_inspector.tscn").instance()
	add_child(_ui) 
	set_bottom_editor(_ui)


func set_node(object) -> void:
	_ui.set_node(object)
