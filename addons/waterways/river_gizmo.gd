# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorSpatialGizmoPlugin


const RiverManager = preload("./river_manager.gd")
const RiverControls = preload("./gui/river_controls.gd")
const HANDLES_PER_POINT = 5
const AXIS_CONSTRAINT_LENGTH = 4096
const AXIS_MAPPING := {
	RiverControls.CONSTRAINTS.AXIS_X: Vector3.RIGHT,
	RiverControls.CONSTRAINTS.AXIS_Y: Vector3.UP,
	RiverControls.CONSTRAINTS.AXIS_Z: Vector3.BACK
}
const PLANE_MAPPING := {
	RiverControls.CONSTRAINTS.PLANE_YZ: Vector3.RIGHT,
	RiverControls.CONSTRAINTS.PLANE_XZ: Vector3.UP,
	RiverControls.CONSTRAINTS.PLANE_XY: Vector3.BACK
}

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
	return "RiverInput"


func has_gizmo(spatial) -> bool:
	return spatial is RiverManager


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	return "Handle " + String(index)


func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	var p_index = index / HANDLES_PER_POINT
	var river : RiverManager = gizmo.get_spatial_node()
	if index % HANDLES_PER_POINT == 0:
		return river.curve.get_point_position(p_index)
	if index % HANDLES_PER_POINT == 1:
		return river.curve.get_point_in(p_index)
	if index % HANDLES_PER_POINT == 2:
		return river.curve.get_point_out(p_index)
	if index % HANDLES_PER_POINT == 3 or  index % HANDLES_PER_POINT == 4:
		return river.widths[p_index] 


# Called when handle is moved
func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	var river : RiverManager = gizmo.get_spatial_node()

	var global_transform : Transform = river.transform
	if river.is_inside_tree():
		global_transform = river.get_global_transform()
	var global_inverse: Transform = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)

	var old_pos : Vector3
	var p_index = int(index / HANDLES_PER_POINT)
	var base = river.curve.get_point_position(p_index)
	
	# Logic to move handles
	if index % HANDLES_PER_POINT == 0:
		old_pos = base
	if index % HANDLES_PER_POINT == 1:
		old_pos = river.curve.get_point_in(p_index) + base
	if index % HANDLES_PER_POINT == 2:
		old_pos = river.curve.get_point_out(p_index) + base
	if index % HANDLES_PER_POINT == 3:
		old_pos = base + river.curve.get_point_out(p_index).cross(Vector3.UP).normalized() * river.widths[p_index]
	if index % HANDLES_PER_POINT == 4:
		old_pos = base + river.curve.get_point_out(p_index).cross(Vector3.DOWN).normalized() * river.widths[p_index]
	
	var old_pos_global := river.to_global(old_pos)
	
	if not _handle_base_transform:
		# This is the first set_handle() call since the last reset so we
		# use the current handle position as our _handle_base_transform
		var z := river.curve.get_point_out(p_index).normalized()
		var x := z.cross(Vector3.DOWN).normalized()
		var y := z.cross(x).normalized()
		_handle_base_transform = Transform(
			Basis(x, y, z) * global_transform.basis,
			old_pos_global
		)
	
	# Point, in and out handles
	if index % HANDLES_PER_POINT <= 2:
		var new_pos
		
		if editor_plugin.constraint == RiverControls.CONSTRAINTS.COLLIDERS:
			# TODO - make in / out handles snap to a plane based on the normal of
			# the raycast hit instead.
			var space_state := river.get_world().direct_space_state
			var result = space_state.intersect_ray(ray_from, ray_from + ray_dir * 4096)
			if result:
				new_pos = result.position
		
		elif editor_plugin.constraint == RiverControls.CONSTRAINTS.NONE:
			var plane = Plane(old_pos_global, old_pos_global + camera.transform.basis.x, old_pos_global + camera.transform.basis.y)
			new_pos = plane.intersects_ray(ray_from, ray_dir)
		
		elif editor_plugin.constraint in AXIS_MAPPING:
			var axis: Vector3 = AXIS_MAPPING[editor_plugin.constraint]
			if editor_plugin.local_editing:
				axis = _handle_base_transform.basis.xform(axis)
			var axis_from = old_pos_global + (axis * AXIS_CONSTRAINT_LENGTH)
			var axis_to = old_pos_global - (axis * AXIS_CONSTRAINT_LENGTH)
			var ray_to = ray_from + (ray_dir * AXIS_CONSTRAINT_LENGTH)
			var result = Geometry.get_closest_points_between_segments(axis_from, axis_to, ray_from, ray_to)
			new_pos = result[0]
		
		elif editor_plugin.constraint in PLANE_MAPPING:
			var normal: Vector3 = PLANE_MAPPING[editor_plugin.constraint]
			if editor_plugin.local_editing:
				normal = _handle_base_transform.basis.xform(normal)
			var projected := old_pos_global.project(normal)
			var direction := sign(projected.dot(normal))
			var distance := direction * projected.length()
			var plane := Plane(normal, distance)
			new_pos = plane.intersects_ray(ray_from, ray_dir)
		
		# Discard if no valid position was found
		if not new_pos:
			return
		
		# TODO: implement rounding when control is pressed.
		# How do we round when in local axis/plane mode?
		
		var new_pos_local := river.to_local(new_pos)

		if index % HANDLES_PER_POINT == 0:
			river.set_curve_point_position(p_index, new_pos_local)
		if index % HANDLES_PER_POINT == 1:
			river.set_curve_point_in(p_index, new_pos_local - base)
			river.set_curve_point_out(p_index, -(new_pos_local - base))
		if index % HANDLES_PER_POINT == 2:
			river.set_curve_point_out(p_index, new_pos_local - base)
			river.set_curve_point_in(p_index, -(new_pos_local - base))
	
	# Widths handles
	if index % HANDLES_PER_POINT >= 3:
		var p1 = base
		var p2
		if index % HANDLES_PER_POINT == 3:
			p2 = river.curve.get_point_out(p_index).cross(Vector3.UP).normalized() * 4096
		if index % HANDLES_PER_POINT == 4:
			p2 = river.curve.get_point_out(p_index).cross(Vector3.DOWN).normalized() * 4096
		var g1 = global_inverse.xform(ray_from)
		var g2 = global_inverse.xform(ray_from + ray_dir * 4096)
		
		var geo_points = Geometry.get_closest_points_between_segments(p1, p2, g1, g2)
		var dir = geo_points[0].distance_to(base) - old_pos.distance_to(base)
		
		river.widths[p_index] += dir
	
	redraw(gizmo)

