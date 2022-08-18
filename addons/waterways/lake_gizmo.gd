# Copyright © 2022 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorSpatialGizmoPlugin

const LakeManager = preload("./lake_manager.gd")
const LakeControls = preload("./gui/lake_controls.gd")
const HANDLES_PER_POINT = 3

var editor_plugin : EditorPlugin

var _path_mat
var _handle_lines_mat
var _handle_base_transform


func _init() -> void:
	create_handle_material("handles")
	var mat = SpatialMaterial.new()
	mat.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
	mat.set_flag(SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	mat.set_albedo(Color(1.0, 1.0, 0.0))
	mat.render_priority = 10
	add_material("path", mat)
	add_material("handle_lines", mat)


func reset() -> void:
	_handle_base_transform = null


func get_name() -> String:
	return "LakeInput"


func has_gizmo(spatial) -> bool:
	return spatial is LakeManager


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	return "Handle " + String(index)


func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	var p_index = index / HANDLES_PER_POINT
	var lake : LakeManager = gizmo.get_spatial_node()
	if index % HANDLES_PER_POINT == 0:
		return lake.curve.get_point_position(p_index)
	if index % HANDLES_PER_POINT == 1:
		return lake.curve.get_point_in(p_index)
	if index % HANDLES_PER_POINT == 2:
		return lake.curve.get_point_out(p_index)

# Called when handle is moved
func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	var lake : LakeManager = gizmo.get_spatial_node()

	var global_transform : Transform = lake.transform
	if lake.is_inside_tree():
		global_transform = lake.get_global_transform()
	var global_inverse: Transform = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)

	var old_pos : Vector3
	var p_index = int(index / HANDLES_PER_POINT)
	var base = lake.curve.get_point_position(p_index)
	
	# Logic to move handles
	if index % HANDLES_PER_POINT == 0:
		old_pos = base
	if index % HANDLES_PER_POINT == 1:
		old_pos = lake.curve.get_point_in(p_index) + base
	if index % HANDLES_PER_POINT == 2:
		old_pos = lake.curve.get_point_out(p_index) + base
	
	var old_pos_global := lake.to_global(old_pos)
	
	if not _handle_base_transform:
		# This is the first set_handle() call since the last reset so we
		# use the current handle position as our _handle_base_transform
		var z := lake.curve.get_point_out(p_index).normalized()
		var x := z.cross(Vector3.DOWN).normalized()
		var y := z.cross(x).normalized()
		_handle_base_transform = Transform(
			Basis(x, y, z) * global_transform.basis,
			old_pos_global
		)
	
	# Point, in and out handles
	if index % HANDLES_PER_POINT <= 2:
		var new_pos
		
		var plane = Plane(old_pos_global, old_pos_global + camera.transform.basis.x, old_pos_global + camera.transform.basis.y)
		new_pos = plane.intersects_ray(ray_from, ray_dir)
		
		# Discard if no valid position was found
		if not new_pos:
			return
		
		var new_pos_local := lake.to_local(new_pos)

		if index % HANDLES_PER_POINT == 0:
			lake.set_curve_point_position(p_index, new_pos_local)
		if index % HANDLES_PER_POINT == 1:
			lake.set_curve_point_in(p_index, new_pos_local - base)
			lake.set_curve_point_out(p_index, -(new_pos_local - base))
		if index % HANDLES_PER_POINT == 2:
			lake.set_curve_point_out(p_index, new_pos_local - base)
			lake.set_curve_point_in(p_index, -(new_pos_local - base))
	
	redraw(gizmo)


# Handle Undo / Redo of handle movements
func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var lake : LakeManager = gizmo.get_spatial_node()

	var ur = editor_plugin.get_undo_redo()
	ur.create_action("Change Lake Shape")

	var p_index = index / HANDLES_PER_POINT
	if index % HANDLES_PER_POINT == 0:
		ur.add_do_method(lake, "set_curve_point_position", p_index, lake.curve.get_point_position(p_index))
		ur.add_undo_method(lake, "set_curve_point_position", p_index, restore)
	if index % HANDLES_PER_POINT == 1:
		ur.add_do_method(lake, "set_curve_point_in", p_index, lake.curve.get_point_in(p_index))
		ur.add_undo_method(lake, "set_curve_point_in", p_index, restore)
		ur.add_do_method(lake, "set_curve_point_out", p_index, lake.curve.get_point_out(p_index))
		ur.add_undo_method(lake, "set_curve_point_out", p_index, -restore)
	if index % HANDLES_PER_POINT == 2:
		ur.add_do_method(lake, "set_curve_point_out", p_index, lake.curve.get_point_out(p_index))
		ur.add_undo_method(lake, "set_curve_point_out", p_index, restore)
		ur.add_do_method(lake, "set_curve_point_in", p_index, lake.curve.get_point_in(p_index))
		ur.add_undo_method(lake, "set_curve_point_in", p_index, -restore)
	
	ur.add_do_method(lake, "properties_changed")
	ur.add_do_method(lake, "update_configuration_warning")
	ur.add_undo_method(lake, "properties_changed")
	ur.add_undo_method(lake, "update_configuration_warning")
	ur.commit_action()
	
	redraw(gizmo)


func redraw(gizmo: EditorSpatialGizmo) -> void:
	# Work around for issue where using "get_material" doesn't return a
	# material when redraw is being called manually from _set_handle()
	# so I'm caching the materials instead
	if not _path_mat:
		_path_mat = get_material("path", gizmo)
	if not _handle_lines_mat:
		_handle_lines_mat = get_material("handle_lines", gizmo)
	gizmo.clear()
	
	var lake := gizmo.get_spatial_node() as LakeManager
	
	if not lake.is_connected("lake_changed", self, "redraw"):
		lake.connect("lake_changed", self, "redraw", [gizmo])
	
	_draw_path(gizmo, lake.curve)
	_draw_handles(gizmo, lake)


func _draw_path(gizmo: EditorSpatialGizmo, curve : Curve3D) -> void:
	var path = PoolVector3Array()
	var baked_points = curve.get_baked_points()
	
	for i in baked_points.size() - 1:
		path.append(baked_points[i])
		path.append(baked_points[i + 1])
	
	gizmo.add_lines(path, _path_mat)


func _draw_handles(gizmo: EditorSpatialGizmo, lake : LakeManager) -> void:
	var handles = PoolVector3Array()
	var lines = PoolVector3Array()
	for i in lake.curve.get_point_count():
		var point_pos = lake.curve.get_point_position(i)
		var point_pos_in = lake.curve.get_point_in(i) + point_pos
		var point_pos_out = lake.curve.get_point_out(i) + point_pos
		
		handles.push_back(point_pos)
		handles.push_back(point_pos_in)
		handles.push_back(point_pos_out)
		
		lines.push_back(point_pos)
		lines.push_back(point_pos_in)
		lines.push_back(point_pos)
		lines.push_back(point_pos_out)
	
	gizmo.add_lines(lines, _handle_lines_mat)
	gizmo.add_handles(handles, get_material("handles", gizmo))
