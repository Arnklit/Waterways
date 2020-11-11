tool
extends MeshInstance


export(bool) var generate := false setget set_generate

export(Texture) var generated_texture



func set_generate(value : bool) -> void:
	generate_tex()


func generate_tex() -> void:
	var imageTexture := ImageTexture.new()
	var image := Image.new()
	image.create(256, 256, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 1.0, 0.0))
	
	var space_state = get_world().direct_space_state
	for x in image.get_width():
		for y in image.get_height():
			# Get the world position of texture position.
			
			pass
			
	var result = space_state.intersect_ray(Vector3(0, 0, 0), Vector3(50, 100, 50))
	if result:
		pass
	
	imageTexture.create_from_image(image, Texture.FLAG_CONVERT_TO_LINEAR)
	generated_texture = imageTexture
	generated_texture.set_flags(Texture.FLAGS_DEFAULT + Texture.FLAG_CONVERT_TO_LINEAR)
	mesh.material.set_texture(0, generated_texture)

	
