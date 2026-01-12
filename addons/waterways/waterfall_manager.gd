@tool
extends Node3D

@export var line_sample_resolution: int = 100:
	set = set_line_sample_resolution
@export var width_top: float = 1.0:
	set = set_width_top
@export var width_bottom: float = 1.0:
	set = set_width_bottom
@export var step_length_divs: int = 1:
	set = set_step_length_divs
@export var step_width_divs: int = 1:
	set = set_step_width_divs
@export var overshoot: float = 1.60158:
	set = set_overshoot

const WaterHelperMethods = preload("./water_helper_methods.gd")
const Constants = preload("./consts.gd")

var mesh_instance: MeshInstance3D
var points := PackedVector3Array([Vector3(0.0, 4.0, 0.0), Vector3(0.0, 0.0, 1.0)]):
	set(value):
		points = value
		_generate_waterfall()
		emit_signal("waterfall_changed")

var valid_flowmap := false
var flow_foam_noise: Texture2D
var dist_pressure: Texture2D
var debug_view: int = 0:
	set = set_debug_view

# Direction vectors at each endpoint (normalized, in XZ plane). Zero means auto-calculate from points.
var direction_top := Vector3.ZERO
var direction_bottom := Vector3.ZERO

# Material Properties
var mat_shader_type: Constants.SHADER_TYPES:
	set = set_shader_type
var mat_custom_shader: Shader:
	set = set_custom_shader

# Shape Properties
var shape_step_length_divs: int = 1:
	set = set_step_length_divs
var shape_step_width_divs: int = 1:
	set = set_step_width_divs
var shape_smoothness: float = 0.5:
	set = set_smoothness

# Bake Properties
@export var baking_resolution: int = 2:
	set = set_baking_resolution
var baking_raycast_distance: float = 10.0
var baking_raycast_layers: int = 1
var baking_dilate: float = 0.6
var baking_flowmap_blur: float = 0.04
var baking_foam_cutoff: float = 0.9
var baking_foam_offset: float = 0.1
var baking_foam_blur: float = 0.02

var _filter_renderer: PackedScene
var _material: ShaderMaterial
var _debug_material: ShaderMaterial
var _st: SurfaceTool
var _mdt: MeshDataTool
var _steps := 2
var _first_enter_tree = true
var _uv2_sides: int

signal waterfall_changed
signal progress_notified # Used to update progress bar when baking maps


