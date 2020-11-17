tool
extends Viewport

const DILATE_PASS1_PATH = "res://addons/river_tool/shaders/dilate_filter_pass1.shader"
const DILATE_PASS2_PATH = "res://addons/river_tool/shaders/dilate_filter_pass2.shader"
const NORMAL_MAP_PASS_PATH = "res://addons/river_tool/shaders/normal_map_pass.shader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/river_tool/shaders/normal_to_flow_filter.shader"
const BLUR_PASS1_PATH = "res://addons/river_tool/shaders/blur_pass1.shader"
var dilate_pass_1_shader : Shader
var dilate_pass_2_shader : Shader
var normal_map_pass_shader : Shader
var normal_to_flow_pass_shader : Shader
var blur_pass1_shader : Shader
var dilate_pass_1_mat : Material
var dilate_pass_2_mat : Material
var normal_map_pass_mat : Material
var normal_to_flow_pass_mat : Material
var blur_pass1_mat : Material


func _enter_tree() -> void:
	dilate_pass_1_shader = load(DILATE_PASS1_PATH) as Shader
	dilate_pass_2_shader = load(DILATE_PASS2_PATH) as Shader
	normal_map_pass_shader = load(NORMAL_MAP_PASS_PATH) as Shader
	normal_to_flow_pass_shader = load(NORMAL_TO_FLOW_PASS_PATH) as Shader
	blur_pass1_shader = load(BLUR_PASS1_PATH)
	dilate_pass_1_mat = ShaderMaterial.new()
	dilate_pass_2_mat = ShaderMaterial.new()
	normal_map_pass_mat = ShaderMaterial.new()
	normal_to_flow_pass_mat = ShaderMaterial.new()
	blur_pass1_mat = ShaderMaterial.new()
	dilate_pass_1_mat.shader = dilate_pass_1_shader
	dilate_pass_2_mat.shader = dilate_pass_2_shader
	normal_map_pass_mat.shader = normal_map_pass_shader
	normal_to_flow_pass_mat.shader = normal_to_flow_pass_shader
	blur_pass1_mat.shader = blur_pass1_shader

func apply_blur(input_texture : Texture, blur : float) -> ImageTexture:
	print("apply_blur called")
	size = input_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = blur_pass1_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", size.x)
	$ColorRect.material.set_shader_param("blur", blur)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image : Image = get_texture().get_data()
	var pass1_result := ImageTexture.new()
	pass1_result.create_from_image(image)
	return pass1_result
	

func apply_normal_to_flow(input_texture : Texture) -> ImageTexture:
	print("apply_normal_to_flow called")
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = normal_to_flow_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", size.x)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image = get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_normal(input_texture : Texture) -> ImageTexture:
	print("apply_normal called")
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = normal_map_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", size.x)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image = get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_dilate(input_texture : Texture, dilation : float) -> ImageTexture:
	print("apply_dilate called")
	size = input_texture.get_size()
	
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = dilate_pass_1_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", size.x)
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
	$ColorRect.material.set_shader_param("size", size.x)
	$ColorRect.material.set_shader_param("dilation", dilation)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image2 = get_texture().get_data()
	var pass2_result := ImageTexture.new()
	pass2_result.create_from_image(image2)
	
	return pass2_result
