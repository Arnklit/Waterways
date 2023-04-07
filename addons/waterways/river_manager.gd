# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterHelperMethods = preload("./water_helper_methods.gd")

const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"
const FLOW_OFFSET_NOISE_TEXTURE_PATH = "res://addons/waterways/textures/flow_offset_noise.png"
const FOAM_NOISE_PATH = "res://addons/waterways/textures/foam_noise.png"

const MATERIAL_CATEGORIES = {
	albedo_ = "Albedo",
	emission_ = "Emission",
	transparency_ = "Transparency",
	flow_ = "Flow",
	foam_ = "Foam",
	custom_ = "Custom"
}

enum SHADER_TYPES {WATER, LAVA, CUSTOM}
const BUILTIN_SHADERS = [
	{
		name = "Water",
		shader_path = "res://addons/waterways/shaders/river.shader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/water1_normal_bump.png"
			}
		]
	},
	{
		name = "Lava",
		shader_path = "res://addons/waterways/shaders/lava.shader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/lava_normal_bump.png"
			},
			{
				name = "emission_texture",
				path = "res://addons/waterways/textures/lava_emission.png"
			}
		]
	}
]

const DEBUG_SHADER = {
	name = "Debug",
	shader_path = "res://addons/waterways/shaders/river_debug.shader",
	texture_paths = [
		{
			name = "debug_pattern",
			path = "res://addons/waterways/textures/debug_pattern.png"
		},
		{
			name = "debug_arrow",
			path = "res://addons/waterways/textures/debug_arrow.svg"
		}
	]
}

const DEFAULT_PARAMETERS = {
	shape_step_length_divs = 1,
	shape_step_width_divs = 1,
	shape_smoothness = 0.5,
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
	lod_lod0_distance = 50.0,
}


# Shape Properties
var shape_step_length_divs := 1 setget set_step_length_divs
var shape_step_width_divs := 1 setget set_step_width_divs
var shape_smoothness := 0.5 setget set_smoothness

# Material Properties that not handled in shader
var mat_shader_type : int setget set_shader_type
var mat_custom_shader : Shader setget set_custom_shader

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

# Public variables
var curve : Curve3D
var widths := [] setget set_widths
var valid_flowmap := false
var debug_view := 0 setget set_debug_view
var mesh_instance : MeshInstance
var flow_foam_noise : Texture
var dist_pressure : Texture

# Private variables
var _steps := 2
var _st : SurfaceTool
var _mdt : MeshDataTool
var _debug_material : ShaderMaterial
var _first_enter_tree := true
var _filter_renderer
# Serialised private variables
var _material : ShaderMaterial
var _selected_shader : int = SHADER_TYPES.WATER
var _uv2_sides : int

# river_changed used to update handles when values are changed on script side
# progress_notified used to up progress bar when baking maps
# albedo_set is needed since the gradient is a custom inspector that needs a signal to update from script side
signal river_changed
signal progress_notified
#signal albedo_set

# Internal Methods
func _get_property_list() -> Array:
	var props = [
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
			name = "mat_shader_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Water, Lava, Custom",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		},
	]

	var props2 = []
	var mat_categories = MATERIAL_CATEGORIES.duplicate(true)
	
	if _material.shader != null:
		var shader_params := VisualServer.shader_get_param_list(_material.shader.get_rid())
		shader_params = WaterHelperMethods.reorder_params(shader_params)
		for p in shader_params:
			if p.name.begins_with("i_"):
				continue
			var hit_category = null
			for category in mat_categories:
				if p.name.begins_with(category):
					props2.append({
						name = str("Material/", mat_categories[category]),
						type = TYPE_NIL,
						hint_string = str("mat_", category),
						usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
					})
					hit_category = category
					break
			if hit_category != null:
				mat_categories.erase(hit_category)
			var cp := {}
			for k in p:
				cp[k] = p[k]
			cp.name = str("mat_", p.name)
			if "curve" in cp.name:
				cp.hint = PROPERTY_HINT_EXP_EASING
				cp.hint_string = "EASE"
			props2.append(cp)
	var props3 = [
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
			name = "valid_flowmap",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "flow_foam_noise",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "dist_pressure",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_material",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "ShaderMaterial",
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_selected_shader",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_uv2_sides",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE
		}
	]
	var combined_props = props + props2 + props3
	return combined_props


func _set(property: String, value) -> bool:
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		_material.set_shader_param(param_name, value)
		return true
	return false


func _get(property : String):
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		return  _material.get_shader_param(param_name)


func property_can_revert(property : String) -> bool:
	if property.begins_with("mat_"):
