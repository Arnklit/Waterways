shader_type canvas_item;

uniform sampler2D flow_texture;
uniform sampler2D foam_texture;

void fragment() {
	COLOR = vec4(texture(flow_texture, UV).rg, texture(foam_texture, UV).r, 1.0);
}