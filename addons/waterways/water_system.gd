tool
extends Spatial

const SystemMapRenderer = preload("res://addons/waterways/system_map_renderer.tscn")


export var system_map : ImageTexture = null
export var resolution := 512.0

func generate_system_maps() -> void:
	var rivers = get_children()
	var renderer = SystemMapRenderer.instance()
	add_child(renderer)
	system_map = yield(renderer.grab_height(rivers, resolution), "completed")
	remove_child(renderer)
	print("generate_system_maps called")


# Returns the flow vector from the system flowmap
func get_flow_vector(position : Vector3) -> Vector2:
	
	# Throw a warning if the map is not baked
	return Vector2(0.0, 0.0)


# Returns the vetical distance to the water, positive values above water level,
# negative numbers below the water
func get_water_altitude(position : Vector3) -> float:
	
	
	# Throw a warning if the map is not baked
	return 0.0
