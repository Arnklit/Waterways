shader_type canvas_item;

render_mode blend_disabled;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float dilation = 0.1;

vec2 pack_4x8_to_2x16(vec4 s) {
	return s.rg + s.ba/256.0;
}

vec4 pack_2x16_to_4x8(vec2 s) {
	return vec4(s.xy - vec2(mod(s.x, 1.0/256.0), mod(s.y, 1.0/256.0)) , vec2(mod(s.x, 1.0/256.0), mod(s.y, 1.0/256.0))*256.0);
}

vec3 distance_v(vec2 uv) {
	vec2 e = vec2(0.0, 1.0/size);
	int steps = int(size*dilation);
	vec3 p = texture(input_texture, uv).rgb;
	//vec3 p = vec3( pack_4x8_to_2x16(texture(input_texture, uv)), uv.y);
	for (int i = 0; i < steps; ++i) {
		vec2 dx = float(i)*e;
		vec3 p2 = texture(input_texture, uv+dx).rgb;
		//vec3 p2 = vec3( pack_4x8_to_2x16(texture(input_texture, uv+dx)), (uv+dx).y);
		if (p2.x > p.x) {
			p2.x = 1.0-sqrt((1.0-p2.x)*(1.0-p2.x)+dx.y*dx.y/dilation/dilation);
			p = mix(p, p2, step(p.x, p2.x));
		}
		p2 = texture(input_texture, uv-dx).rgb;
		//p2 = vec3(pack_4x8_to_2x16(texture(input_texture, uv-dx)), (uv-dx).y);
		if (p2.x > p.x) {
			p2.x = 1.0-sqrt((1.0-p2.x)*(1.0-p2.x)+dx.y*dx.y/dilation/dilation);
			p = mix(p, p2, step(p.x, p2.x));
		}
	}
	return p;
}

void fragment() {
	vec3 dilated_uv = distance_v((UV));
	COLOR = vec4(dilated_uv, 1.0);
	//COLOR = vec4(pack_2x16_to_4x8(dilated_uv.xy));
}