# Copyright © 2020 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial

const WaterHelperMethods = preload("res://addons/river_tool/water_helper_methods.gd")

const DEFAULT_SHADER_PATH = "res://addons/river_tool/shaders/river.shader"
const DEFAULT_WATER_TEXTURE_PATH = "res://addons/river_tool/textures/water1.png"
const FILTER_RENDERER_PATH = "res://addons/river_tool/FilterRenderer.tscn"
const NOISE_TEXTURE_PATH = "res://addons/river_tool/textures/noise.png"
const DEBUG_SHADER_PATH = "res://addons/river_tool/shaders/river_debug.shader"
const DEBUG_PATTERN_PATH = "res://addons/river_tool/textures/debug_pattern.png"

# Shape Properties
export(int, 1, 8) var step_length_divs := 1 setget set_step_length_divs
export(int, 1, 8) var step_width_divs := 1 setget set_step_width_divs
export(float, 0.1, 5.0) var smoothness = 0.5 setget set_smoothness

# Material Properties
export(Color, RGBA) var albedo = Color(0.1, 0.1, 0.1, 0.0) setget set_albedo
export(Color, RGBA) var foam_color = Color.white setget set_foam_color
export(float, 0.0, 4.0) var foam_amount = 1.0 setget set_foam_amount
export(float, 0.0, 1.0) var foam_smoothness = 1.0 setget set_foam_smoothness
export(float, 0.0, 1.0) var roughness = 0.2 setget set_roughness
export(float, -1.0, 1.0) var refraction = 0.05 setget set_refraction
export(Texture) var water_texture setget set_water_texture
export(float, 1.0, 20.0) var water_tiling = 1.0 setget set_water_tiling
export(float, -16.0, 16.0) var normal_scale = 1.0 setget set_normal_scale
export(float, 0.0, 1.0) var absorption = 0.0 setget set_absorption
export(float, 0.0, 10.0) var flow_speed = 1.0 setget set_flowspeed
export(float, 5.0, 100.0) var lod0_distance = 30.0 setget set_lod0_distance

var curve : Curve3D
var widths := [] setget set_widths
var valid_flowmap := false

var _steps := 2
var _st : SurfaceTool
var _mdt : MeshDataTool
var _mesh_instance : MeshInstance
var _default_shader : Shader
var _debug_shader : Shader
var _material : ShaderMaterial
var _debug_material : ShaderMaterial
var _first_enter_tree = true
var _filter_renderer
var _flow_foam_noise : Texture

# Signal used to update handles when values are changed on script side
signal river_changed


