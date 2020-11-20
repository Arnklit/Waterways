extends EditorSpatialGizmoPlugin

const River2Manager = preload("res://addons/river_tool/river2_manager.gd")


var gizmo = preload("res://addons/river_tool/river2_gizmo.gd")
var current_gizmo


func force_redraw():
	if current_gizmo:
		current_gizmo.redraw()

func _init():
	create_handle_material("handles")
	create_material("path", Color(0, 0, 1), false, true)


func create_gizmo(node):
	if node is River2Manager:
		current_gizmo = gizmo.new()
		return current_gizmo
	else:
		return null


func has_gizmo(spatial):
	return spatial is River2Manager