func _get_property_list() -> Array:
	return [
		{
			name = "points",
			type = TYPE_PACKED_VECTOR3_ARRAY,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "direction_top",
			type = TYPE_VECTOR3,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "direction_bottom",
			type = TYPE_VECTOR3,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "_material",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "ShaderMaterial",
			usage = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
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


func get_right_vector_top() -> Vector3:
	if direction_top != Vector3.ZERO:
		return direction_top.cross(Vector3.UP).normalized()
	return _get_default_right_vector()


func get_right_vector_bottom() -> Vector3:
	if direction_bottom != Vector3.ZERO:
		return direction_bottom.cross(Vector3.UP).normalized()
	return _get_default_right_vector()


func _get_default_right_vector() -> Vector3:
	var to_from: Vector3 = points[1] - points[0]
	var to_from_2d = Vector3(to_from.x, 0.0, to_from.z)
	if to_from_2d.length() < 0.001:
		return Vector3.RIGHT
	return to_from_2d.cross(Vector3.UP).normalized()


func _init() -> void:
	_material = ShaderMaterial.new()
	_filter_renderer = load(Constants.FILTER_RENDERER_PATH)
	_material.shader = load(Constants.BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
	for texture in Constants.BUILTIN_SHADERS[mat_shader_type].texture_paths:
		_material.set_shader_parameter(texture.name, load(texture.path) as Texture2D)

	_debug_material = ShaderMaterial.new()
	_debug_material.shader = load(Constants.DEBUG_SHADER.shader_path) as Shader
	for texture in Constants.DEBUG_SHADER.texture_paths:
		_debug_material.set_shader_parameter(texture.name, load(texture.path) as Texture2D)


func get_points() -> PackedVector3Array:
	return points


func set_point(id: int, position: Vector3) -> void:
	points[id] = position
	_generate_waterfall()
	emit_signal("waterfall_changed")


func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false

	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance3D.new()
		new_mesh_instance.name = "WaterfallMeshInstance"
		add_child(new_mesh_instance)
		mesh_instance = get_child(0) as MeshInstance3D
		_generate_waterfall()
	else:
		mesh_instance = get_child(0) as MeshInstance3D
		if mesh_instance.mesh:
			_material = mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


func _generate_waterfall() -> void:
	if mesh_instance == null:
		return

	var to_from: Vector3 = points[1] - points[0]
	var to_from_2d = Vector3(to_from.x, 0.0, to_from.z)
	var dist = to_from_2d.length()

	var line_points := PackedVector3Array()
	var curve := Curve3D.new()

	for i in line_sample_resolution + 1:
		var val = float(i) / float(line_sample_resolution)
		var position = points[0] + to_from_2d * val + Vector3(0.0, ease_back_in(val) * to_from.y, 0.0)
		curve.add_point(position)
		line_points.append(position)

	var curve_length := curve.get_baked_length()
	var avg_width := (width_top + width_bottom) / 2.0

	_steps = int(max(1.0, round(curve_length / avg_width)))

	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_smooth_group(0)

	# Generating the verts
	var right_top := get_right_vector_top()
	var right_bottom := get_right_vector_bottom()
	for step in _steps * step_length_divs + 1:
		var t := float(step) / float(_steps * step_length_divs)
		var position := curve.sample_baked(t * curve_length, false)
		var right_vector := right_top.slerp(right_bottom, t).normalized()
		var width := lerpf(width_top, width_bottom, t)

		for w_sub in step_width_divs + 1:
			_st.set_uv(Vector2(float(w_sub) / (float(step_width_divs)), float(step) / float(step_length_divs)))
			_st.add_vertex(position + right_vector * width - 2.0 * right_vector * width * float(w_sub) / (float(step_width_divs)))

	# Defining the tris
	for step in _steps * step_length_divs:
		for w_sub in step_width_divs:
			_st.add_index((step * (step_width_divs + 1)) + w_sub)
			_st.add_index((step * (step_width_divs + 1)) + w_sub + 1)
			_st.add_index((step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)

			_st.add_index((step * (step_width_divs + 1)) + w_sub + 1)
			_st.add_index((step * (step_width_divs + 1)) + w_sub + 3 + step_width_divs - 1)
			_st.add_index((step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)

	_st.generate_normals()
	_st.generate_tangents()
	_st.deindex()

	var mesh := ArrayMesh.new()
	mesh = _st.commit()
	mesh.surface_set_material(0, _material)
	mesh_instance.mesh = mesh


func ease_back_in(x: float) -> float:
	var c3 = overshoot + 1
	return c3 * x * x * x - overshoot * x * x


func bake_texture() -> void:
	_generate_waterfall()
	_generate_flowmap(pow(2, 6 + baking_resolution))


func _generate_flowmap(flowmap_resolution: float) -> void:
	var image := Image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))

	emit_signal("progress_notified", 0.0, "Calculating Collisions (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame

	image = await WaterHelperMethods.generate_collisionmap(image, mesh_instance, baking_raycast_distance, baking_raycast_layers, _steps, shape_step_length_divs, shape_step_width_divs, self, false)

	emit_signal("progress_notified", 0.95, "Applying filters (" + str(flowmap_resolution) + "x" + str(flowmap_resolution) + ")")
	await get_tree().process_frame

	# Calculate how many columns are in UV2
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

	# Create renderer
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

	# Debug texture gen
	#	flow_pressure_map.get_image().save_png("res://test_assets/baked_pressure_map.png")
	#	blurred_flow_pressure_map.get_image().save_png("res://test_assets/baked_pressure_map_blurred.png")
	#	dilated_texture.get_image().save_png("res://test_assets/dilated_texture.png")
	#	normal_map.get_image().save_png("res://test_assets/normal_map.png")
	#	flow_map.get_image().save_png("res://test_assets/flow_map.png")
	#	blurred_flow_map.get_image().save_png("res://test_assets/blurred_flow_map.png")

	remove_child(renderer_instance) # cleanup

	var flow_foam_noise_result = flow_foam_noise_img.get_image().get_region(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var dist_pressure_result = dist_pressure_img.get_image().get_region(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))

	flow_foam_noise = flow_foam_noise_img
	dist_pressure = dist_pressure_img

	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_valid_flowmap", true)
	set_materials("i_uv2_sides", _uv2_sides)
	valid_flowmap = true
	emit_signal("progress_notified", 100.0, "finished")
	update_configuration_warnings()


func set_line_sample_resolution(value: int) -> void:
	line_sample_resolution = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_width_top(value: float) -> void:
	width_top = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_width_bottom(value: float) -> void:
	width_bottom = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_step_length_divs(value: int) -> void:
	step_length_divs = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_step_width_divs(value: int) -> void:
	step_width_divs = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_smoothness(value: float) -> void:
	shape_smoothness = value
	if _first_enter_tree:
		return
	_generate_waterfall()
	notify_property_list_changed()


func set_overshoot(value: float) -> void:
	overshoot = value
	if _first_enter_tree:
		return

	notify_property_list_changed()
	_generate_waterfall()


func set_baking_resolution(value: int) -> void:
	baking_resolution = value
	if _first_enter_tree:
		return

	notify_property_list_changed()


func set_materials(param: String, value) -> void:
	_material.set_shader_parameter(param, value)
	_debug_material.set_shader_parameter(param, value)


func set_debug_view(index: int) -> void:
	print("Setting debug view to ", index)
	debug_view = index
	if index == 0:
		mesh_instance.material_override = null
	else:
		_debug_material.set_shader_parameter("mode", index)
		mesh_instance.material_override = _debug_material


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


# Signal Methods
func properties_changed() -> void:
	emit_signal("waterfall_changed")
