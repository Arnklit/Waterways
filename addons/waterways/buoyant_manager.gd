# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")


export var water_system : NodePath
export var buoyancy_force := 50.0
export var flow_force := 50.0
export var water_resistance := 5.0

var _rb : RigidBody
var _system : WaterSystem

func _enter_tree() -> void:
	var systems = get_tree().get_nodes_in_group("waterways_systems")
	if systems.size() > 0:
		water_system = self.get_path_to(systems[0])


func _ready() -> void:
	_rb = get_parent() as RigidBody
	if water_system != "":
		_system = get_node(water_system) as WaterSystem


func _physics_process(delta: float) -> void:
	if Engine.editor_hint || _system == null:
		return
	var altitude = _system.get_water_altitude(global_transform.origin)
	var flow = _system.get_water_flow(global_transform.origin)
	if altitude < 0.0:
		_rb.add_central_force(Vector3.UP * buoyancy_force * -altitude)
		_rb.add_central_force(flow * flow_force)
		_rb.linear_damp = water_resistance
	else:
		_rb.linear_damp = -1
