extends EditorSpatialGizmoPlugin


const RiverManager = preload("res://addons/river_tool/river_manager.gd")

var editor_plugin : EditorPlugin


func get_name():
	return "RiverGizmo"


func _init():
	#create_material("handles", Color(0.0, 1.0, 0.0))
	create_handle_material("handles")


func has_gizmo(spatial):
	return spatial is RiverManager


func redraw(gizmo):
	gizmo.clear()
	var river: RiverManager = gizmo.get_spatial_node()
	if not river.parent_is_path:
		return

	if not river.is_connected("river_changed", self, "redraw"):
		river.connect("river_changed", self, "redraw", [gizmo])

	var handles : PoolVector3Array
	
	var points = river.get_step_points()
	var directions = river.get_step_points_directions()
	
	for point in points.size() * 2:
		var index = (point / 2)
		var direction = 1.0
		if point % 2 == 1:
			direction = -1.0
		handles.append(points[index] + (directions[index].cross(Vector3.UP)).normalized() * river.river_width_values[index] * direction)
	
	gizmo.add_handles(handles, get_material("handles", gizmo))


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	return "Handle " + String(index)


func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	var river: RiverManager = gizmo.get_spatial_node()
	var adjusted_index = index / 2
	return river.river_width_values[adjusted_index]


func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	print("set_handle called")
	var river: RiverManager = gizmo.get_spatial_node()

	var global_transform: Transform = river.transform
	if river.is_inside_tree():
		global_transform = river.get_global_transform()

	var global_inverse: Transform = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)

	var points = river.get_step_points()
	var directions = river.get_step_points_directions()

	var adjusted_index := index / 2
	var multiplier := 1.0
	if (index % 2 == 1):
		multiplier = -1.0

	var _previous_pos = points[adjusted_index] + (directions[adjusted_index].cross(Vector3.UP)).normalized() * river.river_width_values[adjusted_index] * multiplier

	var p1 = points[adjusted_index]
	var p2 = directions[adjusted_index].cross(Vector3.UP).normalized() * 4096 * multiplier
	var g1 = global_inverse.xform(ray_from)
	var g2 = global_inverse.xform(ray_from + ray_dir * 4096)

	var geo_points = Geometry.get_closest_points_between_segments(p1, p2, g1, g2)
	var dir = geo_points[0].distance_to(points[adjusted_index]) - _previous_pos.distance_to(points[adjusted_index])

	river.river_width_values[adjusted_index] += dir

	redraw(gizmo)

	river.property_list_changed_notify()

func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var river: RiverManager = gizmo.get_spatial_node()
	var river_width_values_undo := river.river_width_values.duplicate(true)
	river_width_values_undo[index / 2] = restore
	var ur = editor_plugin.get_undo_redo()
	ur.create_action("Set River Width")
	ur.add_do_property(river, "river_width_values", river.river_width_values)
	ur.add_do_method(river, "properties_changed")
	ur.add_undo_property(river, "river_width_values", river_width_values_undo)
	ur.add_undo_method(river, "properties_changed")
	ur.commit_action()
	
	redraw(gizmo)