# Handle Undo / Redo of handle movements
func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var river : RiverManager = gizmo.get_spatial_node()
	
	var ur = editor_plugin.get_undo_redo()
	ur.create_action("Change River Shape")
	
	var p_index = index / HANDLES_PER_POINT
	if index % HANDLES_PER_POINT == 0:
		ur.add_do_method(river, "set_curve_point_position", p_index, river.curve.get_point_position(p_index))
		ur.add_undo_method(river, "set_curve_point_position", p_index, restore)
	if index % HANDLES_PER_POINT == 1:
		ur.add_do_method(river, "set_curve_point_in", p_index, river.curve.get_point_in(p_index))
		ur.add_undo_method(river, "set_curve_point_in", p_index, restore)
		ur.add_do_method(river, "set_curve_point_out", p_index, river.curve.get_point_out(p_index))
		ur.add_undo_method(river, "set_curve_point_out", p_index, -restore)
	if index % HANDLES_PER_POINT == 2:
		ur.add_do_method(river, "set_curve_point_out", p_index, river.curve.get_point_out(p_index))
		ur.add_undo_method(river, "set_curve_point_out", p_index, restore)
		ur.add_do_method(river, "set_curve_point_in", p_index, river.curve.get_point_in(p_index))
		ur.add_undo_method(river, "set_curve_point_in", p_index, -restore)
	if index % HANDLES_PER_POINT == 3 or index % HANDLES_PER_POINT == 4:
		var river_widths_undo := river.widths.duplicate(true)
		river_widths_undo[p_index] = restore
		ur.add_do_property(river, "widths", river.widths)
		ur.add_undo_property(river, "widths", river_widths_undo)
	
	ur.add_do_method(river, "properties_changed")
	ur.add_do_method(river, "set_materials", "i_valid_flowmap", false)
	ur.add_do_property(river, "valid_flowmap", false)
	ur.add_do_method(river, "update_configuration_warning")
	ur.add_undo_method(river, "properties_changed")
	ur.add_undo_method(river, "set_materials", "i_valid_flowmap", river.valid_flowmap)
	ur.add_undo_property(river, "valid_flowmap", river.valid_flowmap)
	ur.add_undo_method(river, "update_configuration_warning")
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
	
	var river := gizmo.get_spatial_node() as RiverManager
	
	if not river.is_connected("river_changed", self, "redraw"):
		river.connect("river_changed", self, "redraw", [gizmo])
	
	_draw_path(gizmo, river.curve)
	_draw_handles(gizmo, river)

func _draw_path(gizmo: EditorSpatialGizmo, curve : Curve3D) -> void:
	var path = PoolVector3Array()
	var baked_points = curve.get_baked_points()
	
	for i in baked_points.size() - 1:
		path.append(baked_points[i])
		path.append(baked_points[i + 1])
	
	gizmo.add_lines(path, _path_mat)

func _draw_handles(gizmo: EditorSpatialGizmo, river : RiverManager) -> void:
	var handles = PoolVector3Array()
	var lines = PoolVector3Array()
	for i in river.curve.get_point_count():
		var point_pos = river.curve.get_point_position(i)
		var point_pos_in = river.curve.get_point_in(i) + point_pos
		var point_pos_out = river.curve.get_point_out(i) + point_pos
		var point_width_pos_right = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.UP).normalized() * river.widths[i]
		var point_width_pos_left = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.DOWN).normalized() * river.widths[i]
		
		handles.push_back(point_pos)
		handles.push_back(point_pos_in)
		handles.push_back(point_pos_out)
		handles.push_back(point_width_pos_right)
		handles.push_back(point_width_pos_left)
		
		lines.push_back(point_pos)
		lines.push_back(point_pos_in)
		lines.push_back(point_pos)
		lines.push_back(point_pos_out)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_right)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_left)
		
	gizmo.add_lines(lines, _handle_lines_mat)
	gizmo.add_handles(handles, get_material("handles", gizmo))
