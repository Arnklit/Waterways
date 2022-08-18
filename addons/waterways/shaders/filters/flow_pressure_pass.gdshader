shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;
uniform float rows = 1.0;

void fragment() {
	float value = 0.0;
	float pixel_size = 1.0 / size;
	for (int i = 0; i < int(size) / int(rows); i++) {
		float base_x = floor(UV.x * rows) / rows;
		vec2 new_uv = vec2(base_x + float(i) / size, UV.y) + pixel_size / 2.0;
		value += textureLod(input_texture, new_uv, 0.0).r;
	}
value /= size / rows;
COLOR = vec4(vec3(value), 1.0);
}