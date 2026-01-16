# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends "res://addons/waterways/water_feature.gd"

const DEFAULT_PARAMETERS = {
	shape_step_length_divs = 1,
	shape_step_width_divs = 1,
	shape_smoothness = 0.5,
	lod_lod0_distance = 50.0,
}

# Shape Properties
var shape_step_length_divs: int = 1:
	set = set_step_length_divs
var shape_step_width_divs: int = 1:
	set = set_step_width_divs
var shape_smoothness: float = 0.5:
	set = set_smoothness

# LOD Properties
var lod_lod0_distance: float = 50.0:
	set = set_lod0_distance

# Public variables
var curve: Curve3D
var widths: Array[float] = [1.0, 1.0]:
	set = set_widths

# Private variables
var _st: SurfaceTool
var _mdt: MeshDataTool
var _selected_shader: int = Constants.SHADER_TYPES.WATER

signal river_changed


func get_step_length_divs() -> int:
	return shape_step_length_divs


func get_step_width_divs() -> int:
	return shape_step_width_divs


func _generate_mesh() -> void:
	_generate_river()


func _get_default_parameters() -> Dictionary:
	return DEFAULT_PARAMETERS


func _get_property_list() -> Array:
	var shape_props = [
		{
			name = "Shape",
			type = TYPE_NIL,
			hint_string = "shape_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "shape_step_length_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "shape_step_width_divs",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 8",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "shape_smoothness",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
	]

	var lod_props = [
		{
			name = "Lod",
			type = TYPE_NIL,
			hint_string = "lod_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			name = "lod_lod0_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "5.0, 200.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
	]

	var storage_props = [
		{
			name = "curve",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "widths",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "_selected_shader",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE,
		},
	]

	return (
		shape_props +
		_get_material_property_list() +
		_get_shader_params_property_list() +
		lod_props +
		_get_baking_property_list() +
		storage_props + _get_base_storage_property_list()
	)


func _init() -> void:
	super()
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	# Have to manually set the color or it does not default right
	_material.set_shader_parameter("albedo_color", Transform3D(Vector3(0.0, 0.8, 1.0), Vector3(0.15, 0.2, 0.5), Vector3.ZERO, Vector3.ZERO))


func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false

	if not curve:
		curve = Curve3D.new()
		curve.bake_interval = 0.05
		curve.add_point(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		curve.add_point(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))

	if get_child_count() <= 0:
		## This is what happens on creating a new river
		var new_mesh_instance := MeshInstance3D.new()
		new_mesh_instance.name = "RiverMeshInstance"
		add_child(new_mesh_instance)
		_mesh_instance = get_child(0) as MeshInstance3D
		_generate_river()
	else:
		_mesh_instance = get_child(0) as MeshInstance3D
		_material = _mesh_instance.mesh.surface_get_material(0) as ShaderMaterial

	set_materials("i_valid_flowmap", valid_flowmap)
	set_materials("i_uv2_sides", _uv2_sides)
	set_materials("i_distmap", dist_pressure)
	set_materials("i_flowmap", flow_foam_noise)
	set_materials("i_texture_foam_noise", load(Constants.FOAM_NOISE_PATH) as Texture2D)


func _get_configuration_warning() -> String:
	if valid_flowmap:
		return ""

	return "No flowmap is set. Select River -> Generate Flow & Foam Map to generate and assign one."


func get_transformed_aabb() -> AABB:
	return global_transform * _mesh_instance.get_aabb()


# Public Methods - These should all be good to use as API from other scripts
func add_point(position: Vector3, index: int, dir: Vector3 = Vector3.ZERO, width: float = 0.0) -> void:
	if index == -1:
		var last_index: int = curve.get_point_count() - 1
		var dist: float = position.distance_to(curve.get_point_position(last_index))
		var new_dir: Vector3 = dir if dir != Vector3.ZERO else (position - curve.get_point_position(last_index) - curve.get_point_out(last_index)).normalized() * 0.25 * dist
		curve.add_point(position, -new_dir, new_dir, -1)
		widths.append(widths[widths.size() - 1]) # If this is a new point at the end, add a width that's the same as last
	else:
		var dist = curve.get_point_position(index).distance_to(curve.get_point_position(index + 1))
		var new_dir: Vector3 = dir if dir != Vector3.ZERO else (curve.get_point_position(index + 1) - curve.get_point_position(index)).normalized() * 0.25 * dist
		curve.add_point(position, -new_dir, new_dir, index + 1)
		var new_width = width if width != 0.0 else (widths[index] + widths[index + 1]) / 2.0
		widths.insert(index + 1, new_width) # We set the width to the average of the two surrounding widths
	emit_signal("river_changed")
	_generate_river()


func remove_point(index: int) -> void:
	# We don't allow rivers shorter than 2 points
	if curve.get_point_count() <= 2:
		return
	curve.remove_point(index)
	widths.remove_at(index)
	emit_signal("river_changed")
	_generate_river()


func set_curve_point_position(index: int, position: Vector3) -> void:
	curve.set_point_position(index, position)
	_generate_river()


func set_curve_point_in(index: int, position: Vector3) -> void:
	curve.set_point_in(index, position)
	_generate_river()


func set_curve_point_out(index: int, position: Vector3) -> void:
	curve.set_point_out(index, position)
	_generate_river()


func set_widths(new_widths) -> void:
	widths = new_widths
	if _first_enter_tree:
		return
	_generate_river()


func spawn_mesh() -> void:
	if owner == null:
		push_warning("Cannot create MeshInstance3D sibling when River is root.")
		return
	var sibling_mesh := _mesh_instance.duplicate(true)
	get_parent().add_child(sibling_mesh)
	sibling_mesh.set_owner(get_tree().get_edited_scene_root())
	sibling_mesh.position = position
	sibling_mesh.material_override = null


func get_curve_points() -> PackedVector3Array:
	var points: PackedVector3Array
	for p in curve.get_point_count():
		points.append(curve.get_point_position(p))

	return points


func get_closest_point_to(point: Vector3) -> int:
	var closest_distance := 4096.0
	var closest_index
	for p in curve.get_point_count():
		var dist := point.distance_to(curve.get_point_position(p))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = p

	return closest_index


func get_shader_parameter(param: String):
	return _material.get_shader_parameter(param)


# Parameter Setters
func set_step_length_divs(value: int) -> void:
	shape_step_length_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_step_width_divs(value: int) -> void:
	shape_step_width_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_smoothness(value: float) -> void:
	shape_smoothness = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("i_valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_lod0_distance(value: float) -> void:
	lod_lod0_distance = value
	set_materials("i_lod0_distance", value)


# Private Methods
func _generate_river() -> void:
	var average_width := WaterHelperMethods.sum_array(widths) / float(widths.size() / 2)
	_steps = int(max(1.0, round(curve.get_baked_length() / average_width)))

	var river_width_values := WaterHelperMethods.generate_river_width_values(curve, _steps, shape_step_length_divs, shape_step_width_divs, widths)
	_mesh_instance.mesh = WaterHelperMethods.generate_river_mesh(curve, _steps, shape_step_length_divs, shape_step_width_divs, shape_smoothness, river_width_values)
	_mesh_instance.mesh.surface_set_material(0, _material)


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
