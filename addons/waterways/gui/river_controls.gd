# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

signal mode
signal options

var menu

func _enter_tree() -> void:
	menu = $RiverMenu


func _on_select() -> void:
	_untoggle_buttons()
	$Select.pressed = true
	emit_signal("mode", "select")


func _on_add() -> void:
	_untoggle_buttons()
	$Add.pressed = true
	emit_signal("mode", "add")


func _on_remove() -> void:
	_untoggle_buttons()
	$Remove.pressed = true
	emit_signal("mode", "remove")


func _on_snap_to_colliders(value: bool) -> void:
	emit_signal("options", "snap_to_colliders", value)


func _untoggle_buttons() -> void:
	$Select.pressed = false
	$Add.pressed = false
	$Remove.pressed = false
