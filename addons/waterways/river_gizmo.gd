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


# Ensure that the width handle can't end up inside the center handle
# as then it is hard to separate them again.
const MIN_DIST_TO_CENTER_HANDLE = 0.02

func _init() -> void:
	# Two materials for every handle type.
	# 1) Transparent handle that is always shown.
	# 2) Opaque handle that is only shown above terrain (when passing depth test)
	# Note that this impacts the point index of the handles. See table below.
	create_handle_material("handles_center")
	create_handle_material("handles_control_points")
	create_handle_material("handles_width")
	create_handle_material("handles_center_with_depth")
	create_handle_material("handles_control_points_with_depth")
	create_handle_material("handles_width_with_depth")

	var handles_center_mat             = get_material("handles_center")
	var handles_center_mat_wd          = get_material("handles_center_with_depth")
	var handles_control_points_mat     = get_material("handles_control_points")
	var handles_control_points_mat_wd  = get_material("handles_control_points_with_depth")
	var handles_width_mat              = get_material("handles_width")
	var handles_width_mat_wd           = get_material("handles_width_with_depth")

	handles_center_mat.set_albedo(           Color(1.0, 1.0, 0.0, 0.25))
	handles_center_mat_wd.set_albedo(        Color(1.0, 1.0, 0.0, 1.0))
	handles_control_points_mat.set_albedo(   Color(1.0, 0.5, 0.0, 0.25))
	handles_control_points_mat_wd.set_albedo(Color(1.0, 0.5, 0.0, 1.0))
	handles_width_mat.set_albedo(            Color(0.0, 1.0, 1.0, 0.25))
	handles_width_mat_wd.set_albedo(         Color(0.0, 1.0, 1.0, 1.0))

	handles_center_mat.set_flag(           SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	handles_center_mat_wd.set_flag(        SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)
	handles_control_points_mat.set_flag(   SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	handles_control_points_mat_wd.set_flag(SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)
	handles_width_mat.set_flag(            SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	handles_width_mat_wd.set_flag(         SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)

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

# Handles are pushed to separate handle lists, one per material (using gizmo.add_handles).
# A handle's "index" is given (by Godot) in order it was added to a gizmo. 
# Given that N = points in the curve:
# - First we add the center ("actual") curve handles, therefore
#   the handle's index is the same as the curve point's index.
# - Then we add the in and out points together. So the first curve point's IN handle
#   gets an index of N. The OUT handle gets N+1.
# - Finally the left/right indices come last, and the first curve point's LEFT is N * 3 .
#   (3 because there are three rows before the left/right indices)
#
# Examples for N = 2, 3, 4:
# curve points 2:0   1      3:0   1   2        4:0   1   2   3
# ------------------------------------------------------------------
# center         0   1        0   1   2          0   1   2   3
# in             2   4        3   5   7          4   6   8   10
# out            3   5        4   6   8          5   7   9   11
# left           6   8        9   11  13         12  14  16  18
# right          7   9        10  12  14         13  15  17  19
#
# The following utility functions calculate to and from curve/handle indices.

func _is_center_point(index: int, river_curve_point_count: int):
	var res = index < river_curve_point_count
	return res

func _is_control_point_in(index: int, river_curve_point_count: int):
	if index < river_curve_point_count:
		return false
	if index >= river_curve_point_count * 3:
		return false
	var res = (index - river_curve_point_count) % 2 == 0
	return res

func _is_control_point_out(index: int, river_curve_point_count: int):
	if index < river_curve_point_count:
		return false
	if index >= river_curve_point_count * 3:
		return false
	var res = (index - river_curve_point_count) % 2 == 1
	return res

func _is_width_point_left(index: int, river_curve_point_count: int):
	if index < river_curve_point_count * 3:
		return false
	var res = (index - river_curve_point_count * 3) % 2 == 0
	return res

func _is_width_point_right(index: int, river_curve_point_count: int):
	if index < river_curve_point_count * 3:
		return false
	var res = (index - river_curve_point_count * 3) % 2 == 1
	return res

func _get_curve_index(index: int, point_count: int):
	if _is_center_point(index, point_count):
		return index
	if _is_control_point_in(index, point_count):
		return (index - point_count) / 2
	if _is_control_point_out(index, point_count):
		return (index - point_count - 1) / 2
	if _is_width_point_left(index, point_count) or _is_width_point_right(index, point_count):
		return (index - point_count * 3) / 2

func _get_point_index(curve_index: int, is_center: bool, is_cp_in: bool, is_cp_out: bool, is_width_left: bool, is_width_right: bool, point_count: int):
	if is_center:
		return curve_index
	if is_cp_in:
		return point_count + curve_index * 2
	if is_cp_out:
		return point_count + 1 + curve_index * 2
	if is_width_left:
		return point_count * 3 + curve_index * 2
	if is_width_right:
		return point_count * 3 + 1 + curve_index * 2


func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	var river : RiverManager = gizmo.get_spatial_node()
	var point_count = river.curve.get_point_count()
	if _is_center_point(index, point_count):
		return river.curve.get_point_position(_get_curve_index(index, point_count))
	if _is_control_point_in(index, point_count):
		return river.curve.get_point_in(_get_curve_index(index, point_count))
	if _is_control_point_out(index, point_count):
		return river.curve.get_point_out(_get_curve_index(index, point_count))
	if _is_width_point_left(index, point_count) or _is_width_point_right(index, point_count):
		return river.widths[_get_curve_index(index, point_count)]


# Called when handle is moved
func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	var river : RiverManager = gizmo.get_spatial_node()
	var space_state := river.get_world().direct_space_state

	var global_transform : Transform = river.transform
	if river.is_inside_tree():
		global_transform = river.get_global_transform()
	var global_inverse: Transform = global_transform.affine_inverse()

	var ray_from = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)

	var old_pos : Vector3
	var point_count = river.curve.get_point_count()
	var p_index = _get_curve_index(index, point_count)
	var base = river.curve.get_point_position(p_index)

	# Logic to move handles
	var is_center = _is_center_point(index, point_count)
	var is_cp_in = _is_control_point_in(index, point_count)
	var is_cp_out = _is_control_point_out(index, point_count)
	var is_width_left = _is_width_point_left(index, point_count)
	var is_width_right = _is_width_point_right(index, point_count)
	if is_center:
		old_pos = base
	if is_cp_in:
		old_pos = river.curve.get_point_in(p_index) + base
	if is_cp_out:
		old_pos = river.curve.get_point_out(p_index) + base
	if is_width_left:
		old_pos = base + river.curve.get_point_out(p_index).cross(Vector3.UP).normalized() * river.widths[p_index]
	if is_width_right:
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
	if is_center or is_cp_in or is_cp_out:
		var new_pos
		
		if editor_plugin.constraint == RiverControls.CONSTRAINTS.COLLIDERS:
			# TODO - make in / out handles snap to a plane based on the normal of
			# the raycast hit instead.
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


		if is_center:
			river.set_curve_point_position(p_index, new_pos_local)
		if is_cp_in:
			river.set_curve_point_in(p_index, new_pos_local - base)
			river.set_curve_point_out(p_index, -(new_pos_local - base))
		if is_cp_out:
			river.set_curve_point_out(p_index, new_pos_local - base)
			river.set_curve_point_in(p_index, -(new_pos_local - base))
	
	# Widths handles
	if is_width_left or is_width_right:
		var p1 = base
		var p2
		if is_width_left:
			p2 = river.curve.get_point_out(p_index).cross(Vector3.UP).normalized() * 4096
		if is_width_right:
			p2 = river.curve.get_point_out(p_index).cross(Vector3.DOWN).normalized() * 4096
		var g1 = global_inverse.xform(ray_from)
		var g2 = global_inverse.xform(ray_from + ray_dir * 4096)
		
		var geo_points = Geometry.get_closest_points_between_segments(p1, p2, g1, g2)
		var dir = geo_points[0].distance_to(base) - old_pos.distance_to(base)
		
		river.widths[p_index] += dir
	

		# Ensure width handles don't end up inside the center point
		river.widths[p_index] = max(river.widths[p_index], MIN_DIST_TO_CENTER_HANDLE)
	redraw(gizmo)

# Handle Undo / Redo of handle movements
func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var river : RiverManager = gizmo.get_spatial_node()
	var point_count = river.curve.get_point_count()

	var ur = editor_plugin.get_undo_redo()
	ur.create_action("Change River Shape")

	var p_index = _get_curve_index(index, point_count)
	if _is_center_point(index, point_count):
		ur.add_do_method(river, "set_curve_point_position", p_index, river.curve.get_point_position(p_index))
		ur.add_undo_method(river, "set_curve_point_position", p_index, restore)
	if _is_control_point_in(index, point_count):
		ur.add_do_method(river, "set_curve_point_in", p_index, river.curve.get_point_in(p_index))
		ur.add_undo_method(river, "set_curve_point_in", p_index, restore)
		ur.add_do_method(river, "set_curve_point_out", p_index, river.curve.get_point_out(p_index))
		ur.add_undo_method(river, "set_curve_point_out", p_index, -restore)
	if _is_control_point_out(index, point_count):
		ur.add_do_method(river, "set_curve_point_out", p_index, river.curve.get_point_out(p_index))
		ur.add_undo_method(river, "set_curve_point_out", p_index, restore)
		ur.add_do_method(river, "set_curve_point_in", p_index, river.curve.get_point_in(p_index))
		ur.add_undo_method(river, "set_curve_point_in", p_index, -restore)
	if _is_width_point_left(index, point_count) or _is_width_point_right(index, point_count):
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
	var lines = PoolVector3Array()
	var handles_center = PoolVector3Array()
	var handles_center_wd = PoolVector3Array()
	var handles_control_points = PoolVector3Array()
	var handles_control_points_wd = PoolVector3Array()
	var handles_width = PoolVector3Array()
	var handles_width_wd = PoolVector3Array()
	var point_count = river.curve.get_point_count()
	for i in point_count:
		var point_pos = river.curve.get_point_position(i)
		var point_pos_in = river.curve.get_point_in(i) + point_pos
		var point_pos_out = river.curve.get_point_out(i) + point_pos
		var point_width_pos_right = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.UP).normalized() * river.widths[i]
		var point_width_pos_left = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.DOWN).normalized() * river.widths[i]

		handles_center.push_back(point_pos)
		handles_control_points.push_back(point_pos_in)
		handles_control_points.push_back(point_pos_out)
		handles_width.push_back(point_width_pos_right)
		handles_width.push_back(point_width_pos_left)

		lines.push_back(point_pos)
		lines.push_back(point_pos_in)
		lines.push_back(point_pos)
		lines.push_back(point_pos_out)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_right)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_left)
		
	gizmo.add_lines(lines, _handle_lines_mat)
	
	# Add each handle twice, for both material types.
	# Needs to be grouped by material "type" since that's what influences the handle indices.
	gizmo.add_handles(handles_center, get_material("handles_center", gizmo))
	gizmo.add_handles(handles_control_points, get_material("handles_control_points", gizmo))
	gizmo.add_handles(handles_width, get_material("handles_width", gizmo))
	gizmo.add_handles(handles_center, get_material("handles_center_with_depth", gizmo))
	gizmo.add_handles(handles_control_points, get_material("handles_control_points_with_depth", gizmo))
	gizmo.add_handles(handles_width, get_material("handles_width_with_depth", gizmo))