#		if "color" in property:
#			# TODO - we are disabling revert for color parameters due to this
#			# bug: https://github.com/godotengine/godot/issues/45388
#			return false
		var param_name = property.right(len("mat_"))
		return _material.property_can_revert(str("shader_param/", param_name))

	if not DEFAULT_PARAMETERS.has(property):
		return false
	if get(property) != DEFAULT_PARAMETERS[property]:
		return true
	return false


func property_get_revert(property : String):
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		var revert_value = _material.property_get_revert(str("shader_param/", param_name))
		return revert_value


func _init() -> void:
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)

	_debug_material = ShaderMaterial.new()
	_debug_material.shader = load(DEBUG_SHADER.shader_path) as Shader
	for texture in DEBUG_SHADER.texture_paths:
		_debug_material.set_shader_param(texture.name, load(texture.path) as Texture)

	_material = ShaderMaterial.new()
	_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
	for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
		_material.set_shader_param(texture.name, load(texture.path) as Texture)
	# Have to manually set the color or it does not default right. Not sure how to work around this
	_material.set_shader_param("albedo_color", Transform(Vector3(0.0, 0.8, 1.0), Vector3(0.15, 0.2, 0.5), Vector3.ZERO, Vector3.ZERO))


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
	
	set_materials("i_valid_flowmap", valid_flowmap)
	set_materials("i_uv2_sides", _uv2_sides)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_texture_foam_noise", load(FOAM_NOISE_PATH) as Texture)


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


func get_shader_param(param : String):
	return _material.get_shader_param(param)


# Parameter Setters
func set_step_length_divs(value : int) -> void:
	shape_step_length_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_step_width_divs(value : int) -> void:
	shape_step_width_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_smoothness(value : float) -> void:
	shape_smoothness = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_shader_type(type: int):
	if type == mat_shader_type:
		return
	mat_shader_type = type
	
	if mat_shader_type == SHADER_TYPES.CUSTOM:
		_material.shader = mat_custom_shader
	else:
		_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path)
		for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
			_material.set_shader_param(texture.name, load(texture.path) as Texture)
	
	property_list_changed_notify()


func set_custom_shader(shader : Shader) -> void:
	if mat_custom_shader == shader:
		return
	mat_custom_shader = shader
	if mat_custom_shader != null:
		_material.shader = mat_custom_shader
		
		if Engine.editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				var selected_shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
				shader.code = selected_shader.code
	
	if shader != null:
		set_shader_type(SHADER_TYPES.CUSTOM)
	else:
		set_shader_type(SHADER_TYPES.WATER)


func set_lod0_distance(value : float) -> void:
	lod_lod0_distance = value
	set_materials("i_lod0_distance", value)


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
	_uv2_sides = WaterHelperMethods.calculate_side(_steps)
	
	var margin := int(round(float(flowmap_resolution) / float(_uv2_sides)))
	
	image = WaterHelperMethods.add_margins(image, flowmap_resolution, margin)

	var collision_with_margins := ImageTexture.new()
	collision_with_margins.create_from_image(image)

	# Create correctly tiling noise for A channel
	var noise_texture := load(FLOW_OFFSET_NOISE_TEXTURE_PATH) as Texture
	var noise_with_tiling := Image.new()
	var noise_with_margin_size := float(_uv2_sides + 2) * (float(noise_texture.get_width()) / float(_uv2_sides))
	noise_with_tiling.create(noise_with_margin_size, noise_with_margin_size, false, Image.FORMAT_RGB8)
	noise_with_tiling.lock()
	var slice_width := float(noise_texture.get_width()) / float(_uv2_sides)
	for x in _uv2_sides:
		noise_with_tiling.blend_rect(noise_texture.get_data(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width - (noise_texture.get_width() / 2.0)))
		noise_with_tiling.blend_rect(noise_texture.get_data(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width + (noise_texture.get_width() / 2.0)))
	noise_with_tiling.unlock()
	var tiled_noise := ImageTexture.new()
	tiled_noise.create_from_image(noise_with_tiling)

	# Create renderer
	var renderer_instance = _filter_renderer.instance()

	self.add_child(renderer_instance)

	var flow_pressure_blur_amount = 0.04 / float(_uv2_sides) * flowmap_resolution
	var dilate_amount = baking_dilate / float(_uv2_sides) 
	var flowmap_blur_amount = baking_flowmap_blur / float(_uv2_sides) * flowmap_resolution
	var foam_offset_amount = baking_foam_offset / float(_uv2_sides)
	var foam_blur_amount = baking_foam_blur / float(_uv2_sides) * flowmap_resolution
	
	var flow_pressure_map = yield(renderer_instance.apply_flow_pressure(collision_with_margins, flowmap_resolution, _uv2_sides + 2.0), "completed")
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
	
	flow_foam_noise = flow_foam_noise_img
	dist_pressure = dist_pressure_img
	
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	valid_flowmap = true;
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warning()


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
