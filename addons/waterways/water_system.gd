tool
extends Spatial

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")


export var system_map : ImageTexture = null
export(int, "128", "256", "512", "1024", "2048") var resolution := 2
export var wet_group_name : String = "water_system"

var system_aabb : AABB

func generate_system_maps() -> void:
	print("generate_system_maps called")
	var rivers = get_children()
	system_aabb = rivers[0].mesh_instance.get_transformed_aabb()
	var renderer = SystemMapRenderer.instance()
	add_child(renderer)
	var res = pow(2, resolution + 7)
	system_map = yield(renderer.grab_height(rivers, res), "completed")
	remove_child(renderer)
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
	print("system_aabb.position: ", system_aabb.position)
	var position_in_aabb = query_pos - system_aabb.position
	print("position in aabb: ", position_in_aabb)
	var pos_2d = Vector2(position_in_aabb.x, position_in_aabb.z)
	print("pos_2d: ", pos_2d)
	pos_2d = pos_2d / system_aabb.get_longest_axis_size()
	if pos_2d.x > 1.0 or pos_2d.x < 0.0 or pos_2d.y > 1.0 or pos_2d.y < 0.0:
		print("value is outside texture")
		return 0.0 # TODO return ocean level / minimum water level
	print("pos_2d divided by longest: ", pos_2d)
	pos_2d = pos_2d * resolution
	print("pos_2d multiplied by resolution: ", pos_2d)
	var img = system_map.get_data()
	img.lock()
	var col = img.get_pixelv(pos_2d)
	img.unlock()
	print("col: ", col)
	if col.a == 0.0:
		print("we are in the transparent part of the texture")
		return 0.0 # TODO return ocean level / minimum water level
	# Throw a warning if the map is not baked
	var height = col.r * system_aabb.size.y + system_aabb.position.y
	print("height: ", height)
	return query_pos.y - height


func get_system_map() -> ImageTexture:
	return system_map


func get_system_map_coordinates() -> Transform:
	# storing the AABB info in a transform, seems dodgy
	var offset = Transform(system_aabb.position, system_aabb.size, system_aabb.end, Vector3())
	return offset
