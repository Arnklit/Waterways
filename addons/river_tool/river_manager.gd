tool
extends Spatial

const DEFAULT_SHADER_PATH = "res://addons/river_tool/river.shader"
const DEFAULT_NORMAL_PATH = "res://addons/river_tool/waves.png"

# Shape Properties
export(int, 1, 100) var steps := 6 setget set_steps
export(int, 1, 8) var step_length_divs = 1 setget set_step_length_divs
export(int, 1, 8) var step_width_divs = 1 setget set_step_width_divs
export(float, 0.1, 5.0) var smoothness = 0.5 setget set_smoothness

# Material Properties
export(Color, RGBA) var albedo = Color(0.1, 0.1, 0.1, 0.0) setget set_albedo 
export(float, 0.0, 1.0) var roughness = 0.2 setget set_roughness
export(float, -1.0, 1.0) var refraction = 0.05 setget set_refraction
export(Texture) var texture_normal setget set_texture_normal
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
	set_texture_normal(load(DEFAULT_NORMAL_PATH))
	_st = SurfaceTool.new()
	_mdt = MeshDataTool.new()


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
		print("interpol is:" + str(interpol))
		var interpol_old = interpol * float(old_river_width_values.size())
		print("interpol_old is:" + str(interpol_old))
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


func set_albedo(color : Color) -> void:
	albedo = color
	_material.set_shader_param("albedo", color)


func set_roughness(value : float) -> void:
	roughness = value
	_material.set_shader_param("roughness", value)


func set_refraction(value : float) -> void:
	refraction = value
	_material.set_shader_param("refraction", value)


func set_texture_normal(texture : Texture) -> void:
	texture_normal = texture
	_material.set_shader_param("texture_normal", texture)


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
	var grid_size = pow(int(grid_side), 2)
	
	print("Grid Size is: " + str(grid_size))
	
#	var index = 0
#	for step in steps:
#		for y in step_length_divs + 1:
#			for x in step_width_divs + 1:
#				var pos := Vector2(float(x) / float(step_width_divs + 1), float(y) / float(step_length_divs + 1))
#				_mdt.set_vertex_uv2(index, pos)
#				print("index is: " + str(index))
#				print(pos)
#				index += 1

	_mdt.set_vertex_uv2(0, Vector2(0.0, 0.0))
	_mdt.set_vertex_uv2(1, Vector2(0.5, 0.0))
	_mdt.set_vertex_uv2(2, Vector2(0.0, 0.5))

	_mdt.set_vertex_uv2(3, Vector2(0.0, 0.5))
	_mdt.set_vertex_uv2(4, Vector2(0.5, 0.0))
	_mdt.set_vertex_uv2(5, Vector2(0.5, 0.5))

	_mdt.set_vertex_uv2(6, Vector2(0.0, 0.5))
	_mdt.set_vertex_uv2(7, Vector2(0.5, 0.5))
	_mdt.set_vertex_uv2(8, Vector2(0.0, 1.0))
#
	_mdt.set_vertex_uv2(9, Vector2(0.0, 1.0))
	_mdt.set_vertex_uv2(10, Vector2(0.5, 0.5))
	_mdt.set_vertex_uv2(11, Vector2(0.5, 1.0))
	
	_mdt.commit_to_surface(mesh2)
	_mesh_instance.mesh = mesh2
	_mesh_instance.mesh.surface_set_material(0, _material)


# Signal Methods
func _on_Path_curve_changed() -> void:
	if _first_enter_tree:
		return
	_generate_river()


func properties_changed() -> void:
	emit_signal("river_changed")
