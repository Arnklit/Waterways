tool
extends Spatial

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")
const FilterRenderer = preload("res://addons/waterways/filter_renderer.tscn")
const RiverManager = preload("res://addons/waterways/river_manager.gd")

export var system_map : ImageTexture = null
export(int, "128", "256", "512", "1024", "2048") var resolution := 2
export var wet_group_name : String = "water_system"

export var system_aabb : AABB

func generate_system_maps() -> void:
	print("generate_system_maps called")
	var rivers := []

	for child in get_children():
		if child is RiverManager:
			rivers.append(child)
	
	# We need to make the aabb out of the first river, so we don't includee 0,0
	if rivers.size() > 0:
		system_aabb = rivers[0].mesh_instance.get_transformed_aabb()
	
	for river in rivers:
		var river_aabb = river.mesh_instance.get_transformed_aabb()
		system_aabb = system_aabb.merge(river_aabb)
	
	print("system_aabb: ", system_aabb)
	
	var renderer = SystemMapRenderer.instance()
	add_child(renderer)
	var res = pow(2, resolution + 7)
	print("resolution is: ", res)
	var flow_map = yield(renderer.grab_flow(rivers, system_aabb, res), "completed")
	var height_map = yield(renderer.grab_height(rivers, system_aabb, res), "completed")
	
	remove_child(renderer)
	
	var filter_renderer = FilterRenderer.instance()
	add_child(filter_renderer)
	
	system_map = yield(filter_renderer.apply_combine(flow_map, flow_map, height_map), "completed")
	
	remove_child(filter_renderer)
	
	# give the map and coordinates to all nodes in the wet_group
	var wet_nodes = get_tree().get_nodes_in_group(wet_group_name)
	for node in wet_nodes:
		node.get_surface_material(0).set_shader_param("water_systemmap", system_map)
		node.get_surface_material(0).set_shader_param("water_systemmap_coords", get_system_map_coordinates())


# Returns the flow vector from the system flowmap
func get_flow_vector(position : Vector3) -> Vector2:
	
	# Throw a warning if the map is not baked
	return Vector2(0.0, 0.0)


# Returns the vetical distance to the water, positive values above water level,
# negative numbers below the water
func get_water_altitude(query_pos : Vector3) -> float:
	var img = system_map.get_data()
	
	var position_in_aabb = query_pos - system_aabb.position
	var pos_2d = Vector2(position_in_aabb.x, position_in_aabb.z)
	pos_2d = pos_2d / system_aabb.get_longest_axis_size()
	if pos_2d.x > 1.0 or pos_2d.x < 0.0 or pos_2d.y > 1.0 or pos_2d.y < 0.0:
		return 0.0 # TODO return ocean level / minimum water level
	
	pos_2d = pos_2d * img.get_width()
	img.lock()
	var col = img.get_pixelv(pos_2d)
	img.unlock()
	if col.a == 0.0:
		return 0.0 # TODO return ocean level / minimum water level
	# Throw a warning if the map is not baked
	var height = col.b * system_aabb.size.y + system_aabb.position.y
	return query_pos.y - height


func get_water_flow(query_pos : Vector3) -> Vector3:
	var img = system_map.get_data()
	
	var position_in_aabb = query_pos - system_aabb.position
	var pos_2d = Vector2(position_in_aabb.x, position_in_aabb.z)
	pos_2d = pos_2d / system_aabb.get_longest_axis_size()
	if pos_2d.x > 1.0 or pos_2d.x < 0.0 or pos_2d.y > 1.0 or pos_2d.y < 0.0:
		return Vector3.ZERO
	
	pos_2d = pos_2d * img.get_width()
	img.lock()
	var col = img.get_pixelv(pos_2d)
	img.unlock()
	
	var flow = Vector3(col.r, 0.5, col.g) * 2.0 - Vector3(1.0, 1.0, 1.0)
	return flow


func get_system_map() -> ImageTexture:
	return system_map


func get_system_map_coordinates() -> Transform:
	# storing the AABB info in a transform, seems dodgy
	var offset = Transform(system_aabb.position, system_aabb.size, system_aabb.end, Vector3())
	return offset
