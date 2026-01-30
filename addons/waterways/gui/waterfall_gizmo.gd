extends EditorNode3DGizmoPlugin

const WaterfallManager = preload("./../waterfall_manager.gd")
const RiverManager = preload("./../river_manager.gd")

const SNAP_DISTANCE = 2.0
const MIN_WIDTH = 0.1
const DIRECTION_HANDLE_LENGTH = 4.0

var editor_plugin: EditorPlugin
var _handle_lines_mat: Material
var _path_mat: Material


func _init() -> void:
	# Two materials for every handle type:
	# 1) Transparent handle that is always shown (depth test disabled)
	# 2) Opaque handle that is only shown above terrain (depth test enabled)
	create_handle_material("handles")
	create_handle_material("handles_width")
	create_handle_material("handles_direction")
	create_handle_material("handles_with_depth")
	create_handle_material("handles_width_with_depth")
	create_handle_material("handles_direction_with_depth")

	var handles_mat := get_material("handles")
	var handles_mat_wd := get_material("handles_with_depth")
	var handles_width_mat := get_material("handles_width")
	var handles_width_mat_wd := get_material("handles_width_with_depth")
	var handles_direction_mat := get_material("handles_direction")
	var handles_direction_mat_wd := get_material("handles_direction_with_depth")

	handles_mat.set_albedo(Color(1.0, 0.0, 0.0, 0.25))
	handles_mat_wd.set_albedo(Color(1.0, 0.0, 0.0, 1.0))
	handles_width_mat.set_albedo(Color(0.0, 1.0, 1.0, 0.25))
	handles_width_mat_wd.set_albedo(Color(0.0, 1.0, 1.0, 1.0))
	handles_direction_mat.set_albedo(Color(1.0, 0.5, 0.0, 0.25))
	handles_direction_mat_wd.set_albedo(Color(1.0, 0.5, 0.0, 1.0))

	handles_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	handles_mat_wd.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)
	handles_width_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	handles_width_mat_wd.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)
	handles_direction_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	handles_direction_mat_wd.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	mat.set_albedo(Color(1.0, 1.0, 0.0))
	mat.render_priority = 10
	add_material("handle_lines", mat)
	add_material("path", mat)


func _get_gizmo_name() -> String:
	return "WaterfallInput"


func _has_gizmo(node_3d) -> bool:
	return node_3d is WaterfallManager


func _get_handle_name(gizmo: EditorNode3DGizmo, index: int, secondary: bool) -> String:
	if index < 2:
		return "Position " + str(index)
	if index < 6:
		return "Width " + str(index - 2)
	return "Direction " + str(index - 6)


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool):
	var waterfall: WaterfallManager = gizmo.get_node_3d()
	if handle_id == 0:
		return waterfall.points[0]
	if handle_id == 1:
		return waterfall.points[1]
	if handle_id == 2 or handle_id == 3:
		return waterfall.width_top
	if handle_id == 4 or handle_id == 5:
		return waterfall.width_bottom
	if handle_id == 6:
		return waterfall.direction_top
	if handle_id == 7:
		return waterfall.direction_bottom


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

		# Snap to river/waterfall endpoints when close (also match width and direction)
		var snap_result := _find_snap_target(waterfall, new_pos)
		if snap_result.position != Vector3.INF:
			new_pos = snap_result.position
			if snap_result.width > 0.0:
				# Convert direction from global to waterfall's local space
				var local_dir: Vector3 = global_inverse.basis * snap_result.direction
				local_dir.y = 0 # Keep direction in XZ plane
				if local_dir.length() > 0.001:
					local_dir = local_dir.normalized()
				if handle_id == 0:
					waterfall.width_top = snap_result.width
					waterfall.direction_top = local_dir
				else:
					waterfall.width_bottom = snap_result.width
					waterfall.direction_bottom = local_dir

		var new_pos_local = waterfall.to_local(new_pos)
		waterfall.set_point(handle_id, new_pos_local)

	# Width handles (2-5): 2=top_right, 3=top_left, 4=bottom_right, 5=bottom_left
	elif handle_id < 6:
		var is_top := handle_id < 4
		var is_left := (handle_id == 3 or handle_id == 5)
		var base: Vector3 = waterfall.points[0] if is_top else waterfall.points[1]
		var right_vector: Vector3 = waterfall.get_right_vector_top() if is_top else waterfall.get_right_vector_bottom()
		if is_left:
			right_vector = -right_vector

		# Project ray onto the width axis
		var p1 = base
		var p2 = base + right_vector * 4096
		var g1 = global_inverse * ray_from
		var g2 = global_inverse * (ray_from + ray_dir * 4096)

		var geo_points = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
		var new_width = geo_points[0].distance_to(base)
		new_width = max(new_width, MIN_WIDTH)

		if is_top:
			waterfall.width_top = new_width
		else:
			waterfall.width_bottom = new_width
		waterfall.properties_changed()

	# Direction handles (6, 7)
	else:
		var point_index = handle_id - 6
		var base: Vector3 = waterfall.points[point_index]
		var base_global: Vector3 = waterfall.to_global(base)

		# Intersect with XZ plane at the point's Y level
		var xz_plane = Plane(Vector3.UP, base_global.y)
		var hit = xz_plane.intersects_ray(ray_from, ray_dir)
		if hit:
			var dir_global: Vector3 = hit - base_global
			dir_global.y = 0
			if dir_global.length() > 0.001:
				var dir_local: Vector3 = global_inverse.basis * dir_global.normalized()
				dir_local.y = 0
				dir_local = dir_local.normalized()
				if point_index == 0:
					waterfall.direction_top = dir_local
				else:
					waterfall.direction_bottom = dir_local
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
	elif handle_id == 2 or handle_id == 3:
		ur.add_do_property(waterfall, "width_top", waterfall.width_top)
		ur.add_undo_property(waterfall, "width_top", restore)
	elif handle_id == 4 or handle_id == 5:
		ur.add_do_property(waterfall, "width_bottom", waterfall.width_bottom)
		ur.add_undo_property(waterfall, "width_bottom", restore)
	elif handle_id == 6:
		ur.add_do_property(waterfall, "direction_top", waterfall.direction_top)
		ur.add_undo_property(waterfall, "direction_top", restore)
	elif handle_id == 7:
		ur.add_do_property(waterfall, "direction_bottom", waterfall.direction_bottom)
		ur.add_undo_property(waterfall, "direction_bottom", restore)

	ur.add_do_method(waterfall, "properties_changed")
	ur.add_undo_method(waterfall, "properties_changed")
	ur.commit_action()


