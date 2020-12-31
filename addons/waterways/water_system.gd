tool
extends Spatial

const WaterHelperMethods = preload("./water_helper_methods.gd")


export var heightmap : ImageTexture = null
export var flowmap : ImageTexture = null
export var resolution := 512.0

func generate_system_maps() -> void:
	# Get all the waterways nodes that are children of this water system
	# and send them to the system baker
	pass



# Returns the flow vector from the system flowmap
func get_flow_vector(position : Vector3) -> Vector2:
	
	# Throw a warning if the map is not baked
	return Vector2(0.0, 0.0)


# Returns the vetical distance to the water, positive values above water level,
# negative numbers below the water
func get_water_altitude(position : Vector3) -> float:
	
	
	# Throw a warning if the map is not baked
	return 0.0
