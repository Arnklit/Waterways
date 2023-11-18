@tool
extends Node3D

const WaterfallConfiguration = preload("./waterfall_configuration.gd")
const WaterHelperMethods = preload("./water_helper_methods.gd")
const line_sample_resolution := 100

@export var configuration: WaterfallConfiguration:
	set(value):
		configuration = value
		configuration.changed.connect(_configuration_changed)
		print("configuration set function is called")
#@export var width := 3.0:
#	set(value):
#		width = value
#		_generate_waterfall()
#@export var step_length_divs := 1:
#	set(value):
#		step_length_divs = value
#		_generate_waterfall()
#@export var step_width_divs := 1:
#	set(value):
#		step_width_divs = value
#		_generate_waterfall()

var points := PackedVector3Array([Vector3(0.0, 4.0, 0.0), Vector3(0.0, 0.0, 1.0)]):
	set(value):
		points = value
		_generate_waterfall()
		emit_signal("waterfall_changed")
var mesh_instance : MeshInstance3D

var _st : SurfaceTool
var _mdt : MeshDataTool
var _steps := 2
var _first_enter_tree = true

# TODO - connect this
signal waterfall_changed


func get_points() -> PackedVector3Array:
	return points


func set_point(id: int, position: Vector3) -> void:
	points[id] = position
	_generate_waterfall()
	emit_signal("waterfall_changed")


func _configuration_changed() -> void:
	print("_configuration changed")
	# TODO - I assume we can pass a parameter about whether a re-gen is needed
	_generate_waterfall()
	emit_signal("waterfall_changed")


func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false

	if get_child_count() <= 0:
		var new_mesh_instance := MeshInstance3D.new()
		new_mesh_instance.name = "WaterfallMeshInstance"
		add_child(new_mesh_instance)
		mesh_instance = get_child(0) as MeshInstance3D
		_generate_waterfall()
	else:
		mesh_instance = get_child(0) as MeshInstance3D
		# TODO set material?
	

func _generate_waterfall() -> void:
	
	# TODO - This spams "the target vector can't be zero", not sure which part, maybe cross product
	
	var to_from: Vector3 = points[1] - points[0]
	var to_from_2d = Vector3(to_from.x, 0.0, to_from.z)
	var dist = to_from_2d.length()
	
	var line_points := PackedVector3Array()
	
	var curve := Curve3D.new()
	
	for i in line_sample_resolution + 1:
		var val = float(i) / float(line_sample_resolution)
		var position = points[0] + to_from_2d * val + Vector3(0.0, ease_back_in(val) * to_from.y, 0.0)
		curve.add_point(position)
		line_points.append(position)
	
	var curve_length := curve.get_baked_length()
		
	_steps = int( max(1.0, round(curve_length / configuration.width)))
	
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_smooth_group(0)
	
	# Generating the verts
	for step in _steps * configuration.step_length_divs + 1:
		var position := curve.sample_baked(float(step) / float(_steps * configuration.step_length_divs) * curve_length, false)
		var backward_pos := curve.sample_baked((float(step) - 0.05) / float(_steps * configuration.step_length_divs) * curve_length, false)
		var forward_pos := curve.sample_baked((float(step) + 0.05) / float(_steps *configuration. step_length_divs) * curve_length, false)
		var forward_vector := forward_pos - backward_pos
		var right_vector := forward_vector.cross(Vector3.UP).normalized()
		
				
		for w_sub in configuration.step_width_divs + 1:
			_st.set_uv(Vector2(float(w_sub) / (float(configuration.step_width_divs)), float(step) / float(configuration.step_length_divs) ))
			_st.add_vertex(position + right_vector * configuration.width - 2.0 * right_vector * configuration.width * float(w_sub) / (float(configuration.step_width_divs)))
	
	# Defining the tris
	for step in _steps * configuration.step_length_divs:
		for w_sub in configuration.step_width_divs:
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub)
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub + 1)
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub + 2 + configuration.step_width_divs - 1)
			
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub + 1)
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub + 3 + configuration.step_width_divs - 1)
			_st.add_index( (step * (configuration.step_width_divs + 1)) + w_sub + 2 + configuration.step_width_divs - 1)
		
	_st.generate_normals()
	_st.generate_tangents()
	_st.deindex()
	
	var mesh := ArrayMesh.new()
	mesh = _st.commit()
	mesh_instance.mesh = mesh


func ease_back_in(x: float) -> float:
	var c1 = 1.70158
	var c3 = c1 + 1
	return c3 * x * x * x - c1 * x * x


# Signal Methods
func properties_changed() -> void:
	emit_signal("waterfall_changed")
