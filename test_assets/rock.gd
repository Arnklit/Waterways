tool
extends MeshInstance


func _enter_tree() -> void:
	var water_system = get_tree().get_nodes_in_group("water_system")[0]
	
	var map = water_system.get_system_map()
	var map_coords = water_system.get_system_map_coordinates()
	material_override.set_shader_param("water_systemmap", map)
	material_override.set_shader_param("water_systemmap_coords", map_coords)

