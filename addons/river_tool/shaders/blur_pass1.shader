shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float blur = 0.1;

vec4 fct(vec2 uv) {
	float e = 1.0 / size;
	vec4 rv = vec4(0.0);
	float sum = 0.0;
	for (float i = -50.0; i <= 50.0; i += 1.0) {
		float coef = exp(-0.5 * (pow(i / blur, 2.0)))/(6.28318530718 * blur * blur);
		rv += texture(input_texture, uv + vec2(i * e, 0.0)) * coef;
		sum += coef;
	}
	return rv / sum;
}

void fragment() {
	COLOR = fct(UV);
}