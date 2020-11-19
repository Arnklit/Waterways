extends Spatial

# Setting up a node with it's own Curve and custom editor to use 
# instead of being a child of a Path object 

var curve : Curve3D

func add_point(position):
	if not curve:
		curve = Curve3D.new()
	
	curve.add_point(position)
	var current_index = curve.get_point_count() - 1
	var previous_index = current_index - 1
	if previous_index < 0:
		curve.set_point_in(current_index, Vector3(-1.0, 0.0, 0.0))
		curve.set_point_out(current_index, Vector3(1.0, 0.0, 0.0))
		return
	
	var dir = position - curve.get_point_position(previous_index)
	var dir_out = dir.normalized()
	var dir_in = -dir.normalized()
	
	curve.set_point_in(current_index, dir_in)
	curve.set_point_out(current_index, dir_out)


func remove_point(index):
	if index > curve.get_point_count() - 1:
		return
	curve.remove_point(index)


func set_point_position(index, pos):
	curve.set_point_position(index, pos)


func get_closest_to(pos):
	var closest = -1
	var dist_squared = -1
	
	for i in range(0, curve.get_point_count()):
		var point_pos = curve.get_point_position(i)
		var point_dist = point_pos.distance_squared_to(pos)
		
		if (closest == -1) or (dist_squared > point_dist):
			closest = i
			dist_squared = point_dist
	
	var threshold = 16 # Ignore if the closest point is farther than this
	if dist_squared >= threshold:
		return -1
	
	return closest


func remove_closest_to(pos):
	# Ignore if there's no point in the curve 
	if curve.get_point_count() == 0:
		return
	var closest = get_closest_to(pos)
	remove_point(closest)
