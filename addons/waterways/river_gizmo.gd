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
var _path_mat_wd
var _handle_control_point_lines_mat
var _handle_control_point_lines_mat_wd
var _handle_width_lines_mat
var _handle_width_lines_mat_wd
var _handle_base_transform
var _extra_lines = {}

const HANDLE_OFFSET = Vector3(0, 0.05, 0)

func _init() -> void:
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

	var path_mat = SpatialMaterial.new()
	var path_mat_wd = SpatialMaterial.new()
	var control_points_mat = SpatialMaterial.new()
	var control_points_mat_wd = SpatialMaterial.new()
	var width_mat = SpatialMaterial.new()
	var width_mat_wd = SpatialMaterial.new()
	path_mat.set_albedo(               Color(1.0, 1.0, 0,   0.25))
	path_mat_wd.set_albedo(            Color(1.0, 1.0, 0,   1.0))
	control_points_mat.set_albedo(     Color(1.0, 0.5, 0.0, 0.25))
	control_points_mat_wd.set_albedo(  Color(1.0, 0.5, 0.0, 1.0))
	width_mat.set_albedo(              Color(0.0, 1.0, 1.0, 0.25))
	width_mat_wd.set_albedo(           Color(0.0, 1.0, 1.0, 1.0))

	path_mat.set_flag(             SpatialMaterial.FLAG_UNSHADED, true)
	path_mat_wd.set_flag(          SpatialMaterial.FLAG_UNSHADED, true)
	control_points_mat.set_flag(   SpatialMaterial.FLAG_UNSHADED, true)
	control_points_mat_wd.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
	width_mat.set_flag(            SpatialMaterial.FLAG_UNSHADED, true)
	width_mat_wd.set_flag(         SpatialMaterial.FLAG_UNSHADED, true)

	path_mat.set_flag(             SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	path_mat_wd.set_flag(          SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)
	control_points_mat.set_flag(   SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	control_points_mat_wd.set_flag(SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)
	width_mat.set_flag(            SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, true)
	width_mat_wd.set_flag(         SpatialMaterial.FLAG_DISABLE_DEPTH_TEST, false)
	path_mat.flags_transparent = true;
	path_mat_wd.flags_transparent = true;
	control_points_mat.flags_transparent = true;
	control_points_mat_wd.flags_transparent = true;
	width_mat.flags_transparent = true;
	width_mat_wd.flags_transparent = true;

	path_mat.render_priority = 10
	path_mat_wd.render_priority = 10
	control_points_mat.render_priority = 10
	control_points_mat_wd.render_priority = 10
	width_mat.render_priority = 10
	width_mat_wd.render_priority = 10
	add_material("path", path_mat)
	add_material("path_wd", path_mat_wd)
	add_material("handle_control_point_lines", control_points_mat)
	add_material("handle_control_point_lines_wd", control_points_mat_wd)
	add_material("handle_width_lines", width_mat)
	add_material("handle_width_lines_wd", width_mat_wd)

	_path_mat = path_mat
	_path_mat_wd = path_mat_wd
	_handle_control_point_lines_mat = control_points_mat
	_handle_control_point_lines_mat_wd = control_points_mat_wd
	_handle_width_lines_mat = width_mat
	_handle_width_lines_mat_wd = width_mat_wd

	_extra_lines = {}

func reset() -> void:
	_handle_base_transform = null


func get_name() -> String:
	return "RiverInput"


func has_gizmo(spatial) -> bool:
	return spatial is RiverManager


func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	return "Handle " + String(index)

# curve points 2:0   1      3:0   1   2        4:0   1   2   3
# ------------------------------------------------------------------
# center         0   1        0   1   2          0   1   2   3
# in             2   4        3   5   7          4   6   8   10
# out            3   5        4   6   8          5   7   9   11
# left           6   8        9   11  13         12  14  16  18
# right          7   9        10  12  14         13  15  17  19

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
	assert(false)
	return 0


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
		river.widths[p_index] = max(river.widths[p_index], 0.02)

#	for i in range(point_count):
	if true:
		var i = _get_curve_index(index, point_count)
		var point_index_center = _get_point_index(i, true, false, false, false, false, point_count)
		var point_index_cp_in = _get_point_index(i, false, true, false, false, false, point_count)
		var point_index_cp_out = _get_point_index(i, false, false, true, false, false, point_count)
		var point_index_width_left = _get_point_index(i, false, false, false, true, false, point_count)
		var point_index_width_right = _get_point_index(i, false, false, false, false, true, point_count)
		var point_pos = river.curve.get_point_position(i)
		var point_pos_in = river.curve.get_point_in(i) + point_pos
		var point_pos_out = river.curve.get_point_out(i) + point_pos
		var point_width_pos_left = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.DOWN).normalized() * river.widths[i]
		var point_width_pos_right = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.UP).normalized() * river.widths[i]

		if editor_plugin.extra_handle_lines or is_center:
			draw_vertical_line_to_terrain(point_index_center, point_pos, river.global_transform.origin, space_state, "center")
		if editor_plugin.extra_handle_lines or is_cp_in or is_cp_out:
			draw_vertical_line_to_terrain(point_index_cp_in, point_pos_in, river.global_transform.origin, space_state, "cp")
			draw_vertical_line_to_terrain(point_index_cp_out, point_pos_out, river.global_transform.origin, space_state, "cp")
		if editor_plugin.extra_handle_lines or is_width_left or is_width_right:
			draw_vertical_line_to_terrain(point_index_width_left, point_width_pos_left, river.global_transform.origin, space_state, "width")
			draw_vertical_line_to_terrain(point_index_width_right, point_width_pos_right, river.global_transform.origin, space_state, "width")

		if is_center:
			if i > 0:
				for t_i in range(1, 5):
					draw_vertical_line_to_terrain(point_count*5+t_i, river.curve.interpolate(i-1, float(t_i)/5), river.global_transform.origin, space_state, "center")
			if i < point_count-1:
				for t_i in range(1, 5):
					draw_vertical_line_to_terrain(point_count*5+t_i+5, river.curve.interpolate(i, float(t_i)/5), river.global_transform.origin, space_state, "center")

		if is_cp_in or is_cp_out:
			for t_i in range(3):
				draw_vertical_line_to_terrain(point_count*5+t_i, lerp(point_pos_in, point_pos, float(t_i)/3), river.global_transform.origin, space_state, "cp")
			for t_i in range(3):
				draw_vertical_line_to_terrain(point_count*5+t_i+3, lerp(point_pos_out, point_pos, float(t_i)/3), river.global_transform.origin, space_state, "cp")
			if i > 0 and editor_plugin.extra_handle_lines:
				var point_pos_prev = river.curve.get_point_position(i-1)
				var point_pos_in_prev = river.curve.get_point_in(i-1) + point_pos_prev
				var point_pos_out_prev = river.curve.get_point_out(i-1) + point_pos_prev
				for t_i in range(0, 6):
					draw_vertical_line_to_terrain(point_count*10+t_i, lerp(point_pos_in_prev, point_pos_out_prev, float(t_i)/5), river.global_transform.origin, space_state, "cp")
			if i < point_count-1 and editor_plugin.extra_handle_lines:
				var point_pos_next = river.curve.get_point_position(i+1)
				var point_pos_in_next = river.curve.get_point_in(i+1) + point_pos_next
				var point_pos_out_next = river.curve.get_point_out(i+1) + point_pos_next
				for t_i in range(0, 6):
					draw_vertical_line_to_terrain(point_count*10+t_i+7, lerp(point_pos_in_next, point_pos_out_next, float(t_i)/5), river.global_transform.origin, space_state, "cp")

		if is_width_left or is_width_right:
			for t_i in range(3):
				draw_vertical_line_to_terrain(point_count*5+t_i, lerp(point_width_pos_left, point_pos, float(t_i)/3), river.global_transform.origin, space_state, "width")
			for t_i in range(3):
				draw_vertical_line_to_terrain(point_count*5+t_i+3, lerp(point_width_pos_right, point_pos, float(t_i)/3), river.global_transform.origin, space_state, "width")

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

	_extra_lines = {}

	redraw(gizmo)

