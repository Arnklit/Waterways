shader_type spatial;

const int FLOWMAP = 1;
const int FLOW_PATTERN = 2;
const int FLOW_ARROWS = 3;

const int FOAMMAP = 4;
const int FOAM_MIX = 5;

uniform int mode = 1;
uniform sampler2D texture_water : hint_black;
uniform sampler2D flowmap : hint_black;
uniform sampler2D debug_pattern : hint_black;
uniform sampler2D debug_arrow : hint_black;
uniform bool valid_flowmap = false;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float foam_amount : hint_range(0.0, 4.0) = 1.0;
uniform float foam_smoothness : hint_range(0.0, 1.0) = 1.0;
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

float mip_map_level(in vec2 texture_coordinate) {
    vec2  dx_vtc = dFdx(texture_coordinate);
    vec2  dy_vtc = dFdy(texture_coordinate);
    float delta_max_sqr = max(dot(dx_vtc, dx_vtc), dot(dy_vtc, dy_vtc));
    float mml = 0.5 * log2(delta_max_sqr);
    return max(0, mml);
}

void fragment() {
	vec4 flow_foam_noise = texture(flowmap, UV2);
	vec2 flow;
	float foam_mask;
	if (valid_flowmap) {
		flow = flow_foam_noise.xy;
		foam_mask = flow_foam_noise.b;
	} else {
		flow = vec2(0.5, 0.572);
		foam_mask = 0.0;
	}
	flow = (flow - 0.5) * 2.0; // unpack flowmap
	
	if(mode == FLOWMAP) {
		ALBEDO = vec3((flow + 0.5) / 2.0, 0.0); // repack flowmap
		
	} else if(mode == FLOW_PATTERN) {
		vec2 jump = vec2(0.24, 0.2083333);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump, uv_tiling, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump, uv_tiling, time, true);

		vec3 pattern_a = texture(debug_pattern, flow_uvA.xy).rgb;
		vec3 pattern_b = texture(debug_pattern, flow_uvB.xy).rgb;
		
		vec3 pattern = pattern_a * flow_uvA.z + pattern_b * flow_uvB.z;
		
		ALBEDO = pattern;
		
	} else if(mode == FLOW_ARROWS) {
		vec2 tiled_UV_raw = UV * uv_tiling * 10.0;
		vec2 tiled_UV = fract(tiled_UV_raw) - 0.5;
		float rotation = atan(flow.y, flow.x) - 3.14 / 2.0;
		float cosine = cos(rotation);
		float sine = sin(rotation);
		mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
		vec2 new_uv = rotation_mat * tiled_UV + 0.5;
		float lod = mip_map_level(tiled_UV_raw * vec2(textureSize(debug_arrow, 0)));
		ALBEDO = textureLod(debug_arrow, new_uv, lod).rgb;
		
	} else if(mode == FOAMMAP) {
		ALBEDO = vec3(foam_mask);
		
	} else if(mode == FOAM_MIX) {
		
		vec2 jump1 = vec2(0.24, 0.2083333);
		vec2 jump2 = vec2(0.20, 0.25);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_tiling, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_tiling, time, true);
		vec3 flowx2_uvA = FlowUVW(UV, flow, jump2, uv_tiling * 2.0, time, false);
		vec3 flowx2_uvB = FlowUVW(UV, flow, jump2, uv_tiling * 2.0, time, true);
		
		vec3 water_a = texture(texture_water, flow_uvA.xy).rgb;
		vec3 water_b = texture(texture_water, flow_uvB.xy).rgb;
		vec3 waterx2_a = texture(texture_water, flowx2_uvA.xy).rgb;
		vec3 waterx2_b = texture(texture_water, flowx2_uvB.xy).rgb;
		vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;
		
		float water_foamFBM = water.b; // LOD1
		water_foamFBM *= waterx2.b * 2.0; // LOD0 - add second level of detail
		
		water_foamFBM = clamp((water_foamFBM * foam_amount) - (0.5 / foam_amount), 0.0, 1.0);
		
		float foam_smooth = clamp(water_foamFBM * foam_mask, 0.0, 1.0);
		float foam_sharp = clamp(water_foamFBM - (1.0 - foam_mask), 0.0, 1.0);
		float combined_foam = mix(foam_sharp, foam_smooth, foam_smoothness);
		
		ALBEDO = vec3(combined_foam);
	}
}