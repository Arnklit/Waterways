shader_type canvas_item;

render_mode blend_disabled;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float blur = 0.1;

vec4 pack_2x16_to_4x8(vec2 s) {
	return vec4(s.xy - vec2(mod(s.x, 1.0/32.0), mod(s.y, 1.0/32.0)) , vec2(mod(s.x, 1.0/32.0), mod(s.y, 1.0/32.0))*32.0);
}

vec4 fct(vec2 uv) {
	float e = 1.0 / size;
	vec4 rv = vec4(0.0);
	float sum = 0.0;
	for (float i = -50.0; i <= 50.0; i += 1.0) {
		float coef = exp(-0.5 * (pow(i / blur, 2.0)))/(6.28318530718 * blur * blur);
		rv += textureLod(input_texture, uv + vec2(i * e, 0.0), 0.0) * coef;
		sum += coef;
	}
	return rv / sum;
}

void fragment() {
	//COLOR = pack_2x16_to_4x8( fct(UV).xy );
	COLOR = fct(UV);
}