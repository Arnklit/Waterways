# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterHelperMethods = preload("./water_helper_methods.gd")

const DEFAULT_SHADER_PATH = "res://addons/waterways/shaders/river.shader"
const DEFAULT_WATER_TEXTURE_PATH = "res://addons/waterways/textures/water1.png"
const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"
const NOISE_TEXTURE_PATH = "res://addons/waterways/textures/noise.png"
const DEBUG_SHADER_PATH = "res://addons/waterways/shaders/river_debug.shader"
const DEBUG_PATTERN_PATH = "res://addons/waterways/textures/debug_pattern.png"
const DEBUG_ARROW_PATH = "res://addons/waterways/textures/debug_arrow.svg"

const DEFAULT_PARAMETERS = {
	shape_step_length_divs = 1,
	shape_step_width_divs = 1,
	shape_smoothness = 0.5,
	mat_uv_tiling = Vector2(1.0, 1.0),
	mat_normal_scale = 1.0,
	mat_clarity = 10.0,
	mat_edge_fade = 0.25,
	mat_albedo = PoolColorArray([Color(0.25, 0.25, 0.70), Color(0.35, 0.25, 0.25)]),
	mat_gradient_depth = 10.0,
	mat_roughness = 0.2,
	mat_refraction = 0.05,
	mat_flow_speed = 1.0,
	mat_flow_base_strength = 0.0,
	mat_flow_steepness_strength = 2.0,
	mat_flow_distance_strength = 1.0,
	mat_flow_pressure_strength = 1.0,
	mat_flow_max_strength = 4.0,
	mat_foam_albedo = Color(0.9, 0.9, 0.9, 1.0),
	mat_foam_amount = 2.0,
	mat_foam_steepness = 2.0,
	mat_foam_smoothness = 0.3,
	lod_lod0_distance = 50.0,
	baking_resolution = 2, 
	baking_raycast_distance = 10.0,
	baking_raycast_layers = 1,
	baking_dilate = 0.6,
	baking_flowmap_blur = 0.04,
	baking_foam_cutoff = 0.9,
	baking_foam_offset = 0.1,
	baking_foam_blur = 0.02,
	adv_custom_shader = null
}

# Shape Properties
var shape_step_length_divs := 1 setget set_step_length_divs
var shape_step_width_divs := 1 setget set_step_width_divs
var shape_smoothness := 0.5 setget set_smoothness

# Material Properties
var mat_texture : Texture setget set_texture
var mat_uv_scale := Vector3(1.0, 1.0, 1.0) setget set_uv_scale
var mat_normal_scale := 1.0 setget set_normal_scale
var mat_clarity := 10.0 setget set_clarity
var mat_edge_fade := 0.25 setget set_edge_fade
var mat_albedo := PoolColorArray([Color(0.25, 0.25, 0.70), Color(0.35, 0.25, 0.25)]) setget set_albedo
var mat_gradient_depth := 10.0 setget set_gradient_depth
var mat_roughness := 0.2 setget set_roughness
var mat_refraction := 0.05 setget set_refraction
var mat_flow_speed := 1.0 setget set_flowspeed
var mat_flow_base_strength := 0.0 setget set_flow_base
var mat_flow_steepness_strength := 2.0 setget set_flow_steepness
var mat_flow_distance_strength := 1.0 setget set_flow_distance
var mat_flow_pressure_strength := 1.0 setget set_flow_pressure
var mat_flow_max_strength := 4.0 setget set_flow_max
var mat_foam_albedo := Color(0.9, 0.9, 0.9, 1.0) setget set_foam_albedo
var mat_foam_amount := 2.0 setget set_foam_amount
var mat_foam_steepness := 2.0 setget set_foam_steepness
var mat_foam_smoothness := 0.3 setget set_foam_smoothness

# LOD Properties
var lod_lod0_distance := 50.0 setget set_lod0_distance

# Bake Properties
var baking_resolution := 2
var baking_raycast_distance := 10.0
var baking_raycast_layers := 1
var baking_dilate := 0.6
var baking_flowmap_blur := 0.04
var baking_foam_cutoff := 0.9
var baking_foam_offset := 0.1
var baking_foam_blur := 0.02

