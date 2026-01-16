@tool
extends "res://addons/waterways/water_feature.gd"

const DEFAULT_PARAMETERS = {
	line_sample_resolution = 100,
	width_top = 1.0,
	width_bottom = 1.0,
	step_length_divs = 1,
	step_width_divs = 1,
	overshoot = 1.60158,
}

# Shape Properties
## How many points to sample the curve at
var line_sample_resolution: int = 100:
	set = set_line_sample_resolution
## The width of the top of the waterfall
var width_top: float = 1.0:
	set = set_width_top
## The width of the bottom of the waterfall
var width_bottom: float = 1.0:
	set = set_width_bottom
var step_length_divs: int = 1:
	set = set_step_length_divs
var step_width_divs: int = 1:
	set = set_step_width_divs
## The amount of overshoot for the waterfall
var overshoot: float = 1.60158:
	set = set_overshoot

var points := PackedVector3Array([Vector3(0.0, 4.0, 0.0), Vector3(0.0, 0.0, 1.0)])

# Direction vectors at each endpoint (normalized, in XZ plane). Zero means auto-calculate from points.
var direction_top := Vector3.ZERO
var direction_bottom := Vector3.ZERO

var _st: SurfaceTool
var _mdt: MeshDataTool
var _mesh_instance: MeshInstance3D

signal waterfall_changed


func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


func get_step_length_divs() -> int:
	return step_length_divs


func get_step_width_divs() -> int:
	return step_width_divs


func _use_uv2_for_collisionmap() -> bool:
	return false


func _generate_mesh() -> void:
	_generate_waterfall()


func _property_can_revert(property: StringName) -> bool:
	if super(property):
		return true
	if DEFAULT_PARAMETERS.has(property):
		return get(property) != DEFAULT_PARAMETERS[property]
	return false


func _property_get_revert(property: StringName):
	var base_result = super(property)
	if base_result != null:
		return base_result
	if DEFAULT_PARAMETERS.has(property):
		return DEFAULT_PARAMETERS[property]
	return null


func _get_property_list() -> Array:
	var props = [
		{
			name = "Shape",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "line_sample_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 200",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "width_top",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1, 10.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "width_bottom",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1, 10.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "step_length_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "step_width_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "overshoot",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,1.0,1.60158,5.0",
			description = "The overshoot value for the waterfall",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
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

	var storage_props = [
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
	return props + shader_props + storage_props


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


func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false

	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance3D.new()
		new_mesh_instance.name = "WaterfallMeshInstance"
		add_child(new_mesh_instance)
		_mesh_instance = get_child(0) as MeshInstance3D
		_generate_waterfall()
	else:
		_mesh_instance = get_child(0) as MeshInstance3D
		if _mesh_instance.mesh:
			_material = _mesh_instance.mesh.surface_get_material(0) as ShaderMaterial


func _generate_waterfall() -> void:
	if _mesh_instance == null:
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
	_mesh_instance.mesh = mesh

	emit_signal("waterfall_changed")


func ease_back_in(x: float) -> float:
	var c3 = overshoot + 1
	return c3 * x * x * x - overshoot * x * x


func bake_texture() -> void:
	_generate_waterfall()
	_generate_flowmap(pow(2, 6 + baking_resolution))


func set_line_sample_resolution(value: int) -> void:
	line_sample_resolution = value
	if _first_enter_tree:
		return
	_generate_waterfall()


func set_width_top(value: float) -> void:
	width_top = value
	if _first_enter_tree:
		return
	_generate_waterfall()


func set_width_bottom(value: float) -> void:
	width_bottom = value
	if _first_enter_tree:
		return
	_generate_waterfall()


func set_step_length_divs(value: int) -> void:
	step_length_divs = value
	if _first_enter_tree:
		return
	_generate_waterfall()


func set_step_width_divs(value: int) -> void:
	step_width_divs = value
	if _first_enter_tree:
		return
	_generate_waterfall()


func set_overshoot(value: float) -> void:
	overshoot = value
	if _first_enter_tree:
		return

	_generate_waterfall()


# Signal Methods
func properties_changed() -> void:
	emit_signal("waterfall_changed")
