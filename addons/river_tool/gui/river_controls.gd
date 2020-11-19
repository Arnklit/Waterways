tool
extends HBoxContainer

signal mode


func _on_select() -> void:
	emit_signal("mode", "select")


func _on_add() -> void:
	emit_signal("mode", "add")


func _on_remove() -> void:
	emit_signal("mode", "remove")
