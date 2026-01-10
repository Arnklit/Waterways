extends EditorNode3DGizmoPlugin

const WaterfallManager = preload("./../waterfall_manager.gd")
const RiverManager = preload("./../river_manager.gd")

const SNAP_DISTANCE = 2.0

var editor_plugin: EditorPlugin


func _init() -> void:
	create_handle_material("handles")

	var handles_mat := get_material("handles")

	handles_mat.set_albedo(Color(1.0, 0.0, 0.0, 1.0))

	handles_mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, false)

#	var mat = StandardMaterial3D.new()
#	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
#	mat.set_flag(StandardMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
#	mat.set_albedo(Color(1.0, 1.0, 0.0))
#	mat.render_priority = 10
#	add_material("path", mat)


func _get_gizmo_name() -> String:
	return "WaterfallInput"


func _has_gizmo(node_3d) -> bool:
	return node_3d is WaterfallManager


func _get_handle_name(gizmo: EditorNode3DGizmo, index: int, secondary: bool) -> String:
	return "Handle " + str(index)


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool):
	var waterfall: WaterfallManager = gizmo.get_node_3d()
	if handle_id == 0:
		return waterfall.points[0]
	if handle_id == 1:
		return waterfall.points[1]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var waterfall: WaterfallManager = gizmo.get_node_3d()

	var global_transform: Transform3D = waterfall.transform
	if waterfall.is_inside_tree():
		global_transform = waterfall.get_global_transform()

	var ray_from = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var old_pos: Vector3 = waterfall.get_points()[handle_id]
	var old_pos_global: Vector3 = waterfall.to_global(old_pos)

	var new_pos: Vector3
	var plane = Plane(old_pos_global, old_pos_global + camera.transform.basis.x, old_pos_global + camera.transform.basis.y)
	new_pos = plane.intersects_ray(ray_from, ray_dir)

	# Snap to river/waterfall endpoints when close
	var snap_target := _find_snap_target(waterfall, new_pos)
	if snap_target != Vector3.INF:
		new_pos = snap_target

	var new_pos_local = waterfall.to_local(new_pos)

	waterfall.set_point(handle_id, new_pos_local)
	_redraw(gizmo)


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore, cancel: bool) -> void:
	var waterfall: WaterfallManager = gizmo.get_node_3d()

	var ur := editor_plugin.get_undo_redo()
	ur.create_action("Change Waterfall Shape")
	if handle_id == 0:
		ur.add_do_method(waterfall, "set_point", 0, waterfall.points[0])
		ur.add_undo_method(waterfall, "set_point", 0, restore)
	if handle_id == 1:
		ur.add_do_method(waterfall, "set_point", 1, waterfall.points[1])
		ur.add_undo_method(waterfall, "set_point", 1, restore)

	ur.add_do_method(waterfall, "properties_changed")
	ur.add_undo_method(waterfall, "properties_changed")
	ur.commit_action()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var waterfall = gizmo.get_node_3d()

	var handles := PackedVector3Array()
	handles.append(waterfall.points[0])
	handles.append(waterfall.points[1])

	gizmo.add_handles(handles, get_material("handles", gizmo), [])

	if waterfall.has_signal("waterfall_changed") and not waterfall.is_connected("waterfall_changed", Callable(self, "_redraw")):
		waterfall.waterfall_changed.connect(_redraw.bind(gizmo))


func _find_snap_target(exclude_node: Node3D, global_pos: Vector3) -> Vector3:
	var closest := Vector3.INF
	var closest_dist := SNAP_DISTANCE

	var root := exclude_node.get_tree().edited_scene_root
	if root == null:
		print("No edited_scene_root")
		return Vector3.INF

	var water_nodes = _get_all_water_nodes(root, exclude_node)
	print("Found water nodes: ", water_nodes.size())
	for node in water_nodes:
		var endpoints := _get_endpoints(node)
		print("  Node: ", node.name, " endpoints: ", endpoints)
		for ep in endpoints:
			var dist := global_pos.distance_to(ep)
			print("    dist to ", ep, ": ", dist)
			if dist < closest_dist:
				closest_dist = dist
				closest = ep
	return closest


func _get_all_water_nodes(node: Node, exclude: Node) -> Array:
	var result := []
	if node != exclude:
		if node is WaterfallManager or node is RiverManager:
			result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_water_nodes(child, exclude))
	return result


func _get_endpoints(node: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if node is WaterfallManager:
		var pts = node.get_points()
		points.append(node.to_global(pts[0]))
		points.append(node.to_global(pts[pts.size() - 1]))
	elif node is RiverManager:
		var curve_pts = node.get_curve_points()
		points.append(node.to_global(curve_pts[0]))
		points.append(node.to_global(curve_pts[curve_pts.size() - 1]))
	return points
