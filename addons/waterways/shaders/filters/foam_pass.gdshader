shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture : hint_default_black;
uniform float offset = 0.1;
uniform float cutoff = 0.9;

void fragment() {
	float combine = 0.0;
	for(int i = 0; i < 10; i++) {
		
		float value = clamp((texture(input_texture, UV - vec2(0.0, (offset / size) * float(i))).r - cutoff) / 0.0001, 0.0, 1.0);
		combine = max(combine, value);
	}
	COLOR = vec4(vec3(combine), 1.0);
}