tool
extends EditorPlugin

signal mode

const RiverGizmoPlugin = preload("res://addons/river_tool/river_gizmo_plugin.gd")
const River2Manager = preload("res://addons/river_tool/river2_manager.gd")


var river_gizmo_plugin = RiverGizmoPlugin.new()

var _edited_node = null
var _editor_selection : EditorSelection = null
var _river2_gizmo = load("res://addons/river_tool/river2_gizmo_plugin.gd").new()
var _path_controls = preload("res://addons/river_tool/gui/river_controls.tscn").instance()
var _mode = "select"

func _enter_tree() -> void:
	add_custom_type("River", "Spatial", preload("res://addons/river_tool/river_manager.gd"), preload("icon.png"))
	add_spatial_gizmo_plugin(river_gizmo_plugin)
	river_gizmo_plugin.editor_plugin = self
	
	add_custom_type("River2", "Spatial", preload("res://addons/river_tool/river2_manager.gd"), preload("icon.png"))
	_register_gizmos()
	_register_signals()


func _exit_tree() -> void:
	remove_custom_type("River")
	remove_spatial_gizmo_plugin(river_gizmo_plugin)
	# New
	remove_custom_type("River2")
	_deregister_gizmos()
	_deregister_signals()


func handles(node):
	return node is River2Manager


func edit(node):
	_show_control_panel()
	_edited_node = node as River2Manager


func _register_gizmos():
	add_spatial_gizmo_plugin(_river2_gizmo)
	_path_controls.connect("mode", self, "_on_mode_change")


func _deregister_gizmos():
	remove_spatial_gizmo_plugin(_river2_gizmo)
	_hide_control_panel()
	disconnect("mode", self, "_on_mode_change")


func _register_signals():
	_editor_selection = get_editor_interface().get_selection()
	_editor_selection.connect("selection_changed", self, "_on_selection_change")


func _deregister_signals():
	_editor_selection.disconnect("selection_changed", self, "_on_selection_change")


func _on_selection_change():
	_editor_selection = get_editor_interface().get_selection()
	var selected = _editor_selection.get_selected_nodes()
	if len(selected) == 0 or not selected[0] is River2Manager:
		_edited_node = null
		if _path_controls.get_parent():
			_hide_control_panel()

func _on_mode_change(mode):
	print("Selected mode : ", mode)
	_mode = mode


func _show_control_panel():
	if not _path_controls.get_parent():
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _path_controls)


func _hide_control_panel():
	if _path_controls.get_parent():
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _path_controls)
