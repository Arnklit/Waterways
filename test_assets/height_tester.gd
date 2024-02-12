@tool
extends MeshInstance3D

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")

@export var water_system_group_name : String = "waterways_system"

var _system : WaterSystem

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var systems = get_tree().get_nodes_in_group(water_system_group_name)
	if systems.size() > 0:
		if systems[0] is WaterSystem:
			_system = systems[0] as WaterSystem
	
	var altitude = _system.get_water_altitude(global_transform.origin)
	#print(altitude)
	
	var pos = Vector3(get_parent().global_transform.origin.x, altitude, get_parent().global_transform.origin.z)
	global_transform.origin = pos
	