# This is to serialize values without exposing it in the inspector
func _get_property_list() -> Array:
	return [
		{
			name = "curve",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "widths",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "_flow_foam_noise",
			type = TYPE_OBJECT,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "valid_flowmap",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


func _init() -> void:
	print("init called")
	_default_shader = load(DEFAULT_SHADER_PATH) as Shader
	_debug_shader = load(DEBUG_SHADER_PATH) as Shader
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()
	_filter_renderer = load(FILTER_RENDERER_PATH)
	_debug_material = ShaderMaterial.new()
	_debug_material.shader = _debug_shader
	_debug_material.set_shader_param("debug_pattern", load(DEBUG_PATTERN_PATH) as Texture)
	_material = ShaderMaterial.new()
	_material.shader = _default_shader
	set_water_texture(load(DEFAULT_WATER_TEXTURE_PATH))


func _enter_tree() -> void:
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false

	if not curve:
		curve = Curve3D.new()
		curve.bake_interval = 0.05
		curve.add_point(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		curve.add_point(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -0.25), Vector3(0.0, 0.0, 0.25))
		widths = [1.0, 1.0]
	
	
	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance.new()
		new_mesh_instance.name = "RiverMeshInstance"
		add_child(new_mesh_instance)
		# Uncomment for debugging the MeshInstance object
		# new_mesh_instance.set_owner(get_tree().get_edited_scene_root()) 
		_mesh_instance = get_child(0) as MeshInstance
		_generate_river()
	else:
		_mesh_instance = get_child(0) as MeshInstance
		_material = _mesh_instance.mesh.surface_get_material(0)
	
	set_materials("valid_flowmap", valid_flowmap)
	set_materials("flowmap", _flow_foam_noise)


func _get_configuration_warning() -> String:
	if valid_flowmap:
		return ""
	else:
		return "No flowmap is set. Select River -> Generate Flow & Foam Map to generate and assign one."


# Public Methods
func add_point(position : Vector3, index : int):
	if index == -1:
		var last_index = curve.get_point_count() - 1
		var dir = (position - curve.get_point_position(last_index) - curve.get_point_out(last_index) ).normalized() * 0.25
		curve.add_point(position, -dir, dir, -1)
		widths.append(widths[widths.size() - 1]) # If this is a new point at the end, add a width that's the same as last
	else:
		var dir = (curve.get_point_position(index + 1) - curve.get_point_position(index)).normalized() * 0.25
		curve.add_point(position, -dir, dir, index + 1)
		widths.insert(index + 1, (widths[index] + widths[index + 1]) / 2.0) # We set the width to the average of the two surrounding widths
	emit_signal("river_changed")
	_generate_river()


func remove_point(index):
	# We don't allow rivers shorter than 2 points
	if curve.get_point_count() <= 2:
		return
	curve.remove_point(index)
	widths.remove(index)
	emit_signal("river_changed")
	_generate_river()


# Getter Methods
func get_curve_points() -> PoolVector3Array:
	var points : PoolVector3Array
	for p in curve.get_point_count():
		points.append(curve.get_point_position(p))
	
	return points


func get_closest_point_to(point : Vector3) -> int:
	var points = []
	var closest_distance = 4096.0
	var closest_index
	for p in curve.get_point_count():
		var dist = point.distance_to(curve.get_point_position(p))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = p
	
	return closest_index


# Setter Methods
func set_curve_point_position(index : int, position : Vector3) -> void:
	curve.set_point_position(index, position)
	_generate_river()


func set_curve_point_in(index : int, position : Vector3) -> void:
	curve.set_point_in(index, position)
	_generate_river()


func set_curve_point_out(index : int, position : Vector3) -> void:
	curve.set_point_out(index, position)
	_generate_river()


func set_widths(new_widths) -> void:
	widths = new_widths
	if _first_enter_tree:
		return
	_generate_river()


func set_step_length_divs(value : int) -> void:
	step_length_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_step_width_divs(value : int) -> void:
	step_width_divs = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_smoothness(value : float) -> void:
	smoothness = value
	if _first_enter_tree:
		return
	valid_flowmap = false
	set_materials("valid_flowmap", valid_flowmap)
	_generate_river()
	emit_signal("river_changed")


func set_albedo(color : Color) -> void:
	albedo = color
	set_materials("albedo", color)


func set_foam_color(color : Color) -> void:
	foam_color = color
	set_materials("foam_color", foam_color)


func set_foam_amount(amount : float) -> void:
	foam_amount = amount
	set_materials("foam_amount", foam_amount)


func set_foam_smoothness(amount : float) -> void:
	foam_smoothness = amount
	set_materials("foam_smoothness", amount)

func set_roughness(value : float) -> void:
	roughness = value
	set_materials("roughness", value)


func set_refraction(value : float) -> void:
	refraction = value
	set_materials("refraction", value)


func set_water_texture(texture : Texture) -> void:
	water_texture = texture
	set_materials("texture_water", texture)


func set_water_tiling(value : float) -> void:
	water_tiling = value
	set_materials("uv_tiling", water_tiling)

func set_normal_scale(value : float) -> void:
	normal_scale = value
	set_materials("normal_scale", value)


func set_absorption(value : float) -> void:
	absorption = value
	set_materials("absorption", value)


func set_flowspeed(value : float) -> void:
	flow_speed = value
	set_materials("flow_speed", value)


func set_lod0_distance(value : float) -> void:
	lod0_distance = value
	set_materials("lod0_distance", value)


func set_materials(param : String, value) -> void:
	_material.set_shader_param(param, value)
	_debug_material.set_shader_param(param, value)


func bake_texture(resolution : float) -> void:
	_generate_river()
	_generate_flowmap(resolution)
	

func _generate_river() -> void:
	var average_width = WaterHelperMethods.sum_array(widths) / float(widths.size() / 2)
	_steps = int( max(1, round(curve.get_baked_length() / average_width)) )

	# generate widths
	var river_width_values = []
	
	var length = curve.get_baked_length()
	for step in _steps * step_length_divs + 1:
		var target_pos := curve.interpolate_baked((float(step) / float(_steps * step_length_divs + 1)) * curve.get_baked_length())
		var closest_dist := 4096.0
		var closest_interpolate : float
		var closest_point : int
		for c_point in curve.get_point_count() - 1:
			for i in 100:
				var interpolate := float(i) / 100.0
				var pos := curve.interpolate(c_point, interpolate)
				var dist = pos.distance_to(target_pos)
				if dist < closest_dist:
					closest_dist = dist
					closest_interpolate = interpolate
					closest_point = c_point
		river_width_values.append( lerp(widths[closest_point], widths[closest_point + 1], closest_interpolate) )
	
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve_length = curve.get_baked_length()
	_st.add_smooth_group(true)
	
	# Generating the verts
	for step in _steps * step_length_divs + 1:
		var position = curve.interpolate_baked((float(step) / float(_steps * step_length_divs) * curve_length), false)
		var backward_pos = curve.interpolate_baked((float(step) - smoothness) / float(_steps * step_length_divs) * curve_length, false)
		var forward_pos = curve.interpolate_baked((float(step) + smoothness) / float(_steps * step_length_divs) * curve_length, false)
		var forward_vector = forward_pos - backward_pos
		var right_vector = forward_vector.cross(Vector3.UP).normalized()
		
		var width_lerp = river_width_values[step]
			
		for w_sub in step_width_divs + 1:
			_st.add_uv(Vector2(float(w_sub) / (float(step_width_divs)), float(step) / float(step_length_divs) ))
			_st.add_vertex(position + right_vector * width_lerp - 2.0 * right_vector * width_lerp * float(w_sub) / (float(step_width_divs)))
	
	# Defining the tris
	for step in _steps * step_length_divs:
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
	var grid_side = sqrt(_steps)
	if fmod(grid_side, 1.0) != 0.0:
		grid_side += 1
	grid_side = int(grid_side)
	var grid_side_length = 1.0 / float(grid_side)
	var x_grid_sub_length = grid_side_length / float(step_width_divs)
	var y_grid_sub_length = grid_side_length / float(step_length_divs)
	var grid_size = pow(grid_side, 2)
	var index := 0
	var UVs := _steps * step_width_divs * step_length_divs * 6
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


func _generate_flowmap(flowmap_resolution : float) -> void:
	WaterHelperMethods.reset_all_colliders(get_tree().root)
	
	var image := Image.new()
	image.create(flowmap_resolution, flowmap_resolution, true, Image.FORMAT_RGB8)
	image.fill(Color(0.0, 0.0, 0.0))
	
	image.lock()
	image = _generate_collisionmap(image)
	image.unlock()
	print("finished collision map")
	# Calculate how many colums are in UV2
	var grid_side = sqrt(_steps)
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
	
	# Create correctly tiling noise for a channel
	var noise_texture := load(NOISE_TEXTURE_PATH) as Texture
	var noise_with_tiling := Image.new()
	var noise_with_margin_size = float(grid_side + 2) * (float(noise_texture.get_width()) / float(grid_side))
	noise_with_tiling.create(noise_with_margin_size, noise_with_margin_size, false, Image.FORMAT_RGB8)
	noise_with_tiling.lock()
	var slice_width = float(noise_texture.get_width()) / float(grid_side)
	for x in grid_side:
		noise_with_tiling.blend_rect(noise_texture.get_data(), Rect2(0.0, 0.0, slice_width, noise_texture.get_height()), Vector2(slice_width + float(x) * slice_width, slice_width))
	noise_with_tiling.unlock()
	var tiled_noise = ImageTexture.new()
	tiled_noise.create_from_image(noise_with_tiling)
	
	# Create renderer for dilate filter
	var renderer_instance = _filter_renderer.instance()
	
	self.add_child(renderer_instance)
	
	var dilate_amount = 0.6 / float(grid_side)
	var flowmap_blur_amount = 0.02 / float(grid_side) * flowmap_resolution
	var foam_offset_amount = 0.1 / float(grid_side)
	var foam_blur_amount = 0.03 / float(grid_side) * flowmap_resolution
	print ("dilate_amount: " + str(dilate_amount))
	var dilated_texture = yield(renderer_instance.apply_dilate(texture_to_dilate, dilate_amount, flowmap_resolution), "completed")
	print("dilate finished")
	var normal_map = yield(renderer_instance.apply_normal(dilated_texture, flowmap_resolution), "completed")
	print("normal finished")
	var flow_map = yield(renderer_instance.apply_normal_to_flow(normal_map, flowmap_resolution), "completed")
	print("flowmap finished")
	var blurred_flow_map = yield(renderer_instance.apply_blur(flow_map, flowmap_blur_amount, flowmap_resolution), "completed")
	print("blurred_flowmap finished")
	var foam_map = yield(renderer_instance.apply_foam(dilated_texture, foam_offset_amount, flowmap_resolution), "completed")
	print("foam_map finished")
	var blurred_foam_map = yield(renderer_instance.apply_blur(foam_map, foam_blur_amount, flowmap_resolution), "completed")
	print("blurred_foam_map finished")
	var combined_map = yield(renderer_instance.apply_combine(blurred_flow_map, blurred_foam_map, tiled_noise), "completed")
	print("combined_map finished")
	
	remove_child(renderer_instance) # cleanup
	
	var flow_foam_noise_result = combined_map.get_data().get_rect(Rect2(margin, margin, flowmap_resolution, flowmap_resolution))
	
	_flow_foam_noise = ImageTexture.new()
	_flow_foam_noise.create_from_image(flow_foam_noise_result, 5)
	
	print("finished map bake")
	set_materials("flowmap", _flow_foam_noise)
	set_materials("valid_flowmap", true)
	valid_flowmap = true;
	
	update_configuration_warning()


func _generate_collisionmap(image : Image) -> Image:
	var space_state := get_world().direct_space_state
	var uv2 := _mesh_instance.mesh.surface_get_arrays(0)[5] as PoolVector2Array
	var verts := _mesh_instance.mesh.surface_get_arrays(0)[0] as PoolVector3Array
	# We need to move the verts into world space
	var world_verts : PoolVector3Array = []
	for v in verts.size():
		world_verts.append( global_transform.xform(verts[v]) )
	
	var tris_in_step_quad = step_length_divs * step_width_divs * 2
	var side := int(sqrt(_steps) + 1)
	
	for x in image.get_width():
		for y in image.get_height():
			var uv_coordinate := Vector2( ( 0.5 + float(x))  / float(image.get_width()), ( 0.5 + float(y)) / float(image.get_height()) )
			var baryatric_coords
			var correct_triangle := []
			
			var pixel := int(x * image.get_width() + y)
			var column := (pixel / image.get_width()) / (image.get_width() / side)
			var row := (pixel % image.get_width()) / (image.get_width() / side)
			var step_quad := column * side + row
			if step_quad >= _steps:
				break # we are in the empty part of UV2 so we break to the next column
			
			for tris in tris_in_step_quad:
				var offset_tris = (tris_in_step_quad * step_quad) + tris
				var triangle : PoolVector2Array = []
				triangle.append(uv2[offset_tris * 3])
				triangle.append(uv2[offset_tris * 3 + 1])
				triangle.append(uv2[offset_tris * 3 + 2])
				var p = Vector3(uv_coordinate.x, uv_coordinate.y, 0.0)
				var a = Vector3(uv2[offset_tris * 3].x, uv2[offset_tris * 3].y, 0.0)
				var b = Vector3(uv2[offset_tris * 3 + 1].x, uv2[offset_tris * 3 + 1].y, 0.0)
				var c = Vector3(uv2[offset_tris * 3 + 2].x, uv2[offset_tris * 3 + 2].y, 0.0)
				baryatric_coords = WaterHelperMethods.cart2bary(p, a, b, c)
				
				if WaterHelperMethods.point_in_bariatric(baryatric_coords):
					correct_triangle = [offset_tris * 3, offset_tris * 3 + 1, offset_tris * 3 + 2]
					break # we have the correct triangle so we break out of loop
			
			if correct_triangle:
				var vert0 = world_verts[correct_triangle[0]] 
				var vert1 = world_verts[correct_triangle[1]] 
				var vert2 = world_verts[correct_triangle[2]]
				
				var real_pos = WaterHelperMethods.bary2cart(vert0, vert1, vert2, baryatric_coords)
				var real_pos_up = real_pos + Vector3.UP * 10.0
				
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
			else:
				# If there is no correct triangle, we are in the empty space
				# of UV2 and we break to skip into the next pixel column.
				# this should not be needed any more after the new quad system
				break
	return image


func set_debug_view(index : int) -> void:
	if index == 0:
		_mesh_instance.material_override = null
	else:
		_debug_material.set_shader_param("mode", index)
		_mesh_instance.material_override =_debug_material


# Signal Methods
func properties_changed() -> void:
	emit_signal("river_changed")
