# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Viewport

const DILATE_PASS1_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass1.shader"
const DILATE_PASS2_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass2.shader"
const DILATE_PASS3_PATH = "res://addons/waterways/shaders/filters/dilate_filter_pass3.shader"
const NORMAL_MAP_PASS_PATH = "res://addons/waterways/shaders/filters/normal_map_pass.shader"
const NORMAL_TO_FLOW_PASS_PATH = "res://addons/waterways/shaders/filters/normal_to_flow_filter.shader"
const BLUR_PASS1_PATH = "res://addons/waterways/shaders/filters/blur_pass1.shader"
const BLUR_PASS2_PATH = "res://addons/waterways/shaders/filters/blur_pass2.shader"
const FOAM_PASS_PATH = "res://addons/waterways/shaders/filters/foam_pass.shader"
const COMBINE_PASS_PATH = "res://addons/waterways/shaders/filters/combine_pass.shader"
const DOTPRODUCT_PASS_PATH = "res://addons/waterways/shaders/filters/dotproduct.shader"
const FLOW_PRESSURE_PASS_PATH = "res://addons/waterways/shaders/filters/flow_pressure_pass.shader"

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
var dilate_pass_1_mat : Material
var dilate_pass_2_mat : Material
var dilate_pass_3_mat : Material
var normal_map_pass_mat : Material
var normal_to_flow_pass_mat : Material
var blur_pass1_mat : Material
var blur_pass2_mat : Material
var foam_pass_mat : Material
var combine_pass_mat : Material
var dotproduct_pass_mat : Material
var flow_pressure_pass_mat : Material

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
	
	dilate_pass_1_mat = ShaderMaterial.new()
	dilate_pass_2_mat = ShaderMaterial.new()
	dilate_pass_3_mat = ShaderMaterial.new()
	normal_map_pass_mat = ShaderMaterial.new()
	normal_to_flow_pass_mat = ShaderMaterial.new()
	blur_pass1_mat = ShaderMaterial.new()
	blur_pass2_mat = ShaderMaterial.new()
	foam_pass_mat = ShaderMaterial.new()
	combine_pass_mat = ShaderMaterial.new()
	dotproduct_pass_mat = ShaderMaterial.new()
	flow_pressure_pass_mat = ShaderMaterial.new()
	
	dilate_pass_1_mat.shader = dilate_pass_1_shader
	dilate_pass_2_mat.shader = dilate_pass_2_shader
	dilate_pass_3_mat.shader = dilate_pass_3_shader
	normal_map_pass_mat.shader = normal_map_pass_shader
	normal_to_flow_pass_mat.shader = normal_to_flow_pass_shader
	blur_pass1_mat.shader = blur_pass1_shader
	blur_pass2_mat.shader = blur_pass2_shader
	foam_pass_mat.shader = foam_pass_shader
	combine_pass_mat.shader = combine_pass_shader
	dotproduct_pass_mat.shader = dotproduct_pass_shader
	flow_pressure_pass_mat.shader = flow_pressure_pass_shader


func apply_combine(r_texture : Texture, g_texture : Texture, b_texture : Texture = null, a_texture : Texture = null) -> ImageTexture:
	size = r_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = combine_pass_mat
	$ColorRect.material.set_shader_param("r_texture", r_texture)
	$ColorRect.material.set_shader_param("g_texture", g_texture)
	$ColorRect.material.set_shader_param("b_texture", b_texture)
	$ColorRect.material.set_shader_param("a_texture", a_texture)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_dotproduct(input_texture : Texture, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = dotproduct_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_flow_pressure(input_texture : Texture, resolution : float, rows : float) -> ImageTexture:
	size = input_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = flow_pressure_pass_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("rows", rows)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image := get_texture().get_data()
	
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_foam(input_texture : Texture, distance : float, cutoff : float, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
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


func apply_vertical_blur(input_texture : Texture, blur : float, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	$ColorRect.material = blur_pass2_mat
	$ColorRect.material.set_shader_param("input_texture", input_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("blur", blur)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image : Image = get_texture().get_data()
	var result := ImageTexture.new()
	result.create_from_image(image)
	return result


func apply_normal_to_flow(input_texture : Texture, resolution : float) -> ImageTexture:
	size = input_texture.get_size()
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
	size = input_texture.get_size()
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


func apply_dilate(input_texture : Texture, dilation : float, fill : float, resolution : float, fill_texture : Texture = null) -> ImageTexture:
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
	# Pass 3
	$ColorRect.material = dilate_pass_3_mat
	$ColorRect.material.set_shader_param("distance_texture", pass2_result)
	if fill_texture != null:
		$ColorRect.material.set_shader_param("color_texture", fill_texture)
	$ColorRect.material.set_shader_param("size", resolution)
	$ColorRect.material.set_shader_param("fill", fill)
	render_target_update_mode = Viewport.UPDATE_ONCE
	update_worlds()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image3 := get_texture().get_data()
	var pass3_result := ImageTexture.new()
	pass3_result.create_from_image(image3)
	return pass3_result
