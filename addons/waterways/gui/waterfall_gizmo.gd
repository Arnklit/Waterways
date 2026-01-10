extends EditorNode3DGizmoPlugin

const WaterfallManager = preload("./../waterfall_manager.gd")
const RiverManager = preload("./../river_manager.gd")

const SNAP_DISTANCE = 2.0
const MIN_WIDTH = 0.1

var editor_plugin: EditorPlugin
var _handle_lines_mat: Material


func _init() -> void:
	create_handle_material("handles")
	create_handle_material("handles_width")

	var handles_mat := get_material("handles")
	handles_mat.set_albedo(Color(1.0, 0.0, 0.0, 1.0))
	handles_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)

	var handles_width_mat := get_material("handles_width")
	handles_width_mat.set_albedo(Color(0.0, 1.0, 1.0, 1.0))
	handles_width_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	mat.set_albedo(Color(1.0, 1.0, 0.0))
	mat.render_priority = 10
	add_material("handle_lines", mat)


func _get_gizmo_name() -> String:
	return "WaterfallInput"


func _has_gizmo(node_3d) -> bool:
	return node_3d is WaterfallManager


func _get_handle_name(gizmo: EditorNode3DGizmo, index: int, secondary: bool) -> String:
	if index < 2:
		return "Position " + str(index)
	return "Width " + str(index - 2)


func _get_right_vector(waterfall: WaterfallManager) -> Vector3:
	var to_from: Vector3 = waterfall.points[1] - waterfall.points[0]
	var to_from_2d = Vector3(to_from.x, 0.0, to_from.z)
	if to_from_2d.length() < 0.001:
		return Vector3.RIGHT
	return to_from_2d.cross(Vector3.UP).normalized()


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool):
	var waterfall: WaterfallManager = gizmo.get_node_3d()
	if handle_id == 0:
		return waterfall.points[0]
	if handle_id == 1:
		return waterfall.points[1]
	if handle_id == 2:
		return waterfall.width_top
	if handle_id == 3:
		return waterfall.width_bottom


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var waterfall: WaterfallManager = gizmo.get_node_3d()

	var global_transform: Transform3D = waterfall.transform
	if waterfall.is_inside_tree():
		global_transform = waterfall.get_global_transform()
	var global_inverse: Transform3D = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	# Position handles (0, 1)
	if handle_id < 2:
		var old_pos: Vector3 = waterfall.get_points()[handle_id]
		var old_pos_global: Vector3 = waterfall.to_global(old_pos)

		var new_pos: Vector3
		var plane = Plane(old_pos_global, old_pos_global + camera.transform.basis.x, old_pos_global + camera.transform.basis.y)
		new_pos = plane.intersects_ray(ray_from, ray_dir)

		# Snap to river/waterfall endpoints when close (also match width)
		var snap_result := _find_snap_target(waterfall, new_pos)
		if snap_result.position != Vector3.INF:
			new_pos = snap_result.position
			if snap_result.width > 0.0:
				if handle_id == 0:
					waterfall.width_top = snap_result.width
				else:
					waterfall.width_bottom = snap_result.width

		var new_pos_local = waterfall.to_local(new_pos)
		waterfall.set_point(handle_id, new_pos_local)

	# Width handles (2, 3)
	else:
		var point_index = handle_id - 2
		var base: Vector3 = waterfall.points[point_index]
		var right_vector := _get_right_vector(waterfall)

		# Project ray onto the width axis
		var p1 = base
		var p2 = base + right_vector * 4096
		var g1 = global_inverse * ray_from
		var g2 = global_inverse * (ray_from + ray_dir * 4096)

		var geo_points = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
		var new_width = geo_points[0].distance_to(base)
		new_width = max(new_width, MIN_WIDTH)

		if point_index == 0:
			waterfall.width_top = new_width
		else:
			waterfall.width_bottom = new_width
		waterfall.properties_changed()

	_redraw(gizmo)


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore, cancel: bool) -> void:
	var waterfall: WaterfallManager = gizmo.get_node_3d()

	var ur := editor_plugin.get_undo_redo()
	ur.create_action("Change Waterfall Shape")

	if handle_id == 0:
		ur.add_do_method(waterfall, "set_point", 0, waterfall.points[0])
		ur.add_undo_method(waterfall, "set_point", 0, restore)
	elif handle_id == 1:
		ur.add_do_method(waterfall, "set_point", 1, waterfall.points[1])
		ur.add_undo_method(waterfall, "set_point", 1, restore)
	elif handle_id == 2:
		ur.add_do_property(waterfall, "width_top", waterfall.width_top)
		ur.add_undo_property(waterfall, "width_top", restore)
	elif handle_id == 3:
		ur.add_do_property(waterfall, "width_bottom", waterfall.width_bottom)
		ur.add_undo_property(waterfall, "width_bottom", restore)

	ur.add_do_method(waterfall, "properties_changed")
	ur.add_undo_method(waterfall, "properties_changed")
	ur.commit_action()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	if not _handle_lines_mat:
		_handle_lines_mat = get_material("handle_lines", gizmo)
	gizmo.clear()

	var waterfall: WaterfallManager = gizmo.get_node_3d()
	var right_vector := _get_right_vector(waterfall)

	# Position handles
	var handles_pos := PackedVector3Array()
	handles_pos.append(waterfall.points[0])
	handles_pos.append(waterfall.points[1])

	# Width handles (on right side of each point)
	var handles_width := PackedVector3Array()
	var width_top_pos := waterfall.points[0] + right_vector * waterfall.width_top
	var width_bottom_pos := waterfall.points[1] + right_vector * waterfall.width_bottom
	handles_width.append(width_top_pos)
	handles_width.append(width_bottom_pos)

	# Lines from center to width handles
	var lines := PackedVector3Array()
	lines.append(waterfall.points[0])
	lines.append(width_top_pos)
	lines.append(waterfall.points[1])
	lines.append(width_bottom_pos)

	gizmo.add_lines(lines, _handle_lines_mat)
	gizmo.add_handles(handles_pos, get_material("handles", gizmo), [])
	gizmo.add_handles(handles_width, get_material("handles_width", gizmo), [])

	if waterfall.has_signal("waterfall_changed") and not waterfall.is_connected("waterfall_changed", Callable(self, "_redraw")):
		waterfall.waterfall_changed.connect(_redraw.bind(gizmo))


