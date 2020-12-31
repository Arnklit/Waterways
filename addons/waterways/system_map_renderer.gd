tool
extends Viewport

var _camera : Camera


func grab_height(water_objects, resolution : float) -> ImageTexture:
	print("in grab height")
	
	_camera = $Camera
	
	render_target_update_mode = Viewport.UPDATE_ONCE
	#var aabb = water_objects[0].get_AABB()
	#print(aabb)

	add_child(water_objects[0].duplicate(true))
	
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	var result := ImageTexture.new()
	result.create_from_image(get_texture().get_data())
	
	return result
