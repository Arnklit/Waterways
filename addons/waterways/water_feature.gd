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


func get_step_length_divs() -> int:
	assert(false, "Subclass must implement get_step_length_divs()")
	return 1


func get_step_width_divs() -> int:
	assert(false, "Subclass must implement get_step_width_divs()")
	return 1


func _use_uv2_for_collisionmap() -> bool:
	return true


func _generate_mesh() -> void:
	assert(false, "Subclass must implement _generate_mesh()")


func _generate_flowmap(flowmap_resolution: float) -> void:
	var image := Image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))

	emit_signal("progress_notified", 0.0, "Calculating Collisions (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame

	image = await WaterHelperMethods.generate_collisionmap(image, get_mesh_instance(), baking_raycast_distance, baking_raycast_layers, _steps, get_step_length_divs(), get_step_width_divs(), self, _use_uv2_for_collisionmap())

	emit_signal("progress_notified", 0.95, "Applying filters (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame

	_uv2_sides = WaterHelperMethods.calculate_side(_steps)

	var margin := int(round(float(flowmap_resolution) / float(_uv2_sides)))
	image = WaterHelperMethods.add_margins(image, flowmap_resolution, margin)

	var collision_with_margins := ImageTexture.create_from_image(image)

	# Create correctly tiling noise for A channel
	var noise_texture := load(Constants.FLOW_OFFSET_NOISE_TEXTURE_PATH) as Texture2D
	var noise_with_margin_size := float(_uv2_sides + 2) * (float(noise_texture.get_width()) / float(_uv2_sides))
	var noise_with_tiling := Image.create(noise_with_margin_size, noise_with_margin_size, false, Image.FORMAT_RGB8)
	var slice_width := float(noise_texture.get_width()) / float(_uv2_sides)

	for x in _uv2_sides:
		noise_with_tiling.blend_rect(noise_texture.get_image(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width - (noise_texture.get_width() / 2.0)))
		noise_with_tiling.blend_rect(noise_texture.get_image(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width + (noise_texture.get_width() / 2.0)))
	var tiled_noise := ImageTexture.new()
	tiled_noise.create_from_image(noise_with_tiling)

	var renderer_instance = _filter_renderer.instantiate()
	self.add_child(renderer_instance)

	var flow_pressure_blur_amount = 0.04 / float(_uv2_sides) * flowmap_resolution
	var dilate_amount = baking_dilate / float(_uv2_sides)
	var flowmap_blur_amount = baking_flowmap_blur / float(_uv2_sides) * flowmap_resolution
	var foam_offset_amount = baking_foam_offset / float(_uv2_sides)
	var foam_blur_amount = baking_foam_blur / float(_uv2_sides) * flowmap_resolution

	var flow_pressure_map = await renderer_instance.apply_flow_pressure(collision_with_margins, flowmap_resolution, _uv2_sides + 2.0)
	var blurred_flow_pressure_map = await renderer_instance.apply_vertical_blur(flow_pressure_map, flow_pressure_blur_amount, flowmap_resolution + margin * 2)
	var dilated_texture = await renderer_instance.apply_dilate(collision_with_margins, dilate_amount, 0.0, flowmap_resolution + margin * 2)
	var normal_map = await renderer_instance.apply_normal(dilated_texture, flowmap_resolution + margin * 2)
	var flow_map = await renderer_instance.apply_normal_to_flow(normal_map, flowmap_resolution + margin * 2)
	var blurred_flow_map = await renderer_instance.apply_blur(flow_map, flowmap_blur_amount, flowmap_resolution + margin * 2)
	var foam_map = await renderer_instance.apply_foam(dilated_texture, foam_offset_amount, baking_foam_cutoff, flowmap_resolution + margin * 2)
	var blurred_foam_map = await renderer_instance.apply_blur(foam_map, foam_blur_amount, flowmap_resolution + margin * 2)
	var flow_foam_noise_img = await renderer_instance.apply_combine(blurred_flow_map, blurred_flow_map, blurred_foam_map, tiled_noise)
	var dist_pressure_img = await renderer_instance.apply_combine(dilated_texture, blurred_flow_pressure_map)

	remove_child(renderer_instance)

	flow_foam_noise = flow_foam_noise_img
	dist_pressure = dist_pressure_img

	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	valid_flowmap = true
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warnings()


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


func _get_material_property_list() -> Array:
	return [
		{
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "mat_shader_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Water, Lava, Custom",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "mat_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Shader",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "_material",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "ShaderMaterial",
			usage = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
	]


func _get_shader_params_property_list() -> Array:
	var shader_props = []
	var mat_categories = Constants.MATERIAL_CATEGORIES.duplicate(true)

	if _material.shader != null:
		var shader_params := RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
		for p in shader_params:
			if p.name.begins_with("i_"):
				continue
			var hit_category = null
			for category in mat_categories:
				if p.name.begins_with(category):
					shader_props.append(
						{
							name = str("Material/", mat_categories[category]),
							type = TYPE_NIL,
							hint_string = str("mat_", category),
							usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
						},
					)
					hit_category = category
					break

			if hit_category != null:
				mat_categories.erase(hit_category)

			var cp := { }
			for k in p:
				cp[k] = p[k]
			cp.name = str("mat_", p.name)
			if "curve" in cp.name:
				cp.hint = PROPERTY_HINT_EXP_EASING
				cp.hint_string = "EASE"
			shader_props.append(cp)

	return shader_props


func _get_baking_property_list() -> Array:
	return [
		{
			name = "Baking",
			type = TYPE_NIL,
			hint_string = "baking_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "64, 128, 256, 512, 1024",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_raycast_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_raycast_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_LAYERS_3D_PHYSICS,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_dilate",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_flowmap_blur",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_foam_cutoff",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_foam_offset",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "baking_foam_blur",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
	]


func _get_base_storage_property_list() -> Array:
	return [
		{
			name = "valid_flowmap",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "flow_foam_noise",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "dist_pressure",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "_uv2_sides",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE,
		},
	]


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
