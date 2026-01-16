@tool
extends Node3D

const WaterHelperMethods = preload("./water_helper_methods.gd")
const Constants = preload("./consts.gd")

const BASE_DEFAULT_PARAMETERS = {
	mat_shader_type = 0,
	mat_custom_shader = null,
	baking_resolution = 2,
	baking_raycast_distance = 10.0,
	baking_raycast_layers = 1,
	baking_dilate = 0.6,
	baking_flowmap_blur = 0.04,
	baking_foam_cutoff = 0.9,
	baking_foam_offset = 0.1,
	baking_foam_blur = 0.02,
}

# Bake Properties
var baking_resolution: int = 2
var baking_raycast_distance: float = 10.0
var baking_raycast_layers: int = 1
var baking_dilate: float = 0.6
var baking_flowmap_blur: float = 0.04
var baking_foam_cutoff: float = 0.9
var baking_foam_offset: float = 0.1
var baking_foam_blur: float = 0.02

# Flowmap state
var valid_flowmap := false
var flow_foam_noise: Texture2D
var dist_pressure: Texture2D

# Material/Debug
var debug_view: int = 0:
	set = set_debug_view
var mat_shader_type: Constants.SHADER_TYPES:
	set = set_shader_type
var mat_custom_shader: Shader:
	set = set_custom_shader

# Internal
var _material: ShaderMaterial
var _debug_material: ShaderMaterial
var _filter_renderer: PackedScene
var _steps := 2
var _first_enter_tree := true
var _uv2_sides: int

signal feature_changed
signal progress_notified


func get_mesh_instance() -> MeshInstance3D:
	assert(false, "Subclass must implement get_mesh_instance()")
	return null


func set_materials(param: String, value) -> void:
	_material.set_shader_parameter(param, value)
	_debug_material.set_shader_parameter(param, value)


func set_debug_view(index: int) -> void:
	debug_view = index
	var mi := get_mesh_instance()
	if mi == null:
		return
	if index == 0:
		mi.material_override = null
	else:
		_debug_material.set_shader_parameter("mode", index)
		mi.material_override = _debug_material


func set_shader_type(type: int) -> void:
	if type == mat_shader_type:
		return
	mat_shader_type = type

	if mat_shader_type == Constants.SHADER_TYPES.CUSTOM:
		_material.shader = mat_custom_shader
	else:
		_material.shader = load(Constants.BUILTIN_SHADERS[mat_shader_type].shader_path)
		for texture in Constants.BUILTIN_SHADERS[mat_shader_type].texture_paths:
			_material.set_shader_parameter(texture.name, load(texture.path) as Texture)

	notify_property_list_changed()


func set_custom_shader(shader: Shader) -> void:
	if mat_custom_shader == shader:
		return
	mat_custom_shader = shader
	if mat_custom_shader != null:
		_material.shader = mat_custom_shader

		if Engine.is_editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				var selected_shader = load(Constants.BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
				shader.code = selected_shader.code

	if shader != null:
		set_shader_type(Constants.SHADER_TYPES.CUSTOM)
	else:
		set_shader_type(Constants.SHADER_TYPES.WATER)


func _set(property: StringName, value) -> bool:
	if str(property).begins_with("mat_"):
		var param_name: String = str(property).replace("mat_", "")
		_material.set_shader_parameter(param_name, value)
		return true
	return false


func _get(property: StringName):
	if str(property).begins_with("mat_"):
		var param_name: String = str(property).replace("mat_", "")
		return _material.get_shader_parameter(param_name)


func _property_can_revert(property: StringName) -> bool:
	if str(property).begins_with("mat_"):
		var param_name: String = str(property).replace("mat_", "")
		return _material.property_can_revert(str("shader_parameter/", param_name))
	if BASE_DEFAULT_PARAMETERS.has(property):
		return get(property) != BASE_DEFAULT_PARAMETERS[property]
	return false


func _property_get_revert(property: StringName):
	if str(property).begins_with("mat_"):
		var param_name: String = str(property).replace("mat_", "")
		return _material.property_get_revert(str("shader_parameter/", param_name))
	if BASE_DEFAULT_PARAMETERS.has(property):
		return BASE_DEFAULT_PARAMETERS[property]
	return null
