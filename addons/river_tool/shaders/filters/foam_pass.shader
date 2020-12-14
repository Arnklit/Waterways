shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float offset = 0.1;
uniform float cutoff = 0.9;


float invLerp(float from, float to, float value){
	return (value - from) / (to - from);
}

float remap(float origFrom, float origTo, float targetFrom, float targetTo, float value){
	float rel = invLerp(origFrom, origTo, value);
	return mix(targetFrom, targetTo, rel);
}

void fragment() {
	vec4 lodded_texture = textureLod(input_texture, UV - vec2(0.0, offset), 0.0);
	float remapped = remap(cutoff, 1.0, 0.0, 1.0, lodded_texture.r);
	COLOR = vec4(remapped, remapped, remapped, 1.0);
}