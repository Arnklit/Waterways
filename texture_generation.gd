tool
extends MeshInstance


export(bool) var generate := false setget set_generate

export(Texture) var generated_texture


func set_generate(value : bool) -> void:
	generate_tex()


func generate_tex() -> void:
	var _mdt := MeshDataTool.new()
	var imageTexture := ImageTexture.new()
	var image := Image.new()
	image.create(4, 4, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	image.lock()
	var space_state := get_world().direct_space_state
	var uv1 := mesh.surface_get_arrays(0)[4] as PoolVector2Array
	var verts := mesh.surface_get_arrays(0)[0] as PoolVector3Array
	# We need to move the verts into world space
	var world_verts : PoolVector3Array = []
	for v in verts.size():
		world_verts.append( transform.xform(verts[v]) )
	#print("uv1" + str(uv1))
	#print("verts" + str(verts))
	#print("world_verts" + str(world_verts))
	
	for x in image.get_width():
		for y in image.get_height():
			var uv_coordinate := Vector2( ( 0.5 + float(x))  / float(image.get_width()), ( 0.5 + float(y)) / float(image.get_height()) )
			
			var correct_triangle := []
			var triangle_distances := []
			for tris in uv1.size() / 3:
				print("tris is: " + str(tris))
				var triangle : PoolVector2Array = []
				triangle.append(uv1[tris * 3])
				triangle.append(uv1[tris * 3 + 1])
				triangle.append(uv1[tris * 3 + 2])
				print("triangle is: " + str(triangle))
				if Geometry.is_point_in_polygon(uv_coordinate, triangle):
					correct_triangle = [tris, tris + 1, tris + 2]
					triangle_distances.append(uv_coordinate.distance_to(uv1[tris]))
					triangle_distances.append(uv_coordinate.distance_to(uv1[tris + 1]))
					triangle_distances.append(uv_coordinate.distance_to(uv1[tris + 2]))
					break
			print("uv coordinate is" + str(uv_coordinate))
			print("correct tri is: " + str(correct_triangle))
			print("triangle distances is: " + str( triangle_distances ))
			
			var combined_dists = triangle_distances[0] + triangle_distances[1] + triangle_distances[2]
			var weight0 = combined_dists / triangle_distances[0]
			var weight1 = combined_dists / triangle_distances[1]
			var weight2 = combined_dists / triangle_distances[2]
			var combined_weight = weight0 + weight1 + weight2
			print("weight0: " + str(weight0 / combined_weight))
			print("weight1: " + str(weight1 / combined_weight))
			print("weight2: " + str(weight2 / combined_weight))
			print("combined weight: " + str(combined_weight))
			var vert0 = world_verts[correct_triangle[0]] * (weight0 / combined_weight)
			var vert1 = world_verts[correct_triangle[1]] * (weight1 / combined_weight)
			var vert2 = world_verts[correct_triangle[2]] * (weight2 / combined_weight)
			var real_pos = (vert0 + vert1 + vert2)
			print("real_pos is: " + str(real_pos))
			var real_pos_up = real_pos + Vector3.UP * 10.0
			print("real_pos_up is: " + str(real_pos_up))
			
			#var world_pos = Vector3( (float(x) / 256.0) - .5, 0.0, (float(y) / 256.0) - .5)
			#var world_pos_up = Vector3( (float(x) / 256.0) - .5, 10.0, (float(y) / 256.0) - .5)

			var result_up = space_state.intersect_ray(real_pos, real_pos_up)
			var result_down = space_state.intersect_ray(real_pos_up, real_pos)
			
			if result_up or result_down:
				if not result_up and result_down:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	image.unlock()
	
	imageTexture.create_from_image(image, Texture.FLAG_CONVERT_TO_LINEAR)
	generated_texture = imageTexture
	generated_texture.set_flags(Texture.FLAGS_DEFAULT + Texture.FLAG_CONVERT_TO_LINEAR)
	mesh.material.set_texture(0, generated_texture)

