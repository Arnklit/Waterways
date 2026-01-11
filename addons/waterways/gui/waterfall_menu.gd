@tool
extends MenuButton

signal generate_flowmap

enum WATERFALL_MENU {
	GENERATE_FLOWMAP
}


func _enter_tree() -> void:
	get_popup().clear()
	get_popup().connect("id_pressed", Callable(self, "_menu_item_selected"))
	get_popup().add_item("Generate Flow & Foam Map")


func _exit_tree() -> void:
	get_popup().disconnect("id_pressed", Callable(self, "_menu_item_selected"))


func _menu_item_selected(index: int) -> void:
	match index:
		WATERFALL_MENU.GENERATE_FLOWMAP:
			emit_signal("generate_flowmap")
