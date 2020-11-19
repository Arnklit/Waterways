extends EditorSpatialGizmoPlugin

var gizmo = preload("res://addons/river_tool/river2_gizmo.gd")

const River2Manager = preload("res://addons/river_tool/river2_manager.gd")


var editor_plugin : EditorPlugin


func get_name():
	return "River2Gizmo"


func _init():
	create_handle_material("handles")


func has_gizmo(spatial):
	return spatial is River2Manager

