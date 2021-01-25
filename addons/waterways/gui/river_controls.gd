# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends HBoxContainer

signal mode
signal options

enum CONSTRAINTS {
	NONE,
	COLLIDERS,
	AXIS_X,
	AXIS_Y,
	AXIS_Z,
	PLANE_YZ,
	PLANE_XZ,
	PLANE_XY,
}

var menu
var constraints

func _enter_tree() -> void:
	menu = $RiverMenu
	constraints = $Constraints


func spatial_gui_input(event: InputEvent) -> bool:
	# This uses the forwarded spatial input in order to not react to events
	# while the spatial editor is not in focus
	if event is InputEventKey and event.is_pressed() and not constraints.disabled:
		
		# Early exit if any of the modifiers (except shift) is pressed to not
		# override default shortcuts like Ctrl + Z
		if event.alt or event.control or event.meta or event.command:
			return false
		
		# Handle local mode keybinding for toggling
		if event.scancode == KEY_T:
			# Set the input as handled to prevent default actions from the keys
			$LocalMode.pressed = not $LocalMode.pressed
			get_tree().set_input_as_handled()
			return true
		
		# Fetch the constraint that the user requested to toggle
		var requested: int
		match [event.scancode, event.shift]:
			[KEY_S, _]: requested = CONSTRAINTS.COLLIDERS
			[KEY_X, false]: requested = CONSTRAINTS.AXIS_X
			[KEY_Y, false]: requested = CONSTRAINTS.AXIS_Y
			[KEY_Z, false]: requested = CONSTRAINTS.AXIS_Z
			[KEY_X, true]: requested = CONSTRAINTS.PLANE_YZ
			[KEY_Y, true]: requested = CONSTRAINTS.PLANE_XZ
			[KEY_Z, true]: requested = CONSTRAINTS.PLANE_XY
			_: return false
		
		# If the user requested the current selection, we toggle it instead to off
		if requested == constraints.selected:
			requested = CONSTRAINTS.NONE
		
		# Update the OptionsButton and call the signal callback as that is
		# only automatically called when the user clicks it
		constraints.select(requested)
		_on_constraint_selected(requested)
		
		# Set the input as handled to prevent default actions from the keys
		get_tree().set_input_as_handled()
		return true
	
	return false


func _on_select() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(false)
	$Select.pressed = true
	emit_signal("mode", "select")


func _on_add() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(false)
	$Add.pressed = true
	emit_signal("mode", "add")


func _on_remove() -> void:
	_untoggle_buttons()
	_disable_constraint_ui(true)
	$Remove.pressed = true
	emit_signal("mode", "remove")


func _on_constraint_selected(index: int) -> void:
	emit_signal("options", "constraint", index)


func _on_local_mode_toggled(enabled: bool) -> void:
	emit_signal("options", "local_mode", enabled)


func _disable_constraint_ui(disable: bool) -> void:
	$Constraints.disabled = disable
	$LocalMode.disabled = disable


func _untoggle_buttons() -> void:
	$Select.pressed = false
	$Add.pressed = false
	$Remove.pressed = false
