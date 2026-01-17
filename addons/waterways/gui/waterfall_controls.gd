@tool
extends HBoxContainer

signal mode
signal options

var menu


func _enter_tree() -> void:
	menu = $WaterfallMenu
