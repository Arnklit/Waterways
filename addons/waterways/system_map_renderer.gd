tool
extends Viewport

const HEIGHT_SHADER_PATH = "res://addons/waterways/shaders/system_renders/height.shader"

var _camera : Camera


func grab_height(water_objects, resolution : float) -> ImageTexture:
	print("in grab height")
	size = Vector2(resolution, resolution)
	
	_camera = $Camera
	var water_mesh_copy : MeshInstance = water_objects[0].mesh_instance.duplicate(true)
	add_child(water_mesh_copy)
	var height_mat = ShaderMaterial.new()
	height_mat.shader = load(HEIGHT_SHADER_PATH) as Shader
	
	water_mesh_copy.material_override = height_mat
	
	render_target_update_mode = Viewport.UPDATE_ONCE
	var aabb : AABB = water_mesh_copy.get_transformed_aabb()
	height_mat.set_shader_param("lower_bounds", aabb.position.y)
	height_mat.set_shader_param("upper_bounds", aabb.end.y)
	
	var longest_axis := aabb.get_longest_axis_index()
	match longest_axis:
		Vector3.AXIS_X:
			_camera.translation = aabb.position + Vector3(aabb.size.x / 2.0, aabb.size.y + 1.0, aabb.size.x / 2.0)
		Vector3.AXIS_Y:
			# This shouldn't happen, we might need some code to handle if it does
			pass
		Vector3.AXIS_Z:
			_camera.translation = aabb.position + Vector3(aabb.size.z / 2.0, aabb.size.y + 1.0, aabb.size.z / 2.0)
	
	_camera.size = aabb.get_longest_axis_size()
	_camera.far = aabb.size.y + 2.0
	
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	water_mesh_copy.material_override = null
	
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	
	return result
