# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends MenuButton

signal generate_flowmap
signal generate_mesh
signal debug_view_changed

enum RIVER_MENU {
	GENERATE,
	GENERATE_MESH,
	DEBUG_VIEW_MENU
}

var debug_view_menu_selected := 0

var _debug_view_menu : PopupMenu


func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", self, "_menu_item_selected")
	get_popup().add_item("Generate Flow & Foam Map")
	get_popup().add_item("Generate MeshInstance Sibling")
	_debug_view_menu = PopupMenu.new()
	_debug_view_menu.name = "DebugViewMenu"
	_debug_view_menu.connect("about_to_show", self, "_on_debug_view_menu_about_to_show")
	_debug_view_menu.connect("id_pressed", self, "_debug_menu_item_selected")
	get_popup().add_child(_debug_view_menu)
	get_popup().add_submenu_item("Debug View", _debug_view_menu.name)


func _exit_tree() -> void:
	get_popup().disconnect("id_pressed", self, "_menu_item_selected")
	_debug_view_menu.disconnect("about_to_show", self, "_on_debug_view_menu_about_to_show")
	_debug_view_menu.disconnect("id_pressed", self, "_debug_menu_item_selected")


func _menu_item_selected(index : int) -> void:
	match index:
		RIVER_MENU.GENERATE:
			emit_signal("generate_flowmap")
		RIVER_MENU.GENERATE_MESH:
			emit_signal("generate_mesh")
		RIVER_MENU.DEBUG_VIEW_MENU:
			pass


func _debug_menu_item_selected(index: int) -> void:
	debug_view_menu_selected = index
	emit_signal("debug_view_changed", index)


func _on_debug_view_menu_about_to_show() -> void:
	_debug_view_menu.clear()
	_debug_view_menu.add_radio_check_item("Display Normal")
	_debug_view_menu.add_radio_check_item("Display Debug Flow Map (RG)")
	_debug_view_menu.add_radio_check_item("Display Debug Foam Map (B)")
	_debug_view_menu.add_radio_check_item("Display Debug Noise Map (A)")
	_debug_view_menu.add_radio_check_item("Display Debug Distance Field Map (R)")
	_debug_view_menu.add_radio_check_item("Display Debug Pressure Map (G)")
	_debug_view_menu.add_radio_check_item("Display Debug Flow Pattern")
	_debug_view_menu.add_radio_check_item("Display Debug Flow Arrows")
	_debug_view_menu.add_radio_check_item("Display Debug Flow Strength")
	_debug_view_menu.add_radio_check_item("Display Debug Foam Mix")
	_debug_view_menu.set_item_checked(debug_view_menu_selected, true)
