# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
#const RiverManager = preload("./river_manager.gd")

static func cart2bary(p : Vector3, a : Vector3, b : Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w
	return Vector3(u, v, w)


static func bary2cart(a : Vector3, b : Vector3, c: Vector3, barycentric: Vector3) -> Vector3:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c


static func point_in_bariatric(v : Vector3) -> bool:
	return 0 <= v.x and v.x <= 1 and 0 <= v.y and v.y <= 1 and 0 <= v.z and v.z <= 1;


static func sum_array(array : Array[float]) -> float:
	var sum := 0.0
	for element in array:
			sum += element
	return sum


static func calculate_side(steps : int) -> int:
	var side_float : float = sqrt(steps)
	if fmod(side_float, 1.0) != 0.0:
		side_float += 1.0
	return int(side_float)


static func generate_river_width_values(curve : Curve3D, steps : int, step_length_divs : int, step_width_divs : int, widths : Array[float]) -> Array[float]:
	var river_width_values: Array[float]
	var length := curve.get_baked_length()
	for step in steps * step_length_divs + 1:
		var target_pos := curve.sample_baked((float(step) / float(steps * step_length_divs + 1)) * curve.get_baked_length())
		var closest_dist := 4096.0
		var closest_interpolate : float
		var closest_point : int
		for c_point in curve.get_point_count() - 1:
			for i in 100:
				var interpolate := float(i) / 100.0
				var pos := curve.sample(c_point, interpolate)
				var dist = pos.distance_to(target_pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_interpolate = interpolate
					closest_point = c_point
		river_width_values.append( lerp(widths[closest_point], widths[closest_point + 1], closest_interpolate) )
	
	return river_width_values


static func generate_river_mesh(curve: Curve3D, steps: int, step_length_divs: int, step_width_divs: int, smoothness: float, river_width_values: Array[float]) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve_length := curve.get_baked_length()
	st.set_smooth_group(0)
	
	# Generating the verts
	for step in steps * step_length_divs + 1:
		var position := curve.sample_baked(float(step) / float(steps * step_length_divs) * curve_length, false)
		var backward_pos := curve.sample_baked((float(step) - smoothness) / float(steps * step_length_divs) * curve_length, false)
		var forward_pos := curve.sample_baked((float(step) + smoothness) / float(steps * step_length_divs) * curve_length, false)
		var forward_vector := forward_pos - backward_pos
		var right_vector := forward_vector.cross(Vector3.UP).normalized()
		
		var width_lerp : float = river_width_values[step]
		
		for w_sub in step_width_divs + 1:
			st.set_uv(Vector2(float(w_sub) / (float(step_width_divs)), float(step) / float(step_length_divs) ))
			st.add_vertex(position + right_vector * width_lerp - 2.0 * right_vector * width_lerp * float(w_sub) / (float(step_width_divs)))
	
	# Defining the tris
	for step in steps * step_length_divs:
		for w_sub in step_width_divs:
			st.add_index( (step * (step_width_divs + 1)) + w_sub)
			st.add_index( (step * (step_width_divs + 1)) + w_sub + 1)
			st.add_index( (step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)
			
			st.add_index( (step * (step_width_divs + 1)) + w_sub + 1)
			st.add_index( (step * (step_width_divs + 1)) + w_sub + 3 + step_width_divs - 1)
			st.add_index( (step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)
		
	st.generate_normals()
	st.generate_tangents()
	st.deindex()

	var mesh := ArrayMesh.new()
	var mesh2 :=  ArrayMesh.new()
	var mesh3 := ArrayMesh.new()
	mesh = st.commit()

	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)

	# Generate UV2
	# Decide on grid size
	var grid_side := calculate_side(steps)
	var grid_side_length := 1.0 / float(grid_side)
	var x_grid_sub_length := grid_side_length / float(step_width_divs)
	var y_grid_sub_length := grid_side_length / float(step_length_divs)
	var grid_size := pow(grid_side, 2)
	var index := 0
	var UVs := steps * step_width_divs * step_length_divs * 6
	var x_offset := 0.0
	for x in grid_side:
		var y_offset := 0.0
		for y in grid_side:
		
			if index < UVs:
				var sub_y_offset := 0.0
				for sub_y in step_length_divs:
					var sub_x_offset := 0.0
					for sub_x in step_width_divs:
						var x_comb_offset := x_offset + sub_x_offset
						var y_comb_offset := y_offset + sub_y_offset
						mdt.set_vertex_uv2(index, Vector2(x_comb_offset, y_comb_offset))
						mdt.set_vertex_uv2(index + 1, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset))
						mdt.set_vertex_uv2(index + 2, Vector2(x_comb_offset, y_comb_offset + y_grid_sub_length))
						
						mdt.set_vertex_uv2(index + 3, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset))
						mdt.set_vertex_uv2(index + 4, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset + y_grid_sub_length))
						mdt.set_vertex_uv2(index + 5, Vector2(x_comb_offset, y_comb_offset + y_grid_sub_length))
						index += 6
						sub_x_offset += grid_side_length / float(step_width_divs)
					sub_y_offset += grid_side_length / float(step_length_divs)
			
			y_offset += grid_side_length
		x_offset += grid_side_length
	
	mdt.commit_to_surface(mesh2)
	st.clear()
	st.create_from(mesh2, 0)
	st.index()
	mesh3 = st.commit()
	return mesh3


