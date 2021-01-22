# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Viewport

const HEIGHT_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_height.shader"
const FLOW_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_flow.shader"
const ALPHA_SHADER_PATH = "res://addons/waterways/shaders/system_renders/alpha.shader"

var _camera : Camera
var _container : Spatial

func grab_height(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera
	_container = $Container
	
	var height_mat = ShaderMaterial.new()
	var height_shader := load(HEIGHT_SHADER_PATH) as Shader
	height_mat.shader = height_shader
	height_mat.set_shader_param("lower_bounds", aabb.position.y)
	height_mat.set_shader_param("upper_bounds", aabb.end.y)
	
	for object in water_objects:
		var water_mesh_copy = object.mesh_instance.duplicate(true)
		_container.add_child(water_mesh_copy)
		water_mesh_copy.transform = object.transform
		water_mesh_copy.material_override = height_mat
	
	var longest_axis := aabb.get_longest_axis_index()
	match longest_axis:
		Vector3.AXIS_X:
			_camera.translation = aabb.position + Vector3(aabb.size.x / 2.0, aabb.size.y + 1.0, aabb.size.x / 2.0)
		Vector3.AXIS_Y:
			# TODO
			# This shouldn't happen, we might need some code to handle if it does
			pass
		Vector3.AXIS_Z:
			_camera.translation = aabb.position + Vector3(aabb.size.z / 2.0, aabb.size.y + 1.0, aabb.size.z / 2.0)
	
	_camera.size = aabb.get_longest_axis_size()
	_camera.far = aabb.size.y + 2.0
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	var height := get_texture().get_data()
	var height_result := ImageTexture.new()
	height_result.create_from_image(height)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return height_result


func grab_alpha(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera
	_container = $Container
	
	var alpha_mat = ShaderMaterial.new()
	var alpha_shader := load(ALPHA_SHADER_PATH) as Shader
	alpha_mat.shader = alpha_shader
	
	for object in water_objects:
		var water_mesh_copy = object.mesh_instance.duplicate(true)
		_container.add_child(water_mesh_copy)
		water_mesh_copy.transform = object.transform
		water_mesh_copy.material_override = alpha_mat
	
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
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	var alpha := get_texture().get_data()
	var alpha_result := ImageTexture.new()
	alpha_result.create_from_image(alpha)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return alpha_result


func grab_flow(water_objects, aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera
	_container = $Container
	
	var flow_mat = ShaderMaterial.new()
	var flow_shader := load(FLOW_SHADER_PATH) as Shader
	flow_mat.shader = flow_shader

	for i in water_objects.size():
		var water_mesh_copy = water_objects[i].mesh_instance.duplicate(true)
		_container.add_child(water_mesh_copy)
		water_mesh_copy.transform = water_objects[i].transform
		water_mesh_copy.material_override = flow_mat
		water_mesh_copy.material_override.set_shader_param("flowmap", water_objects[i].flow_foam_noise)
		water_mesh_copy.material_override.set_shader_param("distmap", water_objects[i].dist_pressure)
		water_mesh_copy.material_override.set_shader_param("flow_base", water_objects[i].get_shader_param("flow_base"))
		water_mesh_copy.material_override.set_shader_param("flow_steepness", water_objects[i].get_shader_param("flow_steepness"))
		water_mesh_copy.material_override.set_shader_param("flow_distance", water_objects[i].get_shader_param("flow_distance"))
		water_mesh_copy.material_override.set_shader_param("flow_pressure", water_objects[i].get_shader_param("flow_pressure"))
		water_mesh_copy.material_override.set_shader_param("flow_max", water_objects[i].get_shader_param("flow_max"))
		water_mesh_copy.material_override.set_shader_param("valid_flowmap", water_objects[i].get_shader_param("i_valid_flowmap"))
	
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
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	var flow := get_texture().get_data()
	var flow_result := ImageTexture.new()
	flow_result.create_from_image(flow)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return flow_result