func _find_snap_target(exclude_node: Node3D, global_pos: Vector3) -> Dictionary:
	var closest := Vector3.INF
	var closest_width := 0.0
	var closest_dist := SNAP_DISTANCE

	var root := exclude_node.get_tree().edited_scene_root
	if root == null:
		return { position = Vector3.INF, width = 0.0 }

	var water_nodes = _get_all_water_nodes(root, exclude_node)
	for node in water_nodes:
		var endpoints := _get_endpoints(node)
		for ep in endpoints:
			var dist := global_pos.distance_to(ep.position)
			if dist < closest_dist:
				closest_dist = dist
				closest = ep.position
				closest_width = ep.width
	return { position = closest, width = closest_width }


func _get_all_water_nodes(node: Node, exclude: Node) -> Array:
	var result := []
	if node != exclude:
		if node is WaterfallManager or node is RiverManager:
			result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_water_nodes(child, exclude))
	return result


func _get_endpoints(node: Node3D) -> Array:
	var endpoints := []
	if node is WaterfallManager:
		var pts = node.get_points()
		endpoints.append({ position = node.to_global(pts[0]), width = node.width_top })
		endpoints.append({ position = node.to_global(pts[pts.size() - 1]), width = node.width_bottom })
	elif node is RiverManager:
		var curve_pts = node.get_curve_points()
		var widths = node.widths
		endpoints.append({ position = node.to_global(curve_pts[0]), width = widths[0] })
		endpoints.append({ position = node.to_global(curve_pts[curve_pts.size() - 1]), width = widths[widths.size() - 1] })
	return endpoints