func draw_vertical_line_to_terrain(index, pos, global_pos, space_state, material):
	var worldpos = pos + global_pos
	var result = space_state.intersect_ray(worldpos, worldpos + Vector3.DOWN * 128)
	if not result:
		result = space_state.intersect_ray(worldpos, worldpos + Vector3.UP * 128)
	if result:
		var ground_pos_relative = result.position - global_pos + Vector3(0, abs(result.position.y - global_pos.y)/2, 0)
		var line_length = (pos - ground_pos_relative).length()
		_extra_lines[index] = {}
		_extra_lines[index]["mat"] = material
		_extra_lines[index]["p1"] = pos
		_extra_lines[index]["p2"] = ground_pos_relative
		_extra_lines[index+100000] = {}
		_extra_lines[index+100000]["mat"] = material
		_extra_lines[index+100000]["p1"] = ground_pos_relative - Vector3(1, 0, 0) * line_length * 0.1
		_extra_lines[index+100000]["p2"] = ground_pos_relative + Vector3(1, 0, 0) * line_length * 0.1


func redraw(gizmo: EditorSpatialGizmo) -> void:
	# Work around for issue where using "get_material" doesn't return a
	# material when redraw is being called manually from _set_handle()
	# so I'm caching the materials instead
	if not _path_mat:
		_path_mat = get_material("path", gizmo)
		_path_mat_wd = get_material("path_wd", gizmo)
	if not _handle_control_point_lines_mat:
		_handle_control_point_lines_mat = get_material("handle_control_point_lines", gizmo)
		_handle_control_point_lines_mat_wd = get_material("handle_control_point_lines_wd", gizmo)
	if not _handle_width_lines_mat:
		_handle_width_lines_mat = get_material("handle_width_lines", gizmo)
		_handle_width_lines_mat_wd = get_material("handle_width_lines_wd", gizmo)
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
		path.append(baked_points[i] + HANDLE_OFFSET)
		path.append(baked_points[i + 1] + HANDLE_OFFSET)
	gizmo.add_lines(path, _path_mat)


