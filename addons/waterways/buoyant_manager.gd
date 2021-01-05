# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")


export var water_system : NodePath setget set_water_system
export(float, 0.0, 200.0) var buoyancy_force := 50.0
export(float, 0.0, 200.0) var flow_force := 50.0
export(float, 0.0, 30.0) var water_resistance := 5.0

var _rb : RigidBody
var _system : WaterSystem


func _enter_tree() -> void:
	var parent = get_parent()
	if parent is RigidBody:
		_rb = parent as RigidBody
	var systems = get_tree().get_nodes_in_group("waterways_systems")
	if systems.size() > 0:
		self.water_system = self.get_path_to(systems[0])


func _exit_tree() -> void:
	_rb = null

func _ready() -> void:
	if water_system != "":
		var path_node = get_node(water_system)
		if path_node is WaterSystem:
			_system = path_node as WaterSystem


func _get_configuration_warning() -> String:
	if _rb == null:
		return "Bouyant node must be a direct child of a RigidBody to function."
	if water_system == "":
		return "Bouyant node must have a WaterSystem defined to function."
	return ""


func _physics_process(delta: float) -> void:
	if Engine.editor_hint || _system == null || _rb == null:
		return
	var altitude = _system.get_water_altitude(global_transform.origin)
	if altitude < 0.0:
		var flow = _system.get_water_flow(global_transform.origin)
		_rb.add_central_force(Vector3.UP * buoyancy_force * -altitude)
		_rb.add_central_force(flow * flow_force)
		_rb.linear_damp = water_resistance
		_rb.angular_damp = water_resistance
	else:
		_rb.linear_damp = -1
		_rb.angular_damp = -1


func set_water_system(path : NodePath) -> void:
	water_system = path
	update_configuration_warning()
