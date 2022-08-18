# Copyright © 2022 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

# Good luck

# Public variables
var curve : Curve3D

# Private variables
var _first_enter_tree := true

# Signals
signal lake_changed

func _enter_tree() -> void:
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false
	
	if not curve:
		curve = Curve3D.new()
		curve.bake_interval = 0.05
		# Default to a small circle? do we need to close it ourselves, or does curve have that ?
		curve.add_point(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.5), Vector3(0.0, 0.0, 0.5))
		curve.add_point(Vector3(0.0, 0.0, 1.0), Vector3(0.5, 0.0, 0.0), Vector3(-0.5, 0.0, 0.0))
		curve.add_point(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.5), Vector3(0.0, 0.0, -0.5))
		curve.add_point(Vector3(0.0, 0.0, -1.0), Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0))
		curve.add_point(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.5), Vector3(0.0, 0.0, 0.5))


func remove_point(index : int) -> void:
	# We don't allow lakes with less than 3 points
	if curve.get_point_count() <= 5:
		return
	curve.remove_point(index)
	emit_signal("lake_changed")


func get_curve_points() -> PoolVector3Array:
	var points : PoolVector3Array
	for p in curve.get_point_count():
		points.append(curve.get_point_position(p))
	
	return points


func set_curve_point_position(index : int, position : Vector3) -> void:
	curve.set_point_position(index, position)


func set_curve_point_in(index : int, position : Vector3) -> void:
	curve.set_point_in(index, position)


func set_curve_point_out(index : int, position : Vector3) -> void:
	curve.set_point_out(index, position)


func get_closest_point_to(point : Vector3) -> int:
	var points = []
	var closest_distance := 4096.0
	var closest_index
	for p in curve.get_point_count():
		var dist := point.distance_to(curve.get_point_position(p))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = p
	
	return closest_index

# Signal Methods
func properties_changed() -> void:
	emit_signal("lake_changed")
