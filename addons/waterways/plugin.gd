# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorPlugin

const WaterHelperMethods = preload("./water_helper_methods.gd")
const WaterSystem = preload("./water_system_manager.gd")
const RiverManager = preload("./river_manager.gd")
const WaterfallManager = preload("./waterfall_manager.gd")
const WaterfallConfiguration = preload("./waterfall_configuration.gd")
const RiverGizmo = preload("./gui/river_gizmo.gd")
const WaterfallGizmo = preload("./gui/waterfall_gizmo.gd")
const InspectorPlugin = preload("./inspector_plugin.gd")
const ProgressWindow = preload("./gui/progress_window.tscn")
const RiverControls = preload("./gui/river_controls.gd")

var river_gizmo: RiverGizmo = RiverGizmo.new()
var waterfall_gizmo: WaterfallGizmo = WaterfallGizmo.new()
var gradient_inspector: InspectorPlugin = InspectorPlugin.new()

var _river_controls = preload("./gui/river_controls.tscn").instantiate()
var _water_system_controls = preload("./gui/water_system_controls.tscn").instantiate()
var _edited_node = null
var _progress_window = null
var _editor_selection : EditorSelection = null
var _heightmap_renderer = null
var _mode := "select"
var constraint: int = RiverControls.CONSTRAINTS.NONE
var local_editing := false


func _enter_tree() -> void:
	add_custom_type("River", "Node3D",RiverManager, preload("./icons/river.svg"))
	add_custom_type("Waterfall", "Node3D", WaterfallManager, preload("./icons/river.svg"))
	add_custom_type("WaterfallConfiguration", "Resource", WaterfallConfiguration, preload("./icons/river.svg"))
	add_custom_type("WaterSystem", "Node3D", preload("./water_system_manager.gd"), preload("./icons/system.svg"))
	add_custom_type("Buoyant", "Node3D", preload("./buoyant_manager.gd"), preload("./icons/buoyant.svg"))
	add_node_3d_gizmo_plugin(river_gizmo)
	add_node_3d_gizmo_plugin(waterfall_gizmo)
	add_inspector_plugin(gradient_inspector)
	river_gizmo.editor_plugin = self
	waterfall_gizmo.editor_plugin = self
	_river_controls.connect("mode", Callable(self, "_on_mode_change"))
	_river_controls.connect("options", Callable(self, "_on_option_change"))
	_progress_window = ProgressWindow.instantiate()
	_river_controls.add_child(_progress_window)
	_editor_selection = get_editor_interface().get_selection()
	_editor_selection.connect("selection_changed", Callable(self, "_on_selection_change"))
	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)


func _on_generate_flowmap_pressed() -> void:
	_edited_node.bake_texture()


func _on_generate_mesh_pressed() -> void:
	_edited_node.spawn_mesh()


func _on_debug_view_changed(index : int) -> void:
	_edited_node.set_debug_view(index)


func _on_generate_system_maps_pressed() -> void:
	_edited_node.generate_system_maps()


func _exit_tree() -> void:
	remove_custom_type("River")
	remove_custom_type("Waterfall")
	remove_custom_type("WaterfallConfiguration")
	remove_custom_type("WaterSystem")
	remove_custom_type("Buoyant")
	remove_node_3d_gizmo_plugin(river_gizmo)
	remove_node_3d_gizmo_plugin(waterfall_gizmo)
	remove_inspector_plugin(gradient_inspector)
	_river_controls.disconnect("mode", Callable(self, "_on_mode_change"))
	_river_controls.disconnect("options", Callable(self, "_on_option_change"))
	_editor_selection.disconnect("selection_changed", Callable(self, "_on_selection_change"))
	disconnect("scene_changed", Callable(self, "_on_scene_changed"));
	disconnect("scene_closed", Callable(self, "_on_scene_closed"));
	_hide_river_control_panel()
	_hide_water_system_control_panel()


func _handles(node):
	return node is RiverManager or node is WaterfallManager or node is WaterSystem


# TODO - I think this was commented out for 4.0 conversion and isn't needed anymore
#func _edit(node):
#	print("edit(), node is: ", node)
#	if node is RiverManager:
#		_show_river_control_panel()
#		_edited_node = node as RiverManager
#	if node is WaterSystem:
#		_show_water_system_control_panel()
#		_edited_node = node as WaterSystem


func _on_selection_change() -> void:
	_editor_selection = get_editor_interface().get_selection()
	var selected = _editor_selection.get_selected_nodes()
	
	_hide_water_system_control_panel()
	_hide_river_control_panel()
	
	if len(selected) == 0:
		return
	if selected[0] is RiverManager:
		_show_river_control_panel()
		_edited_node = selected[0] as RiverManager
		_river_controls.menu.debug_view_menu_selected = _edited_node.debug_view
		if not _edited_node.is_connected("progress_notified", Callable(self, "_river_progress_notified")):
			_edited_node.connect("progress_notified", Callable(self, "_river_progress_notified"))
	elif selected[0] is WaterfallManager:
		_edited_node = selected[0] as WaterfallManager
	elif selected[0] is WaterSystem:
		_show_water_system_control_panel()
		_edited_node = selected[0] as WaterSystem
	else:
		_edited_node = null


