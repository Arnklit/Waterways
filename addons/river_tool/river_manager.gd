# Copyright © 2020 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterHelperMethods = preload("res://addons/river_tool/water_helper_methods.gd")

const DEFAULT_SHADER_PATH = "res://addons/river_tool/shaders/river.shader"
const DEFAULT_WATER_TEXTURE_PATH = "res://addons/river_tool/textures/water1.png"
const FILTER_RENDERER_PATH = "res://addons/river_tool/FilterRenderer.tscn"

# Shape Properties
export(int, 1, 100) var steps := 6 setget set_steps
export(int, 1, 8) var step_length_divs := 1 setget set_step_length_divs
export(int, 1, 8) var step_width_divs := 1 setget set_step_width_divs
export(float, 0.1, 5.0) var smoothness = 0.5 setget set_smoothness
export(bool) var bake_flowmap setget set_bake_flowmap
export(Texture) var distance_texture
export(Texture) var normal_texture
export(Texture) var flowmap_texture
export(Texture) var blurred_flowmap_texture
export(Texture) var foam_texture
export(Texture) var combined_texture
export(int) var flowmap_resolution = 256

# Material Properties
export(Color, RGBA) var albedo = Color(0.1, 0.1, 0.1, 0.0) setget set_albedo 
export(float, 0.0, 1.0) var roughness = 0.2 setget set_roughness
export(float, -1.0, 1.0) var refraction = 0.05 setget set_refraction
export(Texture) var texture_water setget set_water_texture
export(float, -16.0, 16.0) var normal_scale = 1.0 setget set_normal_scale
export(float, 0.0, 1.0) var absorption = 0.0 setget set_absorption
export(float, 0.0, 10.0) var flow_speed = 1.0 setget set_flowspeed

var river_width_values := [] setget set_river_width_values

var _st : SurfaceTool
var _mdt : MeshDataTool
var _mesh_instance : MeshInstance
var _default_shader : Shader
var _material : Material
var _first_enter_tree = true
var _parent_object 
var _filter_renderer
var parent_is_path := false

# Signal used to update handles immedieately when values are changed in script
signal river_changed


