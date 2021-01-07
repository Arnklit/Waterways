tool
extends Node2D


const FilterRenderer = preload("res://addons/waterways/filter_renderer.tscn")

export(bool) var apply_filter = false setget set_apply_filter

export(Texture) var input1
export(Texture) var input2
export(Texture) var output


func set_apply_filter(value : bool) -> void:
	apply_filter = false
	print("in apply filter")
	var filter_renderer = FilterRenderer.instance()
	add_child(filter_renderer)
	
	output = yield(filter_renderer.apply_dilate(input1, 0.1, 0.0, 512.0), "completed")
	
	remove_child(filter_renderer)
