tool
extends Node

var _camera : Camera
var _viewport : Viewport


func grab_height(river, resolution : float) -> ImageTexture:
	print("in grab height")
	
	_viewport = Viewport.new()
	_viewport.size = Vector2(resolution, resolution)
	_viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	_viewport.world = World.new()
	_viewport.own_world = true
	_viewport.transparent_bg = false
	
	var river_copy = river.duplicate(true)

	_viewport.add_child(river_copy)
	
	_camera = Camera.new()
	_camera.projection = Camera.PROJECTION_ORTHOGONAL
	_camera.size = 100.0
	_camera.near = 0.1
	_camera.far = 100.0
	_camera.current = true
	_camera.rotation_degrees = Vector3(-90, 0, 0)
	_camera.translation = Vector3(0.0, 50.0, 0.0)
	_viewport.add_child(_camera)
	
	add_child(_viewport)
	
	_viewport.update_worlds()
	
	# we should be able to do something better here. not sure how to get tree though
	yield(river.get_tree(), "idle_frame")
	yield(river.get_tree(), "idle_frame")
	
	var image := _viewport.get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result