# This is to serialize river_width_values without exposing it in the inspector
func _get_property_list() -> Array:
	return [
		{
			name = "river_width_values",
			type = TYPE_AABB,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


func _init() -> void:
	print("init called")
	_default_shader = load(DEFAULT_SHADER_PATH) as Shader
	_material = ShaderMaterial.new()
	_material.shader = _default_shader
	set_water_texture(load(DEFAULT_WATER_TEXTURE_PATH))
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)


func _enter_tree() -> void:
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false
	print("enter tree called")
	
	_analyse_parent()
	
	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance.new()
		new_mesh_instance.name = "RiverMeshInstance"
		add_child(new_mesh_instance)
		# Uncomment for debugging the MeshInstance object
		new_mesh_instance.set_owner(get_tree().get_edited_scene_root()) 
	_mesh_instance = get_child(0)
	_generate_river()


func _exit_tree() -> void:
	if parent_is_path:
		var parent_path = _parent_object as Path
		parent_path.disconnect("curve_changed", self, "_on_Path_curve_changed")
	parent_is_path = false
	
	
func _get_configuration_warning() -> String:
	if not parent_is_path:
		return "Parent must be a Path node!"
	return ""


# Getter Methods
func get_step_points() -> PoolVector3Array:
	var array : PoolVector3Array
	var curve_length = _parent_object.curve.get_baked_length()
	for step in steps + 1:
		var position = _parent_object.curve.interpolate_baked(float(step) / float(steps)  * curve_length, false)
		array.append(position)
	return array


func get_step_points_directions() -> PoolVector3Array:
	var array : PoolVector3Array
	var curve_length = _parent_object.curve.get_baked_length()
	for step in steps + 1:
		var backward_pos = _parent_object.curve.interpolate_baked((float(step) - smoothness) / float(steps) * curve_length, false)
		var forward_pos = _parent_object.curve.interpolate_baked((float(step) + smoothness) / float(steps) * curve_length, false)
		var forward_vector = forward_pos - backward_pos
		array.append(forward_vector)
	return array


# Setter Methods
func set_steps(value : int) -> void:
	print("set_steps to: " + str(value))
	steps = value
	if _first_enter_tree:
		return
	var old_river_width_values = river_width_values
	print("old_river_width_values.size() is: " + str(old_river_width_values.size()))
	river_width_values = []
	for step in steps + 1:
		var interpol = float(step) / float(steps + 2)
		var interpol_old = interpol * float(old_river_width_values.size())
		var interpolated_value = lerp(old_river_width_values[int(interpol_old)], old_river_width_values[int(interpol_old) + 1], fmod(interpol_old, 1.0))
		river_width_values.append(interpolated_value)
	river_width_values.append(river_width_values.back())
	_generate_river()
	emit_signal("river_changed")


func set_step_length_divs(value : int) -> void:
	step_length_divs = value
	if _first_enter_tree:
		return
	_generate_river()
	emit_signal("river_changed")


func set_step_width_divs(value : int) -> void:
	step_width_divs = value
	if _first_enter_tree:
		return
	_generate_river()
	emit_signal("river_changed")


func set_smoothness(value : float) -> void:
	smoothness = value
	if _first_enter_tree:
		return
	_generate_river()
	emit_signal("river_changed")


func set_bake_flowmap(value : bool) -> void:
	if _first_enter_tree:
		return
	generate_flowmap()

func set_albedo(color : Color) -> void:
	albedo = color
	_material.set_shader_param("albedo", color)


func set_roughness(value : float) -> void:
	roughness = value
	_material.set_shader_param("roughness", value)


func set_refraction(value : float) -> void:
	refraction = value
	_material.set_shader_param("refraction", value)


func set_water_texture(texture : Texture) -> void:
	texture_water = texture
	_material.set_shader_param("texture_water", texture)


func set_normal_scale(value : float) -> void:
	normal_scale = value
	_material.set_shader_param("normal_scale", value)


func set_absorption(value : float) -> void:
	absorption = value
	_material.set_shader_param("absorption", value)


func set_flowspeed(value : float) -> void:
	flow_speed = value
	_material.set_shader_param("flow_speed", value)
	

func set_river_width_values(widths : Array) -> void:
	river_width_values = widths
	if _first_enter_tree:
		return
	_generate_river()


# Private Methods
func _analyse_parent() -> void:
	_parent_object = get_parent()
	if _parent_object.get_class() == "Path":
		parent_is_path = true
		var parent_path = _parent_object as Path
		parent_path.connect("curve_changed", self, "_on_Path_curve_changed")


func _generate_river() -> void:
	#print("Generete river called")
	
	if not parent_is_path:
		return
		
	if _parent_object.curve.get_point_count() < 2:
		return
	if river_width_values.size() == 0:
		for step in steps + 2:
			river_width_values.append(0.5)
	
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve_length = _parent_object.curve.get_baked_length()
	_st.add_smooth_group(true)
	
	for step in steps + 1:
		for l_sub in step_length_divs:
			var subdivision_offset = (float(l_sub) / float(step_length_divs)) * (curve_length / float(steps))
			#print("subdiv offset: " + str(subdivision_offset))
			var position = _parent_object.curve.interpolate_baked((float(step) / float(steps) * curve_length) + subdivision_offset, false)
			var backward_pos = _parent_object.curve.interpolate_baked((float(step) + subdivision_offset - smoothness) / float(steps) * curve_length, false)
			var forward_pos = _parent_object.curve.interpolate_baked((float(step) + subdivision_offset + smoothness) / float(steps) * curve_length, false)
			var forward_vector = forward_pos - backward_pos
			var right_vector = forward_vector.cross(Vector3.UP).normalized()
			var width_lerp = lerp(river_width_values[step], river_width_values[step + 1], smoothstep(0.0, 1.0, float(l_sub) / float(step_length_divs)))
			
			for w_sub in step_width_divs + 1:
				_st.add_uv(Vector2(float(w_sub) / (float(step_width_divs)), float(step) + float(l_sub) / float(step_length_divs) ))
				_st.add_vertex(position + right_vector * width_lerp - 2.0 * right_vector * width_lerp * float(w_sub) / (float(step_width_divs)))
	
	for step in steps * (step_length_divs):
		for w_sub in step_width_divs:
			_st.add_index( (step * (step_width_divs + 1)) + w_sub)
			_st.add_index( (step * (step_width_divs + 1)) + w_sub + 1)
			_st.add_index( (step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)
			
			_st.add_index( (step * (step_width_divs + 1)) + w_sub + 1)
			_st.add_index( (step * (step_width_divs + 1)) + w_sub + 3 + step_width_divs - 1)
			_st.add_index( (step * (step_width_divs + 1)) + w_sub + 2 + step_width_divs - 1)
	
	_st.generate_normals()
	_st.generate_tangents()
	_st.deindex()
	
	var mesh = ArrayMesh.new()
	var mesh2 =  ArrayMesh.new()
	mesh = _st.commit()
	
	_mdt.create_from_surface(mesh, 0)
	
	# Generate UV2
	# Decide on grid size
	var grid_side = sqrt(steps)
	if fmod(grid_side, 1.0) != 0.0:
		grid_side += 1
	grid_side = int(grid_side)
	var grid_side_length = 1.0 / float(grid_side)
	var x_grid_sub_length = grid_side_length / float(step_width_divs)
	var y_grid_sub_length = grid_side_length / float(step_length_divs)
	var grid_size = pow(grid_side, 2)
	var index := 0
	var UVs := steps * step_width_divs * step_length_divs * 6
	var x_offset := 0.0
	for x in grid_side:
		var y_offset := 0.0
		for y in grid_side:
			
			if index < UVs:
				var sub_y_offset := 0.0
				for sub_y in step_length_divs:
					var sub_x_offset := 0.0
					for sub_x in step_width_divs:
						var x_comb_offset = x_offset + sub_x_offset
						var y_comb_offset = y_offset + sub_y_offset
						_mdt.set_vertex_uv2(index, Vector2(x_comb_offset, y_comb_offset))
						_mdt.set_vertex_uv2(index + 1, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset))
						_mdt.set_vertex_uv2(index + 2, Vector2(x_comb_offset, y_comb_offset + y_grid_sub_length))
						
						_mdt.set_vertex_uv2(index + 3, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset))
						_mdt.set_vertex_uv2(index + 4, Vector2(x_comb_offset + x_grid_sub_length, y_comb_offset + y_grid_sub_length))
						_mdt.set_vertex_uv2(index + 5, Vector2(x_comb_offset, y_comb_offset + y_grid_sub_length))
						index += 6
						sub_x_offset += grid_side_length / float(step_width_divs)
					sub_y_offset += grid_side_length / float(step_length_divs)
					
			y_offset += grid_side_length
		x_offset += grid_side_length
	
	_mdt.commit_to_surface(mesh2)
	_mesh_instance.mesh = mesh2
	_mesh_instance.mesh.surface_set_material(0, _material)


