# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends HBoxContainer

var menu

func _enter_tree() -> void:
	menu = $WaterSystemMenu
