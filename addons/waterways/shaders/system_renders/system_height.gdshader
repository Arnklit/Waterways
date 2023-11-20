shader_type spatial;
render_mode unshaded;

uniform float lower_bounds = 0.0;
uniform float upper_bounds = 10.0;
varying vec3 vertex_trans;

// Converts a color from sRGB gamma to linear light gamma
vec4 toLinear(vec4 sRGB)
{
    bvec4 cutoff = lessThan(sRGB, vec4(0.04045));
    vec4 higher = pow((sRGB + vec4(0.055))/vec4(1.055), vec4(2.4));
    vec4 lower = sRGB/vec4(12.92);

    return mix(higher, lower, cutoff);
}

void vertex() {
	vertex_trans = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float range = upper_bounds - lower_bounds;
	float height = clamp((vertex_trans.y - lower_bounds) / range, 0.0, 1.0);
	//height = toLinear(vec4(vec3(height), 1.0)).r;
	ALBEDO = vec3( height );
}