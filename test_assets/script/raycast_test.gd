@tool
extends Node3D

@export var do_cast := false: set = perform_cast

# Called when the node enters the scene tree for the first time.
func perform_cast(_value) -> void:
	
	var ray_params := PhysicsRayQueryParameters3D.create(Vector3(0.0, 5.0, 0.0), Vector3(0.0, 0.0, 0.0))
	
	var space_state = $MeshInstance3D.get_world_3d().direct_space_state
	print("space state:")
	print(space_state)
	
	var result_down = space_state.intersect_ray(ray_params)
	
	print("TADA")
	print(result_down)
	print("ray_params")
	print(var_to_str(ray_params))
