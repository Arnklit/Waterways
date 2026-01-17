@tool
extends RefCounted

signal generate_flowmap_pressed
signal generate_mesh_pressed
signal debug_view_changed(index: int)
signal generate_system_maps_pressed
signal selection_lock_cleared

var _river_controls = preload("./river_controls.tscn").instantiate()
var _waterfall_controls = preload("./waterfall_controls.tscn").instantiate()
var _water_system_controls = preload("./water_system_controls.tscn").instantiate()
var _plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin


func get_river_controls():
	return _river_controls


func get_waterfall_controls():
	return _waterfall_controls


func get_water_system_controls():
	return _water_system_controls


func hide_all_control_panels() -> void:
	hide_river_control_panel()
	hide_water_system_control_panel()
	hide_waterfall_control_panel()


func show_river_control_panel() -> void:
	if not _river_controls.get_parent():
		_plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
		_river_controls.menu.connect("generate_flowmap", _on_generate_flowmap_pressed)
		_river_controls.menu.connect("generate_mesh", _on_generate_mesh_pressed)
		_river_controls.menu.connect("debug_view_changed", _on_debug_view_changed)


func hide_river_control_panel() -> void:
	if _river_controls.get_parent():
		_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
		_river_controls.menu.disconnect("generate_flowmap", _on_generate_flowmap_pressed)
		_river_controls.menu.disconnect("generate_mesh", _on_generate_mesh_pressed)
		_river_controls.menu.disconnect("debug_view_changed", _on_debug_view_changed)

		if _river_controls.lock_selection:
			_river_controls.lock_selection.button_pressed = false
		emit_signal("selection_lock_cleared")


func show_water_system_control_panel() -> void:
	if not _water_system_controls.get_parent():
		_plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
		_water_system_controls.menu.connect("generate_system_maps", _on_generate_system_maps_pressed)


func hide_water_system_control_panel() -> void:
	if _water_system_controls.get_parent():
		_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
		_water_system_controls.menu.disconnect("generate_system_maps", _on_generate_system_maps_pressed)


func show_waterfall_control_panel() -> void:
	if not _waterfall_controls.get_parent():
		_plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _waterfall_controls)
		_waterfall_controls.menu.connect("generate_flowmap", _on_generate_flowmap_pressed)
		_waterfall_controls.menu.connect("debug_view_changed", _on_debug_view_changed)


func hide_waterfall_control_panel() -> void:
	if _waterfall_controls.get_parent():
		_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _waterfall_controls)
		_waterfall_controls.menu.disconnect("generate_flowmap", _on_generate_flowmap_pressed)
		_waterfall_controls.menu.disconnect("debug_view_changed", _on_debug_view_changed)


func _on_generate_flowmap_pressed() -> void:
	emit_signal("generate_flowmap_pressed")


func _on_generate_mesh_pressed() -> void:
	emit_signal("generate_mesh_pressed")


func _on_debug_view_changed(index: int) -> void:
	emit_signal("debug_view_changed", index)


func _on_generate_system_maps_pressed() -> void:
	emit_signal("generate_system_maps_pressed")
