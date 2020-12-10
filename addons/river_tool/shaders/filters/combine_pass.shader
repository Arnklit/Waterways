shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D flow_texture;
uniform sampler2D foam_texture;
uniform sampler2D noise_texture;

void fragment() {
	COLOR = vec4(texture(flow_texture, UV).rg, texture(foam_texture, UV).r, texture(noise_texture, UV).r);
}