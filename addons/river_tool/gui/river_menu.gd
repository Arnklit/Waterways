tool
extends MenuButton

signal generate_flowmap
signal debug_view_changed

enum RIVER_MENU {
	GENERATE,
	DEBUG_VIEW_MENU
}

enum DEBUG_VIEW_MENU {
	DISPLAY_NORMAL,
	DISPLAY_FLOWMAP,
	DISPLAY_FOAMMAP
}

var _debug_view_menu : PopupMenu
var _debug_view_menu_selected := 0

func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", self, "_menu_item_selected")
	get_popup().add_item("Generate Flow & Foam Map")
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
			print("Generate Pressed")
			emit_signal("generate_flowmap")
		RIVER_MENU.DEBUG_VIEW_MENU:
			print("Debug View Pressed")


func _debug_menu_item_selected(index: int) -> void:
	print("debug_menu item pressed: ", index)
	_debug_view_menu_selected = index
	emit_signal("debug_view_changed", index)


func _on_debug_view_menu_about_to_show() -> void:
	_debug_view_menu.clear()
	_debug_view_menu.add_radio_check_item("Display Normal")
	_debug_view_menu.add_radio_check_item("Display Flowmap")
	_debug_view_menu.add_radio_check_item("Display Foammap")
	_debug_view_menu.set_item_checked(_debug_view_menu_selected, true)
