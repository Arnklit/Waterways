# Copyright © 2022 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

signal mode
signal options

var menu
var constraints


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


func _untoggle_buttons() -> void:
	$Select.pressed = false
	$Add.pressed = false
	$Remove.pressed = false