func _draw_path(gizmo: EditorNode3DGizmo, waterfall: WaterfallManager) -> void:
	var to_from: Vector3 = waterfall.points[1] - waterfall.points[0]
	var to_from_2d := Vector3(to_from.x, 0.0, to_from.z)
	var path := PackedVector3Array()
	var resolution := waterfall.line_sample_resolution
	for i in resolution:
		var t0 := float(i) / float(resolution)
		var t1 := float(i + 1) / float(resolution)
		var p0 := waterfall.points[0] + to_from_2d * t0 + Vector3(0.0, waterfall.ease_back_in(t0) * to_from.y, 0.0)
		var p1 := waterfall.points[0] + to_from_2d * t1 + Vector3(0.0, waterfall.ease_back_in(t1) * to_from.y, 0.0)
		path.append(p0)
		path.append(p1)
	gizmo.add_lines(path, _path_mat)


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	if not _handle_lines_mat:
		_handle_lines_mat = get_material("handle_lines", gizmo)
	if not _path_mat:
		_path_mat = get_material("path", gizmo)
	gizmo.clear()

	var waterfall: WaterfallManager = gizmo.get_node_3d()

	# Add collision triangles for editor selection
	var mesh_instance := waterfall.get_mesh_instance()
	if mesh_instance and mesh_instance.mesh:
		var tri_mesh := mesh_instance.mesh.generate_triangle_mesh()
		if tri_mesh:
			gizmo.add_collision_triangles(tri_mesh)

	_draw_path(gizmo, waterfall)
	var right_top := waterfall.get_right_vector_top()
	var right_bottom := waterfall.get_right_vector_bottom()

	# Get direction vectors (use default if not set)
	var dir_top: Vector3 = waterfall.direction_top
	var dir_bottom: Vector3 = waterfall.direction_bottom
	if dir_top == Vector3.ZERO:
		dir_top = waterfall._get_default_right_vector().cross(Vector3.DOWN).normalized()
	if dir_bottom == Vector3.ZERO:
		dir_bottom = waterfall._get_default_right_vector().cross(Vector3.DOWN).normalized()

	# Position handles
	var handles_pos := PackedVector3Array()
	handles_pos.append(waterfall.points[0])
	handles_pos.append(waterfall.points[1])

	# Width handles (both left and right sides)
	var handles_width := PackedVector3Array()
	var width_top_right: Vector3 = waterfall.points[0] + right_top * waterfall.width_top
	var width_top_left: Vector3 = waterfall.points[0] - right_top * waterfall.width_top
	var width_bottom_right: Vector3 = waterfall.points[1] + right_bottom * waterfall.width_bottom
	var width_bottom_left: Vector3 = waterfall.points[1] - right_bottom * waterfall.width_bottom
	handles_width.append(width_top_right)
	handles_width.append(width_top_left)
	handles_width.append(width_bottom_right)
	handles_width.append(width_bottom_left)

	# Direction handles (orange, showing flow direction)
	var handles_direction := PackedVector3Array()
	var dir_top_pos := waterfall.points[0] + dir_top * DIRECTION_HANDLE_LENGTH
	var dir_bottom_pos := waterfall.points[1] + dir_bottom * DIRECTION_HANDLE_LENGTH
	handles_direction.append(dir_top_pos)
	handles_direction.append(dir_bottom_pos)

	# Lines from center to handles
	var lines := PackedVector3Array()
	lines.append(waterfall.points[0])
	lines.append(width_top_right)
	lines.append(waterfall.points[0])
	lines.append(width_top_left)
	lines.append(waterfall.points[1])
	lines.append(width_bottom_right)
	lines.append(waterfall.points[1])
	lines.append(width_bottom_left)
	lines.append(waterfall.points[0])
	lines.append(dir_top_pos)
	lines.append(waterfall.points[1])
	lines.append(dir_bottom_pos)

	gizmo.add_lines(lines, _handle_lines_mat)
	# Add each handle twice, for both material types (transparent always-visible + opaque with depth)
	gizmo.add_handles(handles_pos, get_material("handles", gizmo), [])
	gizmo.add_handles(handles_width, get_material("handles_width", gizmo), [])
	gizmo.add_handles(handles_direction, get_material("handles_direction", gizmo), [])
	gizmo.add_handles(handles_pos, get_material("handles_with_depth", gizmo), [])
	gizmo.add_handles(handles_width, get_material("handles_width_with_depth", gizmo), [])
	gizmo.add_handles(handles_direction, get_material("handles_direction_with_depth", gizmo), [])

	if waterfall.has_signal("waterfall_changed") and not waterfall.is_connected("waterfall_changed", Callable(self, "_redraw")):
		waterfall.waterfall_changed.connect(_redraw.bind(gizmo))


