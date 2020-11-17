tool
extends Viewport

const DILATE_PASS1_PATH = "res://addons/river_tool/shaders/dilate_filter_pass1.shader"
const DILATE_PASS2_PATH = "res://addons/river_tool/shaders/dilate_filter_pass2.shader"
var dilate_pass_1_shader : Shader
var dilate_pass_2_shader : Shader
var dilate_pass_1_mat : Material
var dilate_pass_2_mat : Material


func _enter_tree() -> void:
	dilate_pass_1_shader = load(DILATE_PASS1_PATH) as Shader
	dilate_pass_2_shader = load(DILATE_PASS2_PATH) as Shader
	dilate_pass_1_mat = ShaderMaterial.new()
	dilate_pass_2_mat = ShaderMaterial.new()
	dilate_pass_1_mat.shader = dilate_pass_1_shader
	dilate_pass_2_mat.shader = dilate_pass_2_shader

func apply_dilate(input_texture : Texture, dilation : float) -> ImageTexture:
	print("apply_dilate called")
	size = input_texture.get_size()
	print("size: " + str(size))
	
	$ColorRect.rect_position = Vector2(0, 0)
	$ColorRect.rect_size = size
	print("$ColorRect.rect_size: " + str($ColorRect.rect_size))
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
