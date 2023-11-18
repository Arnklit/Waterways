# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends SubViewport


const DILATE_PASS1_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass1.gdshader"
const DILATE_PASS2_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass2.gdshader"
const DILATE_PASS3_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass3.gdshader"
const NORMAL_MAP_PASS_PATH = "res://addons/waterways/shaders/filters/normal_map_pass.gdshader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/normal_to_flow_filter.gdshader"
const BLUR_PASS1_PATH = "res://addons/waterways/shaders/filters/blur_pass1.gdshader"
const BLUR_PASS2_PATH = "res://addons/waterways/shaders/filters/blur_pass2.gdshader"
const FOAM_PASS_PATH = "res://addons/waterways/shaders/filters/foam_pass.gdshader"
const COMBINE_PASS_PATH = "res://addons/waterways/shaders/filters/combine_pass.gdshader"
const DOTPRODUCT_PASS_PATH = "res://addons/waterways/shaders/filters/dotproduct.gdshader"
const FLOW_PRESSURE_PASS_PATH = "res://addons/waterways/shaders/filters/flow_pressure_pass.gdshader"


var dilate_pass_1_shader : Shader
var dilate_pass_2_shader : Shader
var dilate_pass_3_shader : Shader
var normal_map_pass_shader : Shader
var normal_to_flow_pass_shader : Shader
var blur_pass1_shader : Shader
var blur_pass2_shader : Shader
var foam_pass_shader : Shader
var combine_pass_shader : Shader
var dotproduct_pass_shader : Shader
var flow_pressure_pass_shader : Shader

var filter_mat : ShaderMaterial


func _enter_tree() -> void:
	dilate_pass_1_shader = load(DILATE_PASS1_PATH) as Shader
	dilate_pass_2_shader = load(DILATE_PASS2_PATH) as Shader
	dilate_pass_3_shader = load(DILATE_PASS3_PATH) as Shader
	normal_map_pass_shader = load(NORMAL_MAP_PASS_PATH) as Shader
	normal_to_flow_pass_shader = load(NORMAL_TO_FLOW_PASS_PATH) as Shader
	blur_pass1_shader = load(BLUR_PASS1_PATH) as Shader
	blur_pass2_shader = load(BLUR_PASS2_PATH) as Shader
	foam_pass_shader = load(FOAM_PASS_PATH) as Shader
	combine_pass_shader = load(COMBINE_PASS_PATH) as Shader
	dotproduct_pass_shader = load(DOTPRODUCT_PASS_PATH) as Shader
	flow_pressure_pass_shader = load(FLOW_PRESSURE_PASS_PATH) as Shader
	
	filter_mat = ShaderMaterial.new()
	
	$ColorRect.material = filter_mat


func apply_combine(r_texture : Texture2D, g_texture : Texture2D, b_texture : Texture2D = null, a_texture : Texture2D = null) -> ImageTexture:
	filter_mat.shader = combine_pass_shader
	size = r_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("r_texture", r_texture)
	$ColorRect.material.set_shader_parameter("g_texture", g_texture)
	$ColorRect.material.set_shader_parameter("b_texture", b_texture)
	$ColorRect.material.set_shader_parameter("a_texture", a_texture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_dotproduct(input_texture : Texture2D, resolution : float) -> ImageTexture:
	filter_mat.shader = dotproduct_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_flow_pressure(input_texture : Texture2D, resolution : float, rows : float) -> ImageTexture:
	filter_mat.shader = flow_pressure_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("rows", rows)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	#await RenderingServer.frame_post_draw - TODO, replace with these?
	var image : Image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_foam(input_texture : Texture2D, distance : float, cutoff : float, resolution : float) -> ImageTexture:
	filter_mat.shader = foam_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("offset", distance)
	$ColorRect.material.set_shader_parameter("cutoff", cutoff)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_blur(input_texture : Texture2D, blur : float, resolution : float) -> ImageTexture:
	filter_mat.shader = blur_pass1_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	var pass1_result := ImageTexture.create_from_image(image)
	# Pass 2
	filter_mat.shader = blur_pass2_shader
	$ColorRect.material.set_shader_parameter("input_texture", pass1_result)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image2 : Image = get_texture().get_image()
	
	var pass2_result := ImageTexture.create_from_image(image2)
	return pass2_result


func apply_vertical_blur(input_texture : Texture2D, blur : float, resolution : float) -> ImageTexture:
	filter_mat.shader = blur_pass2_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("blur", blur)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	var result := ImageTexture.create_from_image(image)
	return result


func apply_normal_to_flow(input_texture : Texture2D, resolution : float) -> ImageTexture:
	filter_mat.shader = normal_to_flow_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_normal(input_texture : Texture2D, resolution : float) -> ImageTexture:
	filter_mat.shader = normal_map_pass_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image = get_texture().get_image()
	
	var result := ImageTexture.create_from_image(image)
	return result


func apply_dilate(input_texture : Texture2D, dilation: float, fill: float, resolution: float, fill_texture: Texture2D = null) -> ImageTexture:
	filter_mat.shader = dilate_pass_1_shader
	size = input_texture.get_size()
	$ColorRect.position = Vector2(0, 0)
	$ColorRect.size = size
	$ColorRect.material.set_shader_parameter("input_texture", input_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image : Image = get_texture().get_image()
	var pass1_result := ImageTexture.create_from_image(image)
	# Pass 2
	filter_mat.shader = dilate_pass_2_shader
	$ColorRect.material.set_shader_parameter("input_texture", pass1_result)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("dilation", dilation)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image2 : Image = get_texture().get_image()
	var pass2_result := ImageTexture.create_from_image(image2)
#	return pass2_result
	# Pass 3
	filter_mat.shader = dilate_pass_3_shader
	$ColorRect.material.set_shader_parameter("distance_texture", pass2_result)
	if fill_texture != null:
		$ColorRect.material.set_shader_parameter("color_texture", fill_texture)
	$ColorRect.material.set_shader_parameter("size", resolution)
	$ColorRect.material.set_shader_parameter("fill", fill)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var image3 : Image = get_texture().get_image()
	var pass3_result := ImageTexture.create_from_image(image3)
	return pass3_result