func _find_snap_target(exclude_node: Node3D, global_pos: Vector3) -> Dictionary:
	var closest := Vector3.INF
	var closest_width := 0.0
	var closest_direction := Vector3.ZERO
	var closest_dist := SNAP_DISTANCE

	var root := exclude_node.get_tree().edited_scene_root
	if root == null:
		return { position = Vector3.INF, width = 0.0, direction = Vector3.ZERO }

	var water_nodes = _get_all_water_nodes(root, exclude_node)
	for node in water_nodes:
		var endpoints := _get_endpoints(node)
		for ep in endpoints:
			var dist := global_pos.distance_to(ep.position)
			if dist < closest_dist:
				closest_dist = dist
				closest = ep.position
				closest_width = ep.width
				closest_direction = ep.direction
	return { position = closest, width = closest_width, direction = closest_direction }


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
		# Convert directions to global space
		var dir_top: Vector3 = node.direction_top
		var dir_bottom: Vector3 = node.direction_bottom
		if dir_top != Vector3.ZERO:
			dir_top = node.global_transform.basis * dir_top
		if dir_bottom != Vector3.ZERO:
			dir_bottom = node.global_transform.basis * dir_bottom
		endpoints.append(
			{
				position = node.to_global(pts[0]),
				width = node.width_top,
				direction = dir_top,
			},
		)
		endpoints.append(
			{
				position = node.to_global(pts[pts.size() - 1]),
				width = node.width_bottom,
				direction = dir_bottom,
			},
		)
	elif node is RiverManager:
		var curve: Curve3D = node.curve
		var curve_pts = node.get_curve_points()
		var widths = node.widths
		# Start: use point_out as direction (tangent going forward)
		var dir_start: Vector3 = curve.get_point_out(0).normalized()
		# End: use negative point_in as direction (tangent going forward)
		var dir_end: Vector3 = (-curve.get_point_in(curve.get_point_count() - 1)).normalized()
		endpoints.append(
			{
				position = node.to_global(curve_pts[0]),
				width = widths[0],
				direction = node.global_transform.basis * dir_start,
			},
		)
		endpoints.append(
			{
				position = node.to_global(curve_pts[curve_pts.size() - 1]),
				width = widths[widths.size() - 1],
				direction = node.global_transform.basis * dir_end,
			},
		)
	return endpoints
