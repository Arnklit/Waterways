tool
extends EditorPlugin

signal mode

const RiverGizmoPlugin = preload("res://addons/river_tool/river_gizmo_plugin.gd")

var river_gizmo_plugin = RiverGizmoPlugin.new()


func _enter_tree() -> void:
	add_custom_type("River", "Spatial", preload("res://addons/river_tool/river_manager.gd"), preload("icon.png"))
	add_spatial_gizmo_plugin(river_gizmo_plugin)
	river_gizmo_plugin.editor_plugin = self


func _exit_tree() -> void:
	remove_custom_type("River")
	remove_spatial_gizmo_plugin(river_gizmo_plugin)
