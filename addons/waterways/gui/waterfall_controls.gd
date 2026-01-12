@tool
extends HBoxContainer

signal mode
signal options

var menu
var lock_selection

var _mouse_down
var _lock_icon_open = preload("res://addons/waterways/icons/lock_open.svg")
var _lock_icon_closed = preload("res://addons/waterways/icons/lock_closed.svg")


func _enter_tree() -> void:
	menu = $WaterfallMenu
	lock_selection = $LockSelection


func spatial_gui_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		_mouse_down = event.pressed
	return false


func _on_lock_selection_toggled(enabled: bool) -> void:
	lock_selection.icon = _lock_icon_closed if enabled else _lock_icon_open
	emit_signal("options", "lock_selection", enabled)

