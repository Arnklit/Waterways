# Copyright © 2020 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.

const DEBUG_FLOWMAP_SHADER_PATH = "res://addons/river_tool/shaders/river_debug_flowmap.shader"
const DEBUG_FOAMMAP_SHADER_PATH = "res://addons/river_tool/shaders/river_debug_foammap.shader"
const DEBUG_FLOWARROWS_SHADER_PATH = "res://addons/river_tool/shaders/river_debug_flowarrows.shader"

const DEBUG_ARROW_TEXTURE_PATH = "res://addons/river_tool/textures/flow_arrow.svg"

static func get_debug_material(index : int, flowmap : Texture, flowmap_set : bool) -> Material:
	var material := ShaderMaterial.new()
	match(index):
		1:
			material.shader = load(DEBUG_FLOWMAP_SHADER_PATH) as Shader
		2:
			material.shader = load(DEBUG_FOAMMAP_SHADER_PATH) as Shader
		3:
			material.shader = load(DEBUG_FLOWARROWS_SHADER_PATH) as Shader
			material.set_shader_param("arrows", load(DEBUG_ARROW_TEXTURE_PATH) as Texture)
	
	material.set_shader_param("flowmap", flowmap)
	material.set_shader_param("flowmap_set", flowmap_set)
	
	return material


static func cart2bary(p : Vector3, a : Vector3, b : Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	var v = (d11 * d20 - d01 * d21) / denom
	var w = (d00 * d21 - d01 * d20) / denom
	var u = 1.0 - v - w
	return Vector3(u, v, w)


static func bary2cart(a : Vector3, b : Vector3, c: Vector3, barycentric: Vector3) -> Vector3:
	return barycentric.x * a + barycentric.y * b + barycentric.z * c


static func point_in_bariatric(v : Vector3) -> bool:
	return 0 <= v.x and v.x <= 1 and 0 <= v.y and v.y <= 1 and 0 <= v.z and v.z <= 1;


static func reset_all_colliders(node):
	for n in node.get_children():
		if n.get_child_count() > 0:
			reset_all_colliders(n)
		if n is CollisionShape:
			if n.disabled == false:
				n.disabled = true
				n.disabled = false


static func sum_array(array):
	var sum = 0.0
	for element in array:
			sum += element
	return sum
