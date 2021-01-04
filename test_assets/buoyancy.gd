extends Spatial

const WaterSystem = preload("res://addons/waterways/water_system.gd")

var _rb : RigidBody
var _water_system : WaterSystem

export var up_force = 1.0
export var flow_force = 1.0

func _ready() -> void:
	_rb = get_parent() as RigidBody
	_water_system = get_parent().get_parent().get_node("Water System") as WaterSystem


func _physics_process(delta: float) -> void:
	var altitude = _water_system.get_water_altitude(global_transform.origin)
	var flow = _water_system.get_water_flow(global_transform.origin)
	if altitude < 0.0:
		_rb.add_central_force(Vector3.UP * up_force * -altitude)
		_rb.add_central_force(flow * flow_force)
		_rb.linear_damp = 5.0
	else:
		_rb.linear_damp = -1