func generate_flowmap() -> void:
	WaterHelperMethods.reset_all_colliders(get_tree().root)

	var image := Image.new()
	image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	image.lock()
	var space_state := get_world().direct_space_state
	var uv2 := _mesh_instance.mesh.surface_get_arrays(0)[5] as PoolVector2Array
	var verts := _mesh_instance.mesh.surface_get_arrays(0)[0] as PoolVector3Array
	# We need to move the verts into world space
	var world_verts : PoolVector3Array = []
	for v in verts.size():
		world_verts.append( global_transform.xform(verts[v]) )
	
	for x in image.get_width():
		for y in image.get_height():
			#print("***NEW PIXEL***")
			var uv_coordinate := Vector2( ( 0.5 + float(x))  / float(image.get_width()), ( 0.5 + float(y)) / float(image.get_height()) )
			#print("uv_coordinate: " + str(uv_coordinate))
			var baryatric_coords
			var correct_triangle := []
			for tris in uv2.size() / 3:
				var triangle : PoolVector2Array = []
				triangle.append(uv2[tris * 3])
				triangle.append(uv2[tris * 3 + 1])
				triangle.append(uv2[tris * 3 + 2])
				if Geometry.is_point_in_polygon(uv_coordinate, triangle):
					var p = Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
					var a = Vector3(uv2[tris * 3].x, uv2[tris * 3].y, 0.0)
					var b = Vector3(uv2[tris * 3 + 1].x, uv2[tris * 3 + 1].y, 0.0)
					var c = Vector3(uv2[tris * 3 + 2].x, uv2[tris * 3 + 2].y, 0.0)
					baryatric_coords = WaterHelperMethods.cart2bary(p, a, b, c)
					correct_triangle = [tris * 3, tris * 3 + 1, tris * 3 + 2]
					#print("correct_triangle: " + str(correct_triangle))
					break
			
			# If there is no correct triangle we are in the empty part of the UV2 map and should draw nothing
			if correct_triangle:
				var vert0 = world_verts[correct_triangle[0]] 
				var vert1 = world_verts[correct_triangle[1]] 
				var vert2 = world_verts[correct_triangle[2]]
				#print("vert0: " + str(vert0) + ", vert1: " + str(vert1) + ", vert2: " + str(vert2))
				
				var real_pos = WaterHelperMethods.bary2cart(vert0, vert1, vert2, baryatric_coords)
				var real_pos_up = real_pos + Vector3.UP * 10.0
				#print("real_pos: " + str(real_pos))
				
				var result_up = space_state.intersect_ray(real_pos, real_pos_up)
				var result_down = space_state.intersect_ray(real_pos_up, real_pos)
				
				var up_hit_frontface = false
				if result_up:
					if result_up.normal.y < 0:
						true
				
				if result_up or result_down:
					#print("hit something")
					#image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
					if not up_hit_frontface and result_down:
						image.set_pixel(x, y, Color(1.0, 1.0, 1.0))
	
	image.unlock()
	print("finished collision map")
	# Calculate how many colums are in UV2
	var grid_side = sqrt(steps)
	if fmod(grid_side, 1.0) != 0.0:
		grid_side += 1
	grid_side = int(grid_side)
	print("grid_side: " + str(grid_side))
	var margin = int(round(float(flowmap_resolution) / float(grid_side)))
	print("margin: " + str(margin))
	var with_margins_size = flowmap_resolution + 2 * margin
	print("with_margins_size: " + str(with_margins_size))
	
	var image_with_margins := Image.new()
	image_with_margins.create(with_margins_size, with_margins_size, true, Image.FORMAT_RGB8)
	image_with_margins.lock()
	image_with_margins.blend_rect(image, Rect2(0.0, flowmap_resolution - margin, flowmap_resolution, margin), Vector2(margin + margin, 0.0))
	image_with_margins.blend_rect(image, Rect2(0.0, 0.0, flowmap_resolution, flowmap_resolution), Vector2(margin, margin))
	image_with_margins.blend_rect(image, Rect2(0.0, 0.0, flowmap_resolution, margin), Vector2(0.0, flowmap_resolution + margin))
	image_with_margins.unlock()
	
	var texture_to_dilate := ImageTexture.new()
	texture_to_dilate.create_from_image(image_with_margins)
	print("finished adding margins")
	# Create renderer for dilate filter
	var renderer_instance = _filter_renderer.instance()
	
	self.add_child(renderer_instance)
	
	var dilate_amount = 0.6 / float(grid_side + 2)
	print ("dilate_amount: " + str(dilate_amount))
	var dilated_texture = yield(renderer_instance.apply_dilate(texture_to_dilate, dilate_amount), "completed")
	print("dilate finished")
	var normal_map = yield(renderer_instance.apply_normal(dilated_texture), "completed")
	print("normal finished")
	var flow_map = yield(renderer_instance.apply_normal_to_flow(normal_map), "completed")
	print("flowmap finished")
	var blurred_flow_map = yield(renderer_instance.apply_blur(flow_map, 6.0), "completed")
	print("blurred_flowmap finished")
	var foam_map = yield(renderer_instance.apply_foam(dilated_texture, 0.05), "completed")
	print("foam_map finished")
	var blurred_foam_map = yield(renderer_instance.apply_blur(foam_map, 10.0), "completed")
	print("blurred_foam_map finished")
	var combined_map = yield(renderer_instance.apply_combine(blurred_flow_map, blurred_foam_map), "completed")
	print("combined_map finished")
	
	var dilate_result = dilated_texture.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var normal_result = normal_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var flowmap_result = flow_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var blurred_flowmap_result = blurred_flow_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var foam_map_result = blurred_foam_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	var combined_map_result = combined_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	
	distance_texture = ImageTexture.new()
	distance_texture.create_from_image(dilate_result)
	normal_texture = ImageTexture.new()
	normal_texture.create_from_image(normal_result)
	flowmap_texture = ImageTexture.new()
	flowmap_texture.create_from_image(flowmap_result)
	blurred_flowmap_texture = ImageTexture.new()
	blurred_flowmap_texture.create_from_image(blurred_flowmap_result, 5) # 5 should disable repeat
	foam_texture = ImageTexture.new()
	foam_texture.create_from_image(foam_map_result, 5)
	combined_texture = ImageTexture.new()
	combined_texture.create_from_image(combined_map_result, 5)
	
	print("finished map bake")
	_material.set_shader_param("flowmap", combined_texture)
	_material.set_shader_param("flowmap_set", true)


# Signal Methods
func _on_Path_curve_changed() -> void:
	if _first_enter_tree:
		return
	_generate_river()


func properties_changed() -> void:
	emit_signal("river_changed")
