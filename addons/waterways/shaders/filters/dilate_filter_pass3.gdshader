shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D distance_texture;
uniform sampler2D color_texture : hint_default_white;
uniform float fill = 1.0;

vec2 pack_4x8_to_2x16(vec4 s) {
	return s.rg + s.ba/256.0;
}

void fragment() {
	//vec3 dist = texture(distance_texture, UV).rgb;
	vec3 dist = vec3( pack_4x8_to_2x16(texture(distance_texture, UV)), UV.y);
	COLOR = vec4(texture(color_texture, dist.yz).rgb * mix(dist.x, 1.0, fill), 1.0);
	//COLOR = vec4(dist.xxx, 1.0);
}