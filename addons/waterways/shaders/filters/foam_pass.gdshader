shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : hint_default_black;
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
	float combine = 0.0;
	for(int i; i < 10; i++) {
		float value = texture(input_texture, UV - vec2(0.0, float(i) * (offset / size))).r;
		//float remapped = remap(cutoff, 1.0, 0.0, 1.0, lodded_texture.r);
		value = clamp((value - offset) / 0.00001, 0.0, 1.0);
		//combine = max(combine, value);
		combine = value;
	}
	COLOR = vec4(combine, combine, combine, 1.0);
	//COLOR = texture(input_texture, UV);
}