shader_type spatial;

const int FLOWMAP = 0;
const int FLOW_PATTERN = 1;

const int FOAMMAP = 2;
const int FOAM_MIX = 3;

uniform int mode = 0;
uniform sampler2D texture_water : hint_black;
uniform sampler2D flowmap : hint_black;
uniform bool flowmap_set = false;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D debug_pattern : hint_black;
uniform float foam_amount : hint_range(0.0, 10.0) = 2.0;
uniform float uv_tiling = 1.0;

vec3 FlowUVW(vec2 uv_in, vec2 flowVector, vec2 jump, float tiling, float time, bool flowB) {
	float phaseOffset = flowB ? 0.5 : 0.0;
	float progress = fract(time + phaseOffset);
	vec3 uvw;
	uvw.xy = uv_in - flowVector * (progress - 0.5);
	uvw.xy *= tiling;
	uvw.xy += phaseOffset;
	uvw.xy += (time - progress) * jump;
	uvw.z = 1.0 - abs(1.0 - 2.0 * progress);
	return uvw;
}

void fragment() {
	vec4 flow_foam_noise = texture(flowmap, UV2);
	vec2 flow;
	float foam_mask;
	if (flowmap_set) {
		flow = flow_foam_noise.xy;
		foam_mask = flow_foam_noise.b;
	} else {
		flow = vec2(0.5, 0.572);
		foam_mask = 0.0;
	}
	
	
	
	if(mode == 0) {
		ALBEDO = vec3(flow, 0.0);
		
	} else if(mode == 1) {
		vec2 jump = vec2(0.24, 0.2083333);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump, uv_tiling, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump, uv_tiling, time, true);

		vec3 pattern_a = texture(debug_pattern, flow_uvA.xy).rgb;
		vec3 pattern_b = texture(debug_pattern, flow_uvB.xy).rgb;
		
		vec3 pattern = pattern_a * flow_uvA.z + pattern_b * flow_uvB.z;
		
		ALBEDO = pattern;
		
	} else if(mode == 2) {
		ALBEDO = vec3(foam_mask);
		
	} else if(mode == 3) {
		vec2 jump = vec2(0.24, 0.2083333);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump, uv_tiling, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump, uv_tiling, time, true);

		vec3 water_a = texture(texture_water, flow_uvA.xy).rgb;
		vec3 water_b = texture(texture_water, flow_uvB.xy).rgb;
		
		vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;
		
		float combined_foam = clamp(foam_mask * water.b * foam_amount, 0.0, 1.0);
		
		ALBEDO = vec3(combined_foam);
		
	}
}