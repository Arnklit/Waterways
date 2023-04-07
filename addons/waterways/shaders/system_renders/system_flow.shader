shader_type spatial;
render_mode unshaded;

uniform sampler2D flowmap : hint_normal;
uniform sampler2D distmap : hint_white;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;
uniform bool valid_flowmap = false;

varying vec3 binormal_world;


void vertex() {
	binormal_world = (WORLD_MATRIX * vec4(BINORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 flow_foam_noise = textureLod(flowmap, UV2, 0.0).rg;
	vec2 dist_pressure = textureLod(distmap, UV2, 0.0).xy;
	
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
	vec3 up_viewspace = (INV_CAMERA_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float flow_force = min(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure, flow_max);
	flow *= flow_force;
	
	float rotation = atan(-binormal_world.x, -binormal_world.z);
	float cosine = cos(rotation);
	float sine = sin(rotation);
	mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
	vec2 new_flow = rotation_mat * flow;
	ALBEDO = vec3((new_flow), 0.0) * 0.5 + 0.5; // repack flowmap
}