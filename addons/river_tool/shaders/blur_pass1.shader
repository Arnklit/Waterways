shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float blur = 0.1;

vec4 input_in(vec2 uv) {
vec4 lodded_texture = textureLod(input_texture, uv, 0.0);

return lodded_texture;
}

vec4 fct(vec2 uv) {
	float e = 1.0/size;
	vec4 rv = vec4(0.0);
	float sum = 0.0;
	for (float i = -50.0; i <= 50.0; i += 1.0) {
		float coef = exp(-0.5*(pow(i/blur, 2.0)))/(6.28318530718*blur*blur);
		rv += input_in(uv+vec2(i*e, 0.0))*coef;
		sum += coef;
	}
	return rv/sum;
}

void fragment() {
	COLOR = fct(UV);
}