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
	image.create(256, 256, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	image.lock()
	var space_state := get_world().direct_space_state
	for x in image.get_width():
		for y in image.get_height():
			# Get the world position of texture position.
			# We might have to get the array of UVs, then find out which UV tri
			# a given point belongs to, then figure out how far between those
			# points it is and then use that to find the location on the mesh
			# .... YUCK
			
			var world_pos = Vector3( (float(x) / 256.0) - .5, 0.0, (float(y) / 256.0) - .5)
			var world_pos_up = Vector3( (float(x) / 256.0) - .5, 10.0, (float(y) / 256.0) - .5)
			var result_up = space_state.intersect_ray(world_pos, world_pos_up)
			var result_down = space_state.intersect_ray(world_pos_up, world_pos)
			
			if result_up or result_down:
				if not result_up and result_down:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	image.unlock()
	
#	var shape := ConcavePolygonShape.new()
#	shape.set_faces(mesh.surface_get_arrays(0))
#
#	var physics_shape := PhysicsShapeQueryParameters.new()
#	physics_shape.set_shape(shape)
#	var result = space_state.intersect_shape(physics_shape, 128)
	
	imageTexture.create_from_image(image, Texture.FLAG_CONVERT_TO_LINEAR)
	generated_texture = imageTexture
	generated_texture.set_flags(Texture.FLAGS_DEFAULT + Texture.FLAG_CONVERT_TO_LINEAR)
	mesh.material.set_texture(0, generated_texture)

