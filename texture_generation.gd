tool
extends MeshInstance


export(bool) var generate := false setget set_generate

export(Texture) var generated_texture


func set_generate(value : bool) -> void:
	generate_tex()


# top answer - https://gamedev.stackexchange.com/questions/23743/whats-the-most-efficient-way-to-find-barycentric-coordinates
func cart2bary(p : Vector3, a : Vector3, b : Vector3, c: Vector3) -> Vector3:
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

func bary2cart(a : Vector3, b : Vector3, c: Vector3, barycentric: Vector3) -> Vector3:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c


func generate_tex() -> void:
	var _mdt := MeshDataTool.new()
	var imageTexture := ImageTexture.new()
	var image := Image.new()
	image.create(256, 256, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	image.lock()
	var space_state := get_world().direct_space_state
	var uv1 := mesh.surface_get_arrays(0)[4] as PoolVector2Array
	var verts := mesh.surface_get_arrays(0)[0] as PoolVector3Array
	# We need to move the verts into world space
	var world_verts : PoolVector3Array = []
	for v in verts.size():
		world_verts.append( global_transform.xform(verts[v]) )
	#print("uv1" + str(uv1))
	#print("verts" + str(verts))
	#print("world_verts" + str(world_verts))
	
	for x in image.get_width():
		for y in image.get_height():
			#print("**************NEW*PIXEL**************")
			var uv_coordinate := Vector2( ( 0.5 + float(x))  / float(image.get_width()), ( 0.5 + float(y)) / float(image.get_height()) )
			
			var baryatric_coords
			
			var correct_triangle := []
			for tris in uv1.size() / 3:
				#print("tris is: " + str(tris))
				var triangle : PoolVector2Array = []
				triangle.append(uv1[tris * 3])
				triangle.append(uv1[tris * 3 + 1])
				triangle.append(uv1[tris * 3 + 2])
				#print("triangle is: " + str(triangle))
				if Geometry.is_point_in_polygon(uv_coordinate, triangle):
					var p = Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
					var a = Vector3(uv1[tris * 3].x, uv1[tris * 3].y, 0.0)
					var b = Vector3(uv1[tris * 3 + 1].x, uv1[tris * 3 + 1].y, 0.0)
					var c = Vector3(uv1[tris * 3 + 2].x, uv1[tris * 3 + 2].y, 0.0)
					baryatric_coords = cart2bary(p, a, b, c)
					correct_triangle = [tris * 3, tris * 3 + 1, tris * 3 + 2]
					#print("baryatric coords: " + str(baryatric_coords))
					break
			#print("uv coordinate is" + str(uv_coordinate))
			#print("correct tri is: " + str(correct_triangle))
			
			var vert0 = world_verts[correct_triangle[0]] 
			var vert1 = world_verts[correct_triangle[1]] 
			var vert2 = world_verts[correct_triangle[2]]
			
			#print("vert0: " + str(vert0) + ", vert1: " + str(vert1) + ", vert2: " + str(vert2))
			
			var real_pos = bary2cart(vert0, vert1, vert2, baryatric_coords)
			#print("real_pos is: " + str(real_pos))
			var real_pos_up = real_pos + Vector3.UP * 10.0
			#print("real_pos_up is: " + str(real_pos_up))
			
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