func _draw_handles(gizmo: EditorSpatialGizmo, river : RiverManager) -> void:
	var handles_center = PoolVector3Array()
	var handles_center_wd = PoolVector3Array()
	var handles_control_points = PoolVector3Array()
	var handles_control_points_wd = PoolVector3Array()
	var handles_width = PoolVector3Array()
	var handles_width_wd = PoolVector3Array()

	var lines_center_extras = PoolVector3Array()
	var lines_control_point = PoolVector3Array()
	var lines_width = PoolVector3Array()
	var point_count = river.curve.get_point_count()
	for i in point_count:
		var point_pos = river.curve.get_point_position(i)
		var point_pos_in = river.curve.get_point_in(i) + point_pos
		var point_pos_out = river.curve.get_point_out(i) + point_pos
		var point_width_pos_right = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.UP).normalized() * river.widths[i]
		var point_width_pos_left = river.curve.get_point_position(i) + river.curve.get_point_out(i).cross(Vector3.DOWN).normalized() * river.widths[i]

		handles_center.push_back(point_pos + HANDLE_OFFSET)
		handles_control_points.push_back(point_pos_in + HANDLE_OFFSET)
		handles_control_points.push_back(point_pos_out + HANDLE_OFFSET)
		handles_width.push_back(point_width_pos_right + HANDLE_OFFSET)
		handles_width.push_back(point_width_pos_left + HANDLE_OFFSET)

		lines.push_back(point_pos)
		lines.push_back(point_pos_in)
		lines.push_back(point_pos)
		lines.push_back(point_pos_out)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_right)
		lines.push_back(point_pos)
		lines.push_back(point_width_pos_left)


	gizmo.add_lines(lines_center_extras, _path_mat)
	gizmo.add_lines(lines_center_extras, _path_mat_wd)
	gizmo.add_lines(lines_control_point, _handle_control_point_lines_mat)
	gizmo.add_lines(lines_control_point, _handle_control_point_lines_mat_wd)
	gizmo.add_lines(lines_width, _handle_width_lines_mat)
	gizmo.add_lines(lines_width, _handle_width_lines_mat_wd)
	gizmo.add_handles(handles_center, get_material("handles_center", gizmo))
	gizmo.add_handles(handles_control_points, get_material("handles_control_points", gizmo))
	gizmo.add_handles(handles_width, get_material("handles_width", gizmo))
	gizmo.add_handles(handles_center, get_material("handles_center_with_depth", gizmo))
	gizmo.add_handles(handles_control_points, get_material("handles_control_points_with_depth", gizmo))
	gizmo.add_handles(handles_width, get_material("handles_width_with_depth", gizmo))
