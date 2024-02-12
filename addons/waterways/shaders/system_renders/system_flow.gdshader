shader_type spatial;
render_mode unshaded;

uniform sampler2D flowmap : hint_normal;
uniform sampler2D distmap : hint_default_white;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;
uniform bool valid_flowmap = false;
uniform int uv2_sides = 2;

varying vec3 binormal_world;


// Converts a color from linear light gamma to sRGB gamma
vec4 fromLinear(vec4 linearRGB)
{
    bvec4 cutoff = lessThan(linearRGB, vec4(0.0031308));
    vec4 higher = vec4(1.055)*pow(linearRGB, vec4(1.0/2.4)) - vec4(0.055);
    vec4 lower = linearRGB * vec4(12.92);

    return mix(higher, lower, cutoff);
}

// Converts a color from sRGB gamma to linear light gamma
vec4 toLinear(vec4 sRGB)
{
    bvec4 cutoff = lessThan(sRGB, vec4(0.04045));
    vec4 higher = pow((sRGB + vec4(0.055))/vec4(1.055), vec4(2.4));
    vec4 lower = sRGB/vec4(12.92);

    return mix(higher, lower, cutoff);
}


void vertex() {
	binormal_world = (MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 custom_UV = (UV2 + 1.0 / float(uv2_sides)) * (float(uv2_sides) / float(uv2_sides + 2));
	
	vec2 flow_foam_noise = textureLod(flowmap, custom_UV, 0.0).rg;
	vec2 dist_pressure = textureLod(distmap, custom_UV, 0.0).xy;
	
	
	vec2 flow;
	float distance_map;
	float pressure_map;
	if (valid_flowmap) {
		flow = flow_foam_noise.xy;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
	} else {
		flow = vec2(0.5, 0.572);
		distance_map = 0.5;
		pressure_map = 0.5;
	}
	
	flow = (flow - 0.5) * 2.0; // remap
	
	// calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float flow_force = min(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure, flow_max);
	flow *= flow_force;
	
	float rotation = atan(-binormal_world.x, -binormal_world.z);
	float cosine = cos(rotation);
	float sine = sin(rotation);
	mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
	vec2 new_flow = rotation_mat * flow;
	//new_flow = toLinear(vec4(f, 0.0, 1.0)).rg;
	ALBEDO = vec3((new_flow), 0.0) * 0.5 + 0.5; // repack flowmap
	//ALBEDO = vec3(flow, 0.0);
}