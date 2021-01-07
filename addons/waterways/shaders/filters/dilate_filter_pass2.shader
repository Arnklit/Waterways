shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float dilation = 0.1;

vec3 distance_v(vec2 uv) {
	vec2 e = vec2(0.0, 1.0/size);
	int steps = int(size*dilation);
	vec3 p = texture(input_texture, uv).rgb;
	for (int i = 0; i < steps; ++i) {
		vec2 dx = float(i)*e;
		vec3 p2 = texture(input_texture, uv+dx).rgb;
		if (p2.x > p.x) {
			p2.x = 1.0-sqrt((1.0-p2.x)*(1.0-p2.x)+dx.y*dx.y/dilation/dilation);
			p = mix(p, p2, step(p.x, p2.x));
		}
		p2 = texture(input_texture, uv-dx).rgb;
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
}