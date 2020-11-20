extends EditorSpatialGizmo

# not implemented yet
var _snap_to_colliders : bool = false

func set_handle(index, camera, point):
	var polygon_path = get_spatial_node()
	#var ray_hit_pos = common.intersect_with(polygon_path, camera, point)
	var ray_hit_pos # somthing else
	if not ray_hit_pos:
		return
	var local_pos = polygon_path.to_local(ray_hit_pos)
	var count = polygon_path.curve.get_point_count()
	if index < count:
		polygon_path.set_point_position(index, local_pos)
	else:
		var align_handles = Input.is_key_pressed(KEY_SHIFT)
		var i = (index - count)
		var p_index = int(i / 2)
		var base = polygon_path.curve.get_point_position(p_index)
		if i % 2 == 0:
			polygon_path.set_point_in(p_index, local_pos - base)
			if align_handles:
				polygon_path.set_point_out(p_index, -(local_pos - base))
		else:
			polygon_path.set_point_out(p_index, local_pos - base)
			if align_handles:
				polygon_path.set_point_in(p_index, -(local_pos - base))
	redraw()


func redraw():
	clear()
	var polygon_path = get_spatial_node()
	_draw_path(polygon_path.curve)
	_draw_handles(polygon_path.curve)


func _draw_path(curve):
	var path = PoolVector3Array()
	var points = curve.get_baked_points()
	var size = points.size() - 1
	
	for i in range(size ):
		path.append(points[i])
		path.append(points[i + 1])
	
	add_lines(path, get_plugin().get_material("path", self), false)


func _draw_handles(curve):
	var handles = PoolVector3Array()
	var square_handles = PoolVector3Array()
	var lines = PoolVector3Array()
	var count = curve.get_point_count()
	if count == 0:
		return
	for i in range(count):
		var point_pos = curve.get_point_position(i)
		var point_in = curve.get_point_in(i) + point_pos
		var point_out = curve.get_point_out(i) + point_pos

		lines.push_back(point_pos)
		lines.push_back(point_in)
		lines.push_back(point_pos)
		lines.push_back(point_out)
		
		square_handles.push_back(point_in)
		square_handles.push_back(point_out)
		handles.push_back(point_pos)
		
	add_handles(handles, get_plugin().get_material("handles", self))
	add_handles(square_handles, get_plugin().get_material("square", self))
	add_lines(lines, get_plugin().get_material("handle_lines", self))
