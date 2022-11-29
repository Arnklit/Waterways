@tool
extends Node3D

@export var test_render := false: set = do_test_render
@export var input : Texture2D
@export var output : Texture2D

var _filter_renderer : PackedScene

const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"

func do_test_render(_value) -> void:
	
	var test_string_name = StringName("This_Is_a_test_Thing")
	
	print(test_string_name)
	
	String(test_string_name)
	
	_filter_renderer = load(FILTER_RENDERER_PATH)
	
	var renderer_instance = _filter_renderer.instantiate()

	self.add_child(renderer_instance)
	
	print("before pressure map")

	var test_texture := input

	var test_output = await renderer_instance.apply_blur(test_texture, 6.0, 256);

	output = test_output

	print("after pressure map")
	
	remove_child(renderer_instance) # cleanup