static func generate_collisionmap(image: Image, mesh_instance: MeshInstance3D, raycast_dist: float, raycast_layers: int, steps: int, step_length_divs: int, step_width_divs: int, river) -> Image:
	var space_state := mesh_instance.get_world_3d().direct_space_state
	
	var uv2 := mesh_instance.mesh.surface_get_arrays(0)[5] as PackedVector2Array
	var verts := mesh_instance.mesh.surface_get_arrays(0)[0] as PackedVector3Array
	# We need to move the verts into world space
	var world_verts := PackedVector3Array()
	for v in verts.size():
		world_verts.append( mesh_instance.global_transform * (verts[v]) )
	
	var tris_in_step_quad := step_length_divs * step_width_divs * 2
	var side := calculate_side(steps)
	var percentage = 0.0
	
	river.emit_signal("progress_notified", percentage, "Calculating Collisions (" + str(image.get_width()) + "x" + str(image.get_width()) + ")")
	await river.get_tree().process_frame
	
	#var ray_params := PhysicsRayQueryParameters3D.create(Vector3(0.0, 5.0, 0.0), Vector3(0.0, 0.0, 0.0), raycast_layers)
	#ray_params_up.collision_mask = raycast_layers
	#var result = space_state.intersect_ray(ray_params)
	
	#print(result)
	
	for x in image.get_width():
		var cur_percentage := float(x) / float(image.get_width())
		if cur_percentage > percentage + 0.1:
			percentage += 0.1
			
			river.emit_signal("progress_notified", percentage, "Calculating Collisions (" + str(image.get_width()) + "x" + str(image.get_width()) + ")")
			await river.get_tree().process_frame
		for y in image.get_height():
			var uv_coordinate := Vector2( ( 0.5 + float(x))  / float(image.get_width()), ( 0.5 + float(y)) / float(image.get_height()) )
			var baryatric_coords : Vector3
			var correct_triangle := []
			
			var pixel := int(x * image.get_width() + y)
			var column := (pixel / image.get_width()) / (image.get_width() / side)
			var row := (pixel % image.get_width()) / (image.get_width() / side)
			var step_quad := column * side + row
				
			if step_quad >= steps:
				break # we are in the empty part of UV2 so we break to the next column
			
			for tris in tris_in_step_quad:
				var offset_tris: int = (tris_in_step_quad * step_quad) + tris
				var triangle := PackedVector2Array()
				triangle.append(uv2[offset_tris * 3])
				triangle.append(uv2[offset_tris * 3 + 1])
				triangle.append(uv2[offset_tris * 3 + 2])
				var p := Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
				var a := Vector3(uv2[offset_tris * 3].x, uv2[offset_tris * 3].y, 0.0)
				var b := Vector3(uv2[offset_tris * 3 + 1].x, uv2[offset_tris * 3 + 1].y, 0.0)
				var c := Vector3(uv2[offset_tris * 3 + 2].x, uv2[offset_tris * 3 + 2].y, 0.0)
				baryatric_coords = cart2bary(p, a, b, c)
				
				if point_in_bariatric(baryatric_coords):
					correct_triangle = [offset_tris * 3, offset_tris * 3 + 1, offset_tris * 3 + 2]
					break # we have the correct triangle so we break out of loop

			if correct_triangle:
				var vert0: Vector3 = world_verts[correct_triangle[0]] 
				var vert1: Vector3 = world_verts[correct_triangle[1]] 
				var vert2: Vector3 = world_verts[correct_triangle[2]]
				
				var real_pos := bary2cart(vert0, vert1, vert2, baryatric_coords)
				var real_pos_up := real_pos + Vector3.UP * raycast_dist

				var ray_params_up := PhysicsRayQueryParameters3D.create(real_pos, real_pos_up, raycast_layers)
				var result_up = space_state.intersect_ray(ray_params_up)

				var ray_params_down := PhysicsRayQueryParameters3D.create(real_pos_up, real_pos, raycast_layers)
				var result_down = space_state.intersect_ray(ray_params_down)

				var up_hit_frontface := false
				if result_up:
					if result_up.normal.y < 0:
						true
				
				if result_up or result_down:
					if not up_hit_frontface and result_down:
						image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	return image


# Adds offset margins so filters will correctly extend across UV edges
static func add_margins(image : Image, resolution : int, margin : int) -> Image:
	var with_margins_size := resolution + 2 * margin
	
	var image_with_margins := Image.create(with_margins_size, with_margins_size, true, Image.FORMAT_RGB8)
	image_with_margins.blend_rect(image, Rect2i(0, resolution - margin, resolution, margin), Vector2i(margin + margin, 0))
	image_with_margins.blend_rect(image, Rect2i(0, 0, resolution, resolution), Vector2i(margin, margin))
	image_with_margins.blend_rect(image, Rect2i(0, 0, resolution, margin), Vector2i(0, resolution + margin))
	
	return image_with_margins
