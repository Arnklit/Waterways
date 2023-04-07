shader_type spatial;
render_mode unshaded;

uniform float lower_bounds = 0.0;
uniform float upper_bounds = 10.0;
varying vec3 vertex_trans;

void vertex() {
	vertex_trans = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float range = upper_bounds - lower_bounds;
	ALBEDO = vec3( clamp((vertex_trans.y - lower_bounds) / range, 0.0, 1.0) );
}