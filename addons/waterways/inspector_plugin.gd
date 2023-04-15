# Copyright © 2022 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorInspectorPlugin

const RiverManager = preload("res://addons/waterways/river_manager.gd")
var _editor = load("res://addons/waterways/editor_property.gd")


func _can_handle(object) -> bool:
	return object is RiverManager


func _parse_property(object: Object, type: Variant.Type, path: String, hint: PropertyHint, hint_text: String, usage: PropertyUsageFlags, wide: bool) -> bool:
	if type == TYPE_PROJECTION and "color" in path:
		var editor_property = _editor.new()
		add_property_editor(path, editor_property)
		return true
	return false
