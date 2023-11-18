extends EditorNode3DGizmoPlugin

const WaterfallManager = preload("./../waterfall_manager.gd")

var editor_plugin : EditorPlugin

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


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is WaterfallManager


func _get_handle_name(gizmo: EditorNode3DGizmo, index: int, secondary: bool) -> String:
	return "Handle " + str(index)


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool):
	var waterfall : WaterfallManager = gizmo.get_node_3d()
	if handle_id == 0:
		return waterfall.points[0]
	if handle_id == 1:
		return waterfall.points[1]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var waterfall : WaterfallManager = gizmo.get_node_3d()
	
	var global_transform : Transform3D = waterfall.transform
	if waterfall.is_inside_tree():
		global_transform = waterfall.get_global_transform()

	var ray_from = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	var old_pos : Vector3 = waterfall.get_points()[handle_id]
	var old_pos_global : Vector3 = waterfall.to_global(old_pos)
		
	var new_pos : Vector3
	var plane = Plane(old_pos_global, old_pos_global + camera.transform.basis.x, old_pos_global + camera.transform.basis.y)
	new_pos = plane.intersects_ray(ray_from, ray_dir)

	var new_pos_local = waterfall.to_local(new_pos)

	waterfall.set_point(handle_id, new_pos_local)
	_redraw(gizmo)


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore, cancel: bool) -> void:
	var waterfall : WaterfallManager = gizmo.get_node_3d()
	
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
	
	var waterfall := gizmo.get_node_3d() as WaterfallManager
	
	var handles := PackedVector3Array()
	handles.append(waterfall.points[0])
	handles.append(waterfall.points[1])
	
	gizmo.add_handles(handles, get_material("handles", gizmo), [])
	
	if not waterfall.is_connected("waterfall_changed", Callable(self, "_redraw")):
		waterfall.waterfall_changed.connect(_redraw.bind(gizmo))
	
