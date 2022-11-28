@tool
extends Node3D

@export var test_render := false: set = do_test_render
@export var output : Texture2D

var _filter_renderer : PackedScene

const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"

func do_test_render(_value) -> void:
	
	_filter_renderer = load(FILTER_RENDERER_PATH)
	
	var renderer_instance = _filter_renderer.instantiate()

	self.add_child(renderer_instance)
	
	print("before pressure map")

	var test_texture := load("res://test_assets/test-map.png") as Texture2D

	var flow_pressure_map = await renderer_instance.apply_foam(test_texture, 0.00, 0.9, 512);

	output = flow_pressure_map

	print("after pressure map")
	
	remove_child(renderer_instance) # cleanup

