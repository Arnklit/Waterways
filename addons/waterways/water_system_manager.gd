# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")
const FilterRenderer = preload("res://addons/waterways/filter_renderer.tscn")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

var system_map : ImageTexture = null setget set_system_map
var system_bake_resolution := 2
var system_group_name := "waterways_system"
var minimum_water_level := 0.0
# Auto assign
var wet_group_name : String = "waterways_wet"
var surface_index : int = -1
var material_override : bool = false

var _system_aabb : AABB
var _system_img : Image
var _first_enter_tree := true

func _enter_tree() -> void:
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false
	add_to_group(system_group_name)


func _ready() -> void:
	if system_map != null:
		_system_img = system_map.get_data()
		_system_img.lock()
	else:
		push_warning("No WaterSystem map!")


func _exit_tree() -> void:
	remove_from_group("waterways_system")


func _get_configuration_warning() -> String:
	if system_map == null:
		return "No System Map is set. Select WaterSystem -> Generate System Map to generate and assign one."
	return ""


func _get_property_list() -> Array:
	return [
		{
			name = "system_map",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture"
		},
		{
			name = "system_bake_resolution",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "128, 256, 512, 1024, 2048",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "system_group_name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "minimum_water_level",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Auto assign texture & coordinates on generate",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "wet_group_name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "surface_index",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "material_override",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		# values that need to be serialized, but should not be exposed
		{
			name = "_system_aabb",
			type = TYPE_AABB,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


func generate_system_maps() -> void:
	var rivers := []

	for child in get_children():
		if child is RiverManager:
			rivers.append(child)
	
	# We need to make the aabb out of the first river, so we don't include 0,0
	if rivers.size() > 0:
		_system_aabb = rivers[0].mesh_instance.get_transformed_aabb()
	
	for river in rivers:
		var river_aabb = river.mesh_instance.get_transformed_aabb()
		_system_aabb = _system_aabb.merge(river_aabb)
	
	var renderer = SystemMapRenderer.instance()
	add_child(renderer)
	var resolution = pow(2, system_bake_resolution + 7)
	var flow_map = yield(renderer.grab_flow(rivers, _system_aabb, resolution), "completed")
	var height_map = yield(renderer.grab_height(rivers, _system_aabb, resolution), "completed")
	var alpha_map = yield(renderer.grab_alpha(rivers, _system_aabb, resolution), "completed")
	
	remove_child(renderer)
	
	var filter_renderer = FilterRenderer.instance()
	add_child(filter_renderer)
	
	#var dilated_height = yield(filter_renderer.apply_dilate(alpha_map, 0.1, 1.0, resolution, height_map), "completed")
	self.system_map = yield(filter_renderer.apply_combine(flow_map, flow_map, height_map), "completed")
	
	remove_child(filter_renderer)
	
	# give the map and coordinates to all nodes in the wet_group
	var wet_nodes = get_tree().get_nodes_in_group(wet_group_name)
	for node in wet_nodes:
		var material
		if surface_index != -1:
			if node.get_surface_material_count() > surface_index:
				material = node.get_surface_material(surface_index)
		if material_override:
			material = node.material_override
		
		if material != null:
			material.set_shader_param("water_systemmap", system_map)
			material.set_shader_param("water_systemmap_coords", get_system_map_coordinates())


# Returns the vetical distance to the water, positive values above water level,
# negative numbers below the water
func get_water_altitude(query_pos : Vector3) -> float:
	if _system_img == null:
		return query_pos.y - minimum_water_level
	var position_in_aabb = query_pos - _system_aabb.position
	var pos_2d = Vector2(position_in_aabb.x, position_in_aabb.z)
	pos_2d = pos_2d / _system_aabb.get_longest_axis_size()
	if pos_2d.x > 1.0 or pos_2d.x < 0.0 or pos_2d.y > 1.0 or pos_2d.y < 0.0:
		# We are outside the aabb of the Water System
		return query_pos.y - minimum_water_level
	
	pos_2d = pos_2d * _system_img.get_width()
	var col = _system_img.get_pixelv(pos_2d)
	if col == Color(0, 0, 0, 1):
		# We hit the empty part of the System Map
		return query_pos.y - minimum_water_level
	# Throw a warning if the map is not baked
	var height = col.b * _system_aabb.size.y + _system_aabb.position.y
	return query_pos.y - height


# Returns the flow vector from the system flowmap
func get_water_flow(query_pos : Vector3) -> Vector3:
	if _system_img == null:
		return Vector3.ZERO
	var position_in_aabb = query_pos - _system_aabb.position
	var pos_2d = Vector2(position_in_aabb.x, position_in_aabb.z)
	pos_2d = pos_2d / _system_aabb.get_longest_axis_size()
	if pos_2d.x > 1.0 or pos_2d.x < 0.0 or pos_2d.y > 1.0 or pos_2d.y < 0.0:
		return Vector3.ZERO
	
	pos_2d = pos_2d * _system_img.get_width()
	var col = _system_img.get_pixelv(pos_2d)
	
	if col == Color(0, 0, 0, 1):
		# We hit the empty part of the System Map
		return Vector3.ZERO
	
	var flow = Vector3(col.r, 0.5, col.g) * 2.0 - Vector3(1.0, 1.0, 1.0)
	return flow


func get_system_map() -> ImageTexture:
	return system_map


func get_system_map_coordinates() -> Transform:
	# storing the AABB info in a transform, seems dodgy
	var offset = Transform(_system_aabb.position, _system_aabb.size, _system_aabb.end, Vector3())
	return offset


func set_system_map(texture : ImageTexture) -> void:
	system_map = texture
	if _first_enter_tree:
		return
	property_list_changed_notify()
	update_configuration_warning()
