# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterSystem = preload("res://addons/waterways/water_system_manager.gd")


export var water_system_group_name : String = "waterways_system"
export(float, 0.0, 200.0) var buoyancy_force := 50.0
export(float, 0.0, 20.0) var up_correcting_force := 5.0
export(float, 0.0, 200.0) var flow_force := 50.0
export(float, 0.0, 30.0) var water_resistance := 5.0

var _rb : RigidBody
var _system : WaterSystem
var _default_linear_damp := -1.0
var _default_angular_damp := -1.0


func _enter_tree() -> void:
	var parent = get_parent()
	if parent is RigidBody:
		_rb = parent as RigidBody
		_default_linear_damp = _rb.linear_damp
		_default_angular_damp = _rb.angular_damp


func _exit_tree() -> void:
	_rb = null


func _ready() -> void:
	var systems = get_tree().get_nodes_in_group(water_system_group_name)
	if systems.size() > 0:
		if systems[0] is WaterSystem:
			_system = systems[0] as WaterSystem


func _get_configuration_warning() -> String:
	if _rb == null:
		return "Bouyant node must be a direct child of a RigidBody to function."
	return ""


func _get_rotation_correction() -> Vector3:
	var rotation_transform := Transform()
	var up_vector := global_transform.basis.y
	var angle := up_vector.angle_to(Vector3.UP)
	if angle < 0.1:
		# Don't reaturn a rotation as object is almost upright, since the cross 
		# product at an angle that small might cause precission errors.
		return Vector3.ZERO
	var cross := up_vector.cross(Vector3.UP).normalized()
	rotation_transform = rotation_transform.rotated(cross, angle)
	return rotation_transform.basis.get_euler()


func _physics_process(delta: float) -> void:
	if Engine.editor_hint || _system == null || _rb == null:
		return
	var altitude = _system.get_water_altitude(global_transform.origin)
	if altitude < 0.0:
		var flow = _system.get_water_flow(global_transform.origin)
		_rb.add_central_force(Vector3.UP * buoyancy_force * -altitude)
		var rot = _get_rotation_correction()
		_rb.add_torque(rot * up_correcting_force)
		_rb.add_central_force(flow * flow_force)
		_rb.linear_damp = water_resistance
		_rb.angular_damp = water_resistance
	else:
		_rb.linear_damp = _default_linear_damp
		_rb.angular_damp = _default_angular_damp
