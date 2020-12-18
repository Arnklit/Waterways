# Copyright © 2020 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Viewport

const DILATE_PASS1_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass1.shader"
const DILATE_PASS2_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass2.shader"
const NORMAL_MAP_PASS_PATH = "res://addons/waterways/shaders/filters/normal_map_pass.shader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/normal_to_flow_filter.shader"
const BLUR_PASS1_PATH = "res://addons/waterways/shaders/filters/blur_pass1.shader"
const BLUR_PASS2_PATH = "res://addons/waterways/shaders/filters/blur_pass2.shader"
const FOAM_PASS_PATH = "res://addons/waterways/shaders/filters/foam_pass.shader"
const COMBINE_PASS_PATH = "res://addons/waterways/shaders/filters/combine_pass.shader"

var dilate_pass_1_shader : Shader
var dilate_pass_2_shader : Shader
var normal_map_pass_shader : Shader
var normal_to_flow_pass_shader : Shader
var blur_pass1_shader : Shader
var blur_pass2_shader : Shader
var foam_pass_shader : Shader
var combine_pass_shader : Shader
var dilate_pass_1_mat : Material
var dilate_pass_2_mat : Material
var normal_map_pass_mat : Material
var normal_to_flow_pass_mat : Material
var blur_pass1_mat : Material
var blur_pass2_mat : Material
var foam_pass_mat : Material
var combine_pass_mat : Material

func _enter_tree() -> void:
	dilate_pass_1_shader = load(DILATE_PASS1_PATH) as Shader
	dilate_pass_2_shader = load(DILATE_PASS2_PATH) as Shader
	normal_map_pass_shader = load(NORMAL_MAP_PASS_PATH) as Shader
	normal_to_flow_pass_shader = load(NORMAL_TO_FLOW_PASS_PATH) as Shader
	blur_pass1_shader = load(BLUR_PASS1_PATH) as Shader
	blur_pass2_shader = load(BLUR_PASS2_PATH) as Shader
	foam_pass_shader = load(FOAM_PASS_PATH) as Shader
	combine_pass_shader = load(COMBINE_PASS_PATH) as Shader
	
	dilate_pass_1_mat = ShaderMaterial.new()
	dilate_pass_2_mat = ShaderMaterial.new()
	normal_map_pass_mat = ShaderMaterial.new()
	normal_to_flow_pass_mat = ShaderMaterial.new()
	blur_pass1_mat = ShaderMaterial.new()
	blur_pass2_mat = ShaderMaterial.new()
	foam_pass_mat = ShaderMaterial.new()
	combine_pass_mat = ShaderMaterial.new()
	
	dilate_pass_1_mat.shader = dilate_pass_1_shader
	dilate_pass_2_mat.shader = dilate_pass_2_shader
	normal_map_pass_mat.shader = normal_map_pass_shader
	normal_to_flow_pass_mat.shader = normal_to_flow_pass_shader
	blur_pass1_mat.shader = blur_pass1_shader
	blur_pass2_mat.shader = blur_pass2_shader
	foam_pass_mat.shader = foam_pass_shader
	combine_pass_mat.shader = combine_pass_shader

func apply_combine(flow_texture : Texture, foam_texture : Texture, noise_texture : Texture) -> ImageTexture:
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = combine_pass_mat
	$ColorRect.material.set_shader_param("flow_texture", flow_texture)
	$ColorRect.material.set_shader_param("foam_texture", foam_texture)
	$ColorRect.material.set_shader_param("noise_texture", noise_texture)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_foam(input_texture : Texture, distance : float, cutoff : float, resolution : float) -> ImageTexture:
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = foam_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("offset", distance)
	$ColorRect.material.set_shader_param("cutoff", cutoff)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_blur(input_texture : Texture, blur : float, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = blur_pass1_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("blur", blur)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image : Image = get_texture().get_data()
	var pass1_result := ImageTexture.new()
	pass1_result.create_from_image(image)
	# Pass 2
	$ColorRect.material = blur_pass2_mat
	$ColorRect.material.set_shader_param("input_texture", pass1_result)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("blur", blur)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image2 := get_texture().get_data()
	
	var pass2_result := ImageTexture.new()
	pass2_result.create_from_image(image2)
	return pass2_result
	

func apply_normal_to_flow(input_texture : Texture, resolution : float) -> ImageTexture:
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = normal_to_flow_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_normal(input_texture : Texture, resolution : float) -> ImageTexture:
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = normal_map_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image = get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_dilate(input_texture : Texture, dilation : float, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
	
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = dilate_pass_1_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("dilation", dilation)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image : Image = get_texture().get_data()
	var pass1_result := ImageTexture.new()
	pass1_result.create_from_image(image)
	# Pass 2
	$ColorRect.material = dilate_pass_2_mat
	$ColorRect.material.set_shader_param("input_texture", pass1_result)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("dilation", dilation)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image2 := get_texture().get_data()
	
	var pass2_result := ImageTexture.new()
	pass2_result.create_from_image(image2)
	return pass2_result