# Advanced Properties
var adv_custom_shader : Shader setget set_custom_shader

# Public variables
var curve : Curve3D
var widths := [] setget set_widths
var valid_flowmap := false
var debug_view := 0 setget set_debug_view
var mesh_instance : MeshInstance

# Private variables
var _steps := 2
var _st : SurfaceTool
var _mdt : MeshDataTool
var _default_shader : Shader
var _debug_shader : Shader
var _material : ShaderMaterial
var _debug_material : ShaderMaterial
var _first_enter_tree := true
var _filter_renderer
var _flow_foam_noise : Texture
var _dist_pressure : Texture

# river_changed used to update handles when values are changed on script side
# progress_notified used to up progress bar when baking maps
# albedo_set is needed since the gradient is a custom inspector that needs a signal to update from script side
signal river_changed
signal progress_notified
signal albedo_set

# Internal Methods
func _get_property_list() -> Array:
	return [
		{
			name = "Shape",
			type = TYPE_NIL,
			hint_string = "shape_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_step_length_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_step_width_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_smoothness",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_texture",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture"
		},
		{
			name = "mat_uv_scale",
			type = TYPE_VECTOR3,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_normal_scale",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-16.0, 16.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_albedo",
			type = TYPE_COLOR_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_gradient_depth",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 200.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_clarity",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 200.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_edge_fade",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_roughness",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_refraction",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-1.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material/Flow",
			type = TYPE_NIL,
			hint_string = "mat_flow_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_speed",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 10.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_base_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_steepness_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_distance_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_pressure_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_flow_max_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material/Foam",
			type = TYPE_NIL,
			hint_string = "mat_foam_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_foam_albedo",
			type = TYPE_COLOR,
			hint = PROPERTY_HINT_COLOR_NO_ALPHA,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_foam_amount",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 4.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_foam_steepness",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 8.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_foam_smoothness",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Lod",
			type = TYPE_NIL,
			hint_string = "lod_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "lod_lod0_distance",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "5.0, 200.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Baking",
			type = TYPE_NIL,
			hint_string = "baking_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "64, 128, 256, 512, 1024",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_raycast_distance",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},		
		{
			name = "baking_raycast_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_dilate",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_flowmap_blur",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_cutoff",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_offset",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "baking_foam_blur",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Advanced",
			type = TYPE_NIL,
			hint_string = "adv_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "adv_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		},
		# Serialize these values without exposing it in the inspector
		{
			name = "curve",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "widths",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_flow_foam_noise",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_dist_pressure",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "valid_flowmap",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


func property_can_revert(p_name: String) -> bool:
	if not DEFAULT_PARAMETERS.has(p_name):
		return false
	if get(p_name) != DEFAULT_PARAMETERS[p_name]:
		return true
	return false


func property_get_revert(p_name: String): # returns variant
	return DEFAULT_PARAMETERS[p_name]


func _init() -> void:
	_default_shader = load(DEFAULT_SHADER_PATH) as Shader
	_debug_shader = load(DEBUG_SHADER_PATH) as Shader
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)
	_debug_material = ShaderMaterial.new()
	_debug_material.shader = _debug_shader
	_debug_material.set_shader_param("debug_pattern", load(DEBUG_PATTERN_PATH) as Texture)
	_debug_material.set_shader_param("debug_arrow", load(DEBUG_ARROW_PATH) as Texture)
	_material = ShaderMaterial.new()
	_material.shader = _default_shader
	set_texture(load(DEFAULT_WATER_TEXTURE_PATH) as Texture)


func _enter_tree() -> void:
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false

	if not curve:
		curve = Curve3D.new()
		curve.bake_interval = 0.05
		curve.add_point(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		curve.add_point(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		widths = [1.0, 1.0]
	
	
	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance.new()
		new_mesh_instance.name = "RiverMeshInstance"
		add_child(new_mesh_instance)
		mesh_instance = get_child(0) as MeshInstance
		_generate_river()
	else:
		mesh_instance = get_child(0) as MeshInstance
		_material = mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	
	set_materials("valid_flowmap", valid_flowmap)
	set_materials("distmap", _dist_pressure)
	set_materials("flowmap", _flow_foam_noise)
	# If a value is not set on the material, the values are not correct
	set_albedo1(mat_albedo[0])
	set_albedo2(mat_albedo[1])
	emit_signal("albedo_set", mat_albedo[0], mat_albedo[1])


func _get_configuration_warning() -> String:
	if valid_flowmap:
		return ""
	else:
		return "No flowmap is set. Select River -> Generate Flow & Foam Map to generate and assign one."


# Public Methods - These should all be good to use as API from other scripts
func add_point(position : Vector3, index : int, dir : Vector3 = Vector3.ZERO, width : float = 0.0) -> void:
	if index == -1:
		var last_index := curve.get_point_count() - 1
		var dist = position.distance_to(curve.get_point_position(last_index))
		var new_dir := dir if dir != Vector3.ZERO else (position - curve.get_point_position(last_index) - curve.get_point_out(last_index) ).normalized() * 0.25 * dist
		#var new_dir := (position - curve.get_point_position(last_index) - curve.get_point_out(last_index) ).normalized() * 0.25
		curve.add_point(position, -new_dir, new_dir, -1)
		widths.append(widths[widths.size() - 1]) # If this is a new point at the end, add a width that's the same as last
	else:
		var dist = curve.get_point_position(index).distance_to(curve.get_point_position(index + 1))
		var new_dir := dir if dir != Vector3.ZERO else (curve.get_point_position(index + 1) - curve.get_point_position(index)).normalized() * 0.25 * dist
		curve.add_point(position, -new_dir, new_dir, index + 1)
		var new_width = width if width != 0.0 else (widths[index] + widths[index + 1]) / 2.0
		widths.insert(index + 1, new_width) # We set the width to the average of the two surrounding widths
	emit_signal("river_changed")
	_generate_river()


func remove_point(index : int) -> void:
	# We don't allow rivers shorter than 2 points
	if curve.get_point_count() <= 2:
		return
	curve.remove_point(index)
	widths.remove(index)
	emit_signal("river_changed")
	_generate_river()


func bake_texture() -> void:
	_generate_river()
	_generate_flowmap(pow(2, 6 + baking_resolution))


func set_curve_point_position(index : int, position : Vector3) -> void:
	curve.set_point_position(index, position)
	_generate_river()


func set_curve_point_in(index : int, position : Vector3) -> void:
	curve.set_point_in(index, position)
	_generate_river()


func set_curve_point_out(index : int, position : Vector3) -> void:
	curve.set_point_out(index, position)
	_generate_river()


func set_widths(new_widths : Array) -> void:
	widths = new_widths
	if _first_enter_tree:
		return
	_generate_river()


func set_materials(param : String, value) -> void:
	_material.set_shader_param(param, value)
	_debug_material.set_shader_param(param, value)


func set_debug_view(index : int) -> void:
	debug_view = index
	if index == 0:
		mesh_instance.material_override = null
	else:
		_debug_material.set_shader_param("mode", index)
		mesh_instance.material_override =_debug_material


func spawn_mesh() -> void:
	if owner == null:
		push_warning("Cannot create MeshInstance sibling when River is root.")
		return
	var sibling_mesh := mesh_instance.duplicate(true)
	get_parent().add_child(sibling_mesh)
	sibling_mesh.set_owner(get_tree().get_edited_scene_root())
	sibling_mesh.translation = translation
	sibling_mesh.material_override = null;


func get_curve_points() -> PoolVector3Array:
	var points : PoolVector3Array
	for p in curve.get_point_count():
		points.append(curve.get_point_position(p))
	
	return points


func get_closest_point_to(point : Vector3) -> int:
	var points = []
	var closest_distance := 4096.0
	var closest_index
	for p in curve.get_point_count():
		var dist := point.distance_to(curve.get_point_position(p))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = p
	
	return closest_index


# Parameter Setters
func set_step_length_divs(value : int) -> void:
	shape_step_length_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_step_width_divs(value : int) -> void:
	shape_step_width_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_smoothness(value : float) -> void:
	shape_smoothness = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_albedo1(color : Color) -> void:
	mat_albedo[0] = color
	set_materials("albedo1", color)


func set_albedo2(color : Color) -> void:
	mat_albedo[1] = color
	set_materials("albedo2", color)


func set_albedo(colors : PoolColorArray) -> void:
	set_albedo1(colors[0])
	set_albedo2(colors[1])
	emit_signal("albedo_set", colors)


func set_gradient_depth(value : float) -> void:
	mat_gradient_depth = value
	set_materials("gradient_depth", value)


func set_foam_albedo(color : Color) -> void:
	mat_foam_albedo = color
	set_materials("foam_albedo", color)


func set_foam_amount(amount : float) -> void:
	mat_foam_amount = amount
	set_materials("foam_amount", amount)


func set_foam_steepness(amount : float) -> void:
	mat_foam_steepness = amount
	set_materials("foam_steepness", amount)


func set_foam_smoothness(amount : float) -> void:
	mat_foam_smoothness = amount
	set_materials("foam_smoothness", amount)


func set_custom_shader(shader : Shader) -> void:
	if adv_custom_shader == shader:
		return
	adv_custom_shader = shader
	if adv_custom_shader == null:
		_material.shader = load(DEFAULT_SHADER_PATH)
	else:
		_material.shader = adv_custom_shader
		
		if Engine.editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				shader.code = _default_shader.code


func set_roughness(value : float) -> void:
	mat_roughness = value
	set_materials("roughness", value)


func set_refraction(value : float) -> void:
	mat_refraction = value
	set_materials("refraction", value)


func set_texture(texture : Texture) -> void:
	mat_texture = texture
	set_materials("texture_water", texture)


func set_uv_scale(value : Vector3) -> void:
	mat_uv_scale = value
	set_materials("uv_scale", value)


func set_normal_scale(value : float) -> void:
	mat_normal_scale = value
	set_materials("normal_scale", value)


func set_clarity(value : float) -> void:
	mat_clarity = value
	set_materials("clarity", value)


func set_edge_fade(value : float) -> void:
	mat_edge_fade = value
	set_materials("edge_fade", value)


func set_flowspeed(value : float) -> void:
	mat_flow_speed = value
	set_materials("flow_speed", value)


func set_flow_base(value : float) -> void:
	mat_flow_base_strength = value
	set_materials("flow_base", value)


func set_flow_steepness(value : float) -> void:
	mat_flow_steepness_strength = value
	set_materials("flow_steepness", value)


func set_flow_distance(value : float) -> void:
	mat_flow_distance_strength = value
	set_materials("flow_distance", value)


func set_flow_pressure(value : float) -> void:
	mat_flow_pressure_strength = value
	set_materials("flow_pressure", value)


func set_flow_max(value : float) -> void:
	mat_flow_max_strength = value
	set_materials("flow_max", value)


func set_lod0_distance(value : float) -> void:
	lod_lod0_distance = value
	set_materials("lod0_distance", value)


# Private Methods
func _generate_river() -> void:
	var average_width := WaterHelperMethods.sum_array(widths) / float(widths.size() / 2)
	_steps = int( max(1.0, round(curve.get_baked_length() / average_width)) )
	
	var river_width_values := WaterHelperMethods.generate_river_width_values(curve, _steps, shape_step_length_divs, shape_step_width_divs, widths)
	mesh_instance.mesh = WaterHelperMethods.generate_river_mesh(curve, _steps, shape_step_length_divs, shape_step_width_divs, shape_smoothness, river_width_values)
	mesh_instance.mesh.surface_set_material(0, _material)


func _generate_flowmap(flowmap_resolution : float) -> void:
	WaterHelperMethods.reset_all_colliders(get_tree().root)
	
	var image := Image.new()
	image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	emit_signal("progress_notified", 0.0, "Calculating Collisions (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	yield(get_tree(), "idle_frame")
	
	image.lock()
	image = yield(WaterHelperMethods.generate_collisionmap(image, mesh_instance, baking_raycast_distance, baking_raycast_layers, _steps, shape_step_length_divs, shape_step_width_divs, self), "completed")
	image.unlock()
	
	emit_signal("progress_notified", 0.95, "Applying filters (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	yield(get_tree(), "idle_frame")
	
	# Calculate how many colums are in UV2
	var grid_side := WaterHelperMethods.calculate_side(_steps)
	
	var margin := int(round(float(flowmap_resolution) / float(grid_side)))
	
	image = WaterHelperMethods.add_margins(image, flowmap_resolution, margin)

	var collision_with_margins := ImageTexture.new()
	collision_with_margins.create_from_image(image)

	# Create correctly tiling noise for A channel
	var noise_texture := load(NOISE_TEXTURE_PATH) as Texture
	var noise_with_tiling := Image.new()
	var noise_with_margin_size := float(grid_side + 2) * (float(noise_texture.get_width()) / float(grid_side))
	noise_with_tiling.create(noise_with_margin_size, noise_with_margin_size, false, Image.FORMAT_RGB8)
	noise_with_tiling.lock()
	var slice_width := float(noise_texture.get_width()) / float(grid_side)
	for x in grid_side:
		noise_with_tiling.blend_rect(noise_texture.get_data(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width))
	noise_with_tiling.unlock()
	var tiled_noise := ImageTexture.new()
	tiled_noise.create_from_image(noise_with_tiling)

	# Create renderer
	var renderer_instance = _filter_renderer.instance()

	self.add_child(renderer_instance)

	var flow_pressure_blur_amount = 0.04 / float(grid_side) * flowmap_resolution
	var dilate_amount = baking_dilate / float(grid_side) 
	var flowmap_blur_amount = baking_flowmap_blur / float(grid_side) * flowmap_resolution
	var foam_offset_amount = baking_foam_offset / float(grid_side)
	var foam_blur_amount = baking_foam_blur / float(grid_side) * flowmap_resolution
	
	var flow_pressure_map = yield(renderer_instance.apply_flow_pressure(collision_with_margins, flowmap_resolution, grid_side + 2.0), "completed")
	var blurred_flow_pressure_map = yield(renderer_instance.apply_vertical_blur(flow_pressure_map, flow_pressure_blur_amount, flowmap_resolution), "completed")
	var dilated_texture = yield(renderer_instance.apply_dilate(collision_with_margins, dilate_amount, 0.0, flowmap_resolution), "completed")
	var normal_map = yield(renderer_instance.apply_normal(dilated_texture, flowmap_resolution), "completed")
	var flow_map = yield(renderer_instance.apply_normal_to_flow(normal_map, flowmap_resolution), "completed")
	var blurred_flow_map = yield(renderer_instance.apply_blur(flow_map, flowmap_blur_amount, flowmap_resolution), "completed")
	var foam_map = yield(renderer_instance.apply_foam(dilated_texture, foam_offset_amount, baking_foam_cutoff, flowmap_resolution), "completed")
	var blurred_foam_map = yield(renderer_instance.apply_blur(foam_map, foam_blur_amount, flowmap_resolution), "completed")
	var flow_foam_noise_img = yield(renderer_instance.apply_combine(blurred_flow_map, blurred_flow_map, blurred_foam_map, tiled_noise), "completed")
	var dist_pressure_img = yield(renderer_instance.apply_combine(dilated_texture, blurred_flow_pressure_map), "completed")

	remove_child(renderer_instance) # cleanup

	var flow_foam_noise_result = flow_foam_noise_img.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var dist_pressure_result = dist_pressure_img.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))

	_flow_foam_noise = ImageTexture.new()
	_flow_foam_noise.create_from_image(flow_foam_noise_result, 5)
	
	_dist_pressure = ImageTexture.new()
	_dist_pressure.create_from_image(dist_pressure_result, 5)
	
	set_materials("flowmap", _flow_foam_noise)
	set_materials("distmap", _dist_pressure)
	set_materials("valid_flowmap", true)
	valid_flowmap = true;
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warning()


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
