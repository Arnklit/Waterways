# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends MenuButton

signal generate_system_maps

enum RIVER_MENU {
	GENERATE_SYSTEM_MAPS
}


func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", self, "_menu_item_selected")
	get_popup().add_item("Generate System Maps")


func _exit_tree() -> void:
	get_popup().disconnect("id_pressed", self, "_menu_item_selected")


func _menu_item_selected(index : int) -> void:
	match index:
		RIVER_MENU.GENERATE_SYSTEM_MAPS:
			emit_signal("generate_system_maps")
