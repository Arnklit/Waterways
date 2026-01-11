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
@export var baking_resolution: int = 2:
	set = set_baking_resolution

const WaterHelperMethods = preload("./water_helper_methods.gd")

const FOAM_NOISE_PATH = "res://addons/waterways/textures/foam_noise.png"

const MATERIAL_CATEGORIES = {
	albedo_ = "Albedo",
	emission_ = "Emission",
	transparency_ = "Transparency",
	flow_ = "Flow",
	foam_ = "Foam",
	custom_ = "Custom",
}

enum SHADER_TYPES { WATER, LAVA, CUSTOM }
const BUILTIN_SHADERS = [
	{
		name = "Water",
		shader_path = "res://addons/waterways/shaders/river.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/water1_normal_bump.png",
			},
		],
	},
	{
		name = "Lava",
		shader_path = "res://addons/waterways/shaders/lava.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/lava_normal_bump.png",
			},
			{
				name = "emission_texture",
				path = "res://addons/waterways/textures/lava_emission.png",
			},
		],
	},
]

var mesh_instance: MeshInstance3D
var points := PackedVector3Array([Vector3(0.0, 4.0, 0.0), Vector3(0.0, 0.0, 1.0)]):
	set(value):
		points = value
		_generate_waterfall()
		emit_signal("waterfall_changed")

# Direction vectors at each endpoint (normalized, in XZ plane). Zero means auto-calculate from points.
var direction_top := Vector3.ZERO
var direction_bottom := Vector3.ZERO

# Material Properties
var mat_shader_type: SHADER_TYPES:
	set = set_shader_type
var mat_custom_shader: Shader:
	set = set_custom_shader

var _material: ShaderMaterial
var _st: SurfaceTool
var _mdt: MeshDataTool
var _steps := 2
var _first_enter_tree = true

signal waterfall_changed


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
	_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
	for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
		_material.set_shader_parameter(texture.name, load(texture.path) as Texture2D)


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
	print("Baking texture...")
	_generate_waterfall()
	_generate_flowmap(pow(2, 6 + baking_resolution))


func _generate_flowmap(flowmap_resolution: float) -> void:
	print("Generating flowmap...")
	print("Flowmap resolution: ", flowmap_resolution)
	print("Flowmap resolution: ", flowmap_resolution)


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


func set_shader_type(type: int) -> void:
	if type == mat_shader_type:
		return
	mat_shader_type = type

	if mat_shader_type == SHADER_TYPES.CUSTOM:
		_material.shader = mat_custom_shader
	else:
		_material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path)
		for texture in BUILTIN_SHADERS[mat_shader_type].texture_paths:
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
				var selected_shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
				shader.code = selected_shader.code


# Signal Methods
func properties_changed() -> void:
	_generate_waterfall()
	emit_signal("waterfall_changed")