func _on_scene_changed(scene_root) -> void:
	_hide_river_control_panel()
	_hide_water_system_control_panel()


func _on_scene_closed(_value) -> void:
	_hide_river_control_panel()
	_hide_water_system_control_panel()


func _on_mode_change(mode) -> void:
	_mode = mode


func _on_option_change(option, value) -> void:
	if option == "constraint":
		constraint = value
		if constraint == RiverControls.CONSTRAINTS.COLLIDERS:
			# WaterHelperMethods.reset_all_colliders(_edited_node.get_tree().root)
			# TODO - figure out if this is needed any more
			pass
	elif option == "local_mode":
		local_editing = value


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _edited_node:
		return AFTER_GUI_INPUT_PASS
	
	if _edited_node is RiverManager:
		return _forward_3d_gui_input_river(camera, event)
	elif _edited_node is WaterfallManager:
		return AFTER_GUI_INPUT_PASS
	
	return AFTER_GUI_INPUT_PASS


func _forward_3d_gui_input_river(camera: Camera3D, event: InputEvent) -> int:
	var global_transform: Transform3D = _edited_node.transform
	if _edited_node.is_inside_tree():
		global_transform = _edited_node.get_global_transform()
	var global_inverse: Transform3D = global_transform.affine_inverse()
	
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		var ray_from = camera.project_ray_origin(event.position)
		var ray_dir = camera.project_ray_normal(event.position)
		var g1 = global_inverse * (ray_from)
		var g2 = global_inverse * (ray_from + ray_dir * 4096)
		
			
		# Iterate through points to find closest segment
		var curve_points = _edited_node.get_curve_points()
		var closest_distance = 4096.0
		var closest_segment = -1
		
		for point in curve_points.size() -1:
			var p1 = curve_points[point]
			var p2 = curve_points[point + 1]
			var result  = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
			var dist = result[0].distance_to(result[1])
			if dist < closest_distance:
				closest_distance = dist
				closest_segment = point
		
		# Iterate through baked points to find the closest position on the
		# curved path
		var baked_curve_points = _edited_node.curve.get_baked_points()
		var baked_closest_distance = 4096.0
		var baked_closest_point = Vector3()
		var baked_point_found = false
		
		for baked_point in baked_curve_points.size() - 1:
			var p1 = baked_curve_points[baked_point]
			var p2 = baked_curve_points[baked_point + 1]
			var result  = Geometry3D.get_closest_points_between_segments(p1, p2, g1, g2)
			var dist = result[0].distance_to(result[1])
			if dist < 0.1 and dist < baked_closest_distance:
				baked_closest_distance = dist
				baked_closest_point = result[0]
				baked_point_found = true
		
		# In case we were close enough to a line segment to find a segment,
		# but not close enough to the curved line
		if not baked_point_found:
			closest_segment = -1
		
		# We'll use this closest point to add a point in between if on the line
		# and to remove if close to a point
		if _mode == "select":
			if not event.pressed:
				river_gizmo.reset()
			return AFTER_GUI_INPUT_PASS
		if _mode == "add" and not event.pressed:
			# if we don't have a point on the line, we'll calculate a point
			# based of a plane of the last point of the curve
			if closest_segment == -1:
				var end_pos = _edited_node.curve.get_point_position(_edited_node.curve.get_point_count() - 1)
				var end_pos_global : Vector3 = _edited_node.to_global(end_pos)
					
				var z : Vector3 = _edited_node.curve.get_point_out(_edited_node.curve.get_point_count() - 1).normalized()
				var x := z.cross(Vector3.DOWN).normalized()
				var y := z.cross(x).normalized()
				var _handle_base_transform = Transform3D(
					Basis(x, y, z) * global_transform.basis,
					end_pos_global
				)
			
				var plane := Plane(end_pos_global, end_pos_global + camera.transform.basis.x, end_pos_global + camera.transform.basis.y)
				var new_pos
				if constraint == RiverControls.CONSTRAINTS.COLLIDERS:
					var space_state = _edited_node.get_world_3d().direct_space_state
					var ray_params = PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 4096)
					var result = space_state.intersect_ray(ray_params)
					if result:
						new_pos = result.position
					else:
						return AFTER_GUI_INPUT_PASS
				elif constraint == RiverControls.CONSTRAINTS.NONE:
					new_pos = plane.intersects_ray(ray_from, ray_from + ray_dir * 4096)
				
				elif constraint in RiverGizmo.AXIS_MAPPING:
					var axis: Vector3 = RiverGizmo.AXIS_MAPPING[constraint]
					if local_editing:
						axis = _handle_base_transform.basis * (axis)
					var axis_from = end_pos_global + (axis * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var axis_to = end_pos_global - (axis * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var ray_to = ray_from + (ray_dir * RiverGizmo.AXIS_CONSTRAINT_LENGTH)
					var result = Geometry3D.get_closest_points_between_segments(axis_from, axis_to, ray_from, ray_to)
					new_pos = result[0]
				
				elif constraint in RiverGizmo.PLANE_MAPPING:
					var normal: Vector3 = RiverGizmo.PLANE_MAPPING[constraint]
					if local_editing:
						normal = _handle_base_transform.basis * (normal)
					var projected : Vector3 = end_pos_global.project(normal)
					var direction : float = signf(projected.dot(normal))
					var distance : float = direction * projected.length()
					plane = Plane(normal, distance)
					new_pos = plane.intersects_ray(ray_from, ray_dir)
						
				baked_closest_point = _edited_node.to_local(new_pos)
			
			var ur := get_undo_redo()
			ur.create_action("Add River point")
			ur.add_do_method(_edited_node, "add_point", baked_closest_point, closest_segment)
			ur.add_do_method(_edited_node, "properties_changed")
			ur.add_do_method(_edited_node, "set_materials", "i_valid_flowmap", false)
			ur.add_do_property(_edited_node, "valid_flowmap", false)
			ur.add_do_method(_edited_node, "update_configuration_warnings")
			if closest_segment == -1:
				ur.add_undo_method(_edited_node, "remove_point", _edited_node.curve.get_point_count()) # remove last
			else:
				ur.add_undo_method(_edited_node, "remove_point", closest_segment + 1)
			ur.add_undo_method(_edited_node, "properties_changed")
			ur.add_undo_method(_edited_node, "set_materials", "i_valid_flowmap", _edited_node.valid_flowmap)
			ur.add_undo_property(_edited_node, "valid_flowmap", _edited_node.valid_flowmap)
			ur.add_undo_method(_edited_node, "update_configuration_warnings")
			ur.commit_action()
		if _mode == "remove" and not event.pressed:
			# A closest_segment of -1 means we didn't press close enough to a
			# point for it to be removed
			if not closest_segment == -1: 
				var closest_index = _edited_node.get_closest_point_to(baked_closest_point)
				#_edited_node.remove_point(closest_index)
				var ur = get_undo_redo()
				ur.create_action("Remove River point")
				ur.add_do_method(_edited_node, "remove_point", closest_index)
				ur.add_do_method(_edited_node, "properties_changed")
				ur.add_do_method(_edited_node, "set_materials", "i_valid_flowmap", false)
				ur.add_do_property(_edited_node, "valid_flowmap", false)
				ur.add_do_method(_edited_node, "update_configuration_warnings")
				if closest_index == _edited_node.curve.get_point_count() - 1:
					ur.add_undo_method(_edited_node, "add_point", _edited_node.curve.get_point_position(closest_index), -1)
				else:
					ur.add_undo_method(_edited_node, "add_point", _edited_node.curve.get_point_position(closest_index), closest_index - 1, _edited_node.curve.get_point_out(closest_index), _edited_node.widths[closest_index])
				ur.add_undo_method(_edited_node, "properties_changed")
				ur.add_undo_method(_edited_node, "set_materials", "i_valid_flowmap", _edited_node.valid_flowmap)
				ur.add_undo_property(_edited_node, "valid_flowmap", _edited_node.valid_flowmap)
				ur.add_undo_method(_edited_node, "update_configuration_warnings")
				ur.commit_action()
		return AFTER_GUI_INPUT_STOP
	
	elif _edited_node is RiverManager:
		# Forward input to river controls. This is cleaner than handling
		# the keybindings here as the keybindings need to interact with
		# the buttons. Handling it here would expose more private details
		# of the controls than needed, instead only the spatial_gui_input()
		# method needs to be exposed.
		# TODO - so this was returning a bool before? Check this
		return _river_controls.spatial_gui_input(event)
	return AFTER_GUI_INPUT_PASS


func _river_progress_notified(progress : float, message : String) -> void:
	if message == "finished":
		_progress_window.hide()
	
	else:
		if not _progress_window.visible:
			_progress_window.popup_centered()
		
		_progress_window.show_progress(message, progress)


func _show_river_control_panel() -> void:
	if not _river_controls.get_parent():
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
		_river_controls.menu.connect("generate_flowmap", Callable(self, "_on_generate_flowmap_pressed"))
		_river_controls.menu.connect("generate_mesh", Callable(self, "_on_generate_mesh_pressed"))
		_river_controls.menu.connect("debug_view_changed", Callable(self, "_on_debug_view_changed"))


func _hide_river_control_panel() -> void:
	if _river_controls.get_parent():
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _river_controls)
		_river_controls.menu.disconnect("generate_flowmap", Callable(self, "_on_generate_flowmap_pressed"))
		_river_controls.menu.disconnect("generate_mesh", Callable(self, "_on_generate_mesh_pressed"))
		_river_controls.menu.disconnect("debug_view_changed", Callable(self, "_on_debug_view_changed"))


func _show_water_system_control_panel() -> void:
	if not _water_system_controls.get_parent():
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
		_water_system_controls.menu.connect("generate_system_maps", Callable(self, "_on_generate_system_maps_pressed"))


func _hide_water_system_control_panel() -> void:
	if _water_system_controls.get_parent():
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _water_system_controls)
		_water_system_controls.menu.disconnect("generate_system_maps", Callable(self, "_on_generate_system_maps_pressed"))
