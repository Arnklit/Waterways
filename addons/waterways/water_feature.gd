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

# Internal
var _material: ShaderMaterial
var _debug_material: ShaderMaterial
var _filter_renderer: PackedScene
var _steps := 2
var _first_enter_tree := true
var _uv2_sides: int

signal feature_changed
signal progress_notified


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
