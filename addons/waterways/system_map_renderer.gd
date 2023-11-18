# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport

const HEIGHT_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_height.gdshader"
const FLOW_SHADER_PATH = "res://addons/waterways/shaders/system_renders/system_flow.gdshader"
const ALPHA_SHADER_PATH = "res://addons/waterways/shaders/system_renders/alpha.gdshader"
const RiverManager = preload("./river_manager.gd")

var _camera: Camera3D
var _container: Node3D

func grab_height(water_objects: Array[RiverManager], aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera3D as Camera3D
	_container = $Container as Node3D
	
	var height_mat := ShaderMaterial.new()
	var height_shader := load(HEIGHT_SHADER_PATH) as Shader
	height_mat.shader = height_shader
	height_mat.set_shader_parameter("lower_bounds", aabb.position.y)
	height_mat.set_shader_parameter("upper_bounds", aabb.end.y)
	
	for object in water_objects:
		var water_mesh_copy := object.mesh_instance.duplicate(true)
		_container.add_child(water_mesh_copy)
		water_mesh_copy.transform = object.transform # TODO - This seems unneeded?
		water_mesh_copy.material_override = height_mat
	
	var longest_axis := aabb.get_longest_axis_index()
	match longest_axis:
		Vector3.AXIS_X:
			_camera.position = aabb.position + Vector3(aabb.size.x / 2.0, aabb.size.y + 1.0, aabb.size.x / 2.0)
		Vector3.AXIS_Y:
			# TODO
			# This shouldn't happen, we might need some code to handle if it does
			pass
		Vector3.AXIS_Z:
			_camera.position = aabb.position + Vector3(aabb.size.z / 2.0, aabb.size.y + 1.0, aabb.size.z / 2.0)
	
	_camera.size = aabb.get_longest_axis_size()
	_camera.far = aabb.size.y + 2.0
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var height : Image = get_texture().get_image()
	var height_result := ImageTexture.create_from_image(height)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return height_result


func grab_alpha(water_objects: Array[RiverManager], aabb: AABB, resolution: float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera3D as Camera3D
	_container = $Container as Node3D
	
	var alpha_mat := ShaderMaterial.new()
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
			_camera.position = aabb.position + Vector3(aabb.size.x / 2.0, aabb.size.y + 1.0, aabb.size.x / 2.0)
		Vector3.AXIS_Y:
			# This shouldn't happen, we might need some code to handle if it does
			pass
		Vector3.AXIS_Z:
			_camera.position = aabb.position + Vector3(aabb.size.z / 2.0, aabb.size.y + 1.0, aabb.size.z / 2.0)
	
	_camera.size = aabb.get_longest_axis_size()
	_camera.far = aabb.size.y + 2.0
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var alpha : Image = get_texture().get_image()
	var alpha_result := ImageTexture.create_from_image(alpha)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return alpha_result


func grab_flow(water_objects: Array[RiverManager], aabb : AABB, resolution : float) -> ImageTexture:
	size = Vector2(resolution, resolution)
	_camera = $Camera3D as Camera3D
	_container = $Container as Node3D
	

	for i in water_objects.size():
		var flow_mat := ShaderMaterial.new()
		var flow_shader := load(FLOW_SHADER_PATH) as Shader
		flow_mat.shader = flow_shader
		flow_mat.set_shader_parameter("flowmap", water_objects[i].flow_foam_noise)
		flow_mat.set_shader_parameter("distmap", water_objects[i].dist_pressure)
		flow_mat.set_shader_parameter("flow_base", water_objects[i].get_shader_parameter("flow_base"))
		flow_mat.set_shader_parameter("flow_steepness", water_objects[i].get_shader_parameter("flow_steepness"))
		flow_mat.set_shader_parameter("flow_distance", water_objects[i].get_shader_parameter("flow_distance"))
		flow_mat.set_shader_parameter("flow_pressure", water_objects[i].get_shader_parameter("flow_pressure"))
		flow_mat.set_shader_parameter("flow_max", water_objects[i].get_shader_parameter("flow_max"))
		flow_mat.set_shader_parameter("valid_flowmap", water_objects[i].get_shader_parameter("i_valid_flowmap"))
		flow_mat.set_shader_parameter("uv2_sides", water_objects[i].get_shader_parameter("i_uv2_sides"))
				
		var water_mesh_copy := water_objects[i].mesh_instance.duplicate(true)
		_container.add_child(water_mesh_copy)
		water_mesh_copy.transform = water_objects[i].transform
		water_mesh_copy.material_override = flow_mat
	
	var longest_axis := aabb.get_longest_axis_index()
	match longest_axis:
		Vector3.AXIS_X:
			_camera.position = aabb.position + Vector3(aabb.size.x / 2.0, aabb.size.y + 1.0, aabb.size.x / 2.0)
		Vector3.AXIS_Y:
			# This shouldn't happen, we might need some code to handle if it does - TODO
			pass
		Vector3.AXIS_Z:
			_camera.position = aabb.position + Vector3(aabb.size.z / 2.0, aabb.size.y + 1.0, aabb.size.z / 2.0)
	
	_camera.size = aabb.get_longest_axis_size()
	_camera.far = aabb.size.y + 2.0
	
	render_target_clear_mode = CLEAR_MODE_ALWAYS
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var flow : Image = get_texture().get_image()
	var flow_result := ImageTexture.create_from_image(flow)
	
	for child in _container.get_children():
		_container.remove_child(child)
	
	return flow_result
