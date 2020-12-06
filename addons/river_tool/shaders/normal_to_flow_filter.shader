shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;

vec3 nm2flow(vec2 x) {
	x -= vec2(0.5);
	vec3 rv = vec3((x.x > 0.0) ? vec2(-x.y, x.x) : vec2(x.y, -x.x), -1.0);
	return 0.5*normalize(rv)+vec3(0.5);
}

vec3 lighten(vec3 col1, vec3 col2) {
	return vec3(max(col1.r, col2.r), max(col1.g, col2.g), max(col1.b, col2.b));
}

void fragment() {
	// Create two copies of the flowmap sligtly offset by each other and combine
	// them with lighten to remove seam
	vec4 texture1 = texture(input_texture, UV + vec2(1.0 / size), 0.0);
	vec4 texture2 = texture(input_texture, UV - vec2(1.0 / size), 0.0);
	vec3 flowmap1 = nm2flow(texture1.xy);
	vec3 flowmap2 = nm2flow(texture2.xy);
	vec3 combined_texture = lighten(flowmap1, flowmap2);
	COLOR = vec4(combined_texture, 1.0);
}