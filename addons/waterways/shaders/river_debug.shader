// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;

const int FLOWMAP = 1;
const int FOAMMAP = 2;
const int NOISEMAP = 3;

const int DISTANCEMAP = 4;
const int PRESSUREMAP = 5;

const int FLOW_PATTERN = 6;
const int FLOW_ARROWS = 7;
const int FLOW_FORCE = 8;

const int FOAM_MIX = 9;


uniform int mode = 1;

uniform sampler2D normal_bump_texture : hint_normal;
uniform sampler2D debug_pattern : hint_black;
uniform sampler2D debug_arrow : hint_black;

uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;

uniform float foam_amount : hint_range(0.0, 4.0) = 1.0;
uniform float foam_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float foam_smoothness : hint_range(0.0, 1.0) = 1.0;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);

uniform sampler2D i_texture_foam_noise : hint_white;
uniform sampler2D i_flowmap : hint_black;
uniform sampler2D i_distmap : hint_white;
uniform bool i_valid_flowmap = false;
uniform int i_uv2_sides = 2;


vec3 FlowUVW(vec2 uv_in, vec2 flowVector, vec2 jump, vec3 tiling, float time, bool flowB) {
	float phaseOffset = flowB ? 0.5 : 0.0;
	float progress = fract(time + phaseOffset);
	vec3 uvw;
	uvw.xy = uv_in - flowVector * (progress - 0.5);
	uvw.xy *= tiling.xy;
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

vec3 grayscale_to_gradient(float gradient) {
	float red = clamp(mix(0.0, 2.0, gradient), 0.0, 1.0);
	float green = clamp(mix(2.0, 0.0, gradient),0.0, 1.0);
	return vec3(red, green, 0.0);
}

void fragment() {
	vec2 custom_UV = (UV2 + 1.0 / float(i_uv2_sides)) * (float(i_uv2_sides) / float(i_uv2_sides + 2));
	vec4 flow_foam_noise = textureLod(i_flowmap, custom_UV, 0.0);
	vec2 dist_pressure = textureLod(i_distmap, custom_UV, 0.0).xy;
	
	vec2 flow;
	float foam_mask;
	float noise_mask;
	float distance_map;
	float pressure_map;
	if (i_valid_flowmap) {
		flow = flow_foam_noise.xy;
		foam_mask = flow_foam_noise.b;
		noise_mask = flow_foam_noise.a;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
	} else {
		flow = vec2(0.5, 0.572);
		foam_mask = 0.0;
		noise_mask = 0.0;
		distance_map = 0.5;
		pressure_map = 0.5;
	}
	flow = (flow - 0.5) * 2.0; // unpack flowmap
	
	// calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (INV_CAMERA_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 8.0;
	
	float flow_force = min(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure, flow_max);
	flow *= flow_force;
	
	if(mode == FLOWMAP) {
		ALBEDO = vec3((flow + 0.5) / 2.0, 0.0); // repack flowmap
		
	} else if(mode == FOAMMAP) {
		ALBEDO = vec3(foam_mask);
		
	} else if(mode == NOISEMAP) {
		ALBEDO = vec3(noise_mask);
		
	} else if(mode == FLOW_PATTERN) {
		vec2 jump = vec2(0.24, 0.2083333);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump, uv_scale, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump, uv_scale, time, true);

		vec3 pattern_a = texture(debug_pattern, flow_uvA.xy).rgb;
		vec3 pattern_b = texture(debug_pattern, flow_uvB.xy).rgb;
		
		vec3 pattern = pattern_a * flow_uvA.z + pattern_b * flow_uvB.z;
		
		ALBEDO = pattern;
		
	} else if(mode == FLOW_ARROWS) {
		vec2 tiled_UV_raw = UV * uv_scale.xy * 10.0;
		vec2 tiled_UV = fract(tiled_UV_raw) - 0.5;
		float rotation = atan(flow.y, flow.x) - 3.14 / 2.0;
		float cosine = cos(rotation);
		float sine = sin(rotation);
		mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
		vec2 new_uv = rotation_mat * tiled_UV + 0.5;
		float lod = mip_map_level(tiled_UV_raw * vec2(textureSize(debug_arrow, 0)));
		ALBEDO = textureLod(debug_arrow, new_uv, lod).rgb;
		
	} else if(mode == FLOW_FORCE) {
		float gradient = clamp(mix(0.0, 1.0, flow_force / flow_max), 0.0, 1.0);
		ALBEDO = grayscale_to_gradient(gradient);
		
	} else if(mode == FOAM_MIX) {
		
		vec2 jump1 = vec2(0.24, 0.2083333);
		vec2 jump2 = vec2(0.20, 0.25);
		float time = TIME * flow_speed + flow_foam_noise.a;
		vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_scale, time, false);
		vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_scale, time, true);
		vec3 flowx2_uvA = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, false);
		vec3 flowx2_uvB = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, true);
		
		vec3 water_a = texture(normal_bump_texture, flow_uvA.xy).rgb;
		vec3 water_b = texture(normal_bump_texture, flow_uvB.xy).rgb;
		vec3 waterx2_a = texture(normal_bump_texture, flowx2_uvA.xy).rgb;
		vec3 waterx2_b = texture(normal_bump_texture, flowx2_uvB.xy).rgb;
		vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;
		
		float water_foamFBM = water.b; // LOD1
		water_foamFBM *= waterx2.b * 2.0; // LOD0 - add second level of detail
		float foam_randomness = texture(i_texture_foam_noise, UV * uv_scale.xy).r;
		foam_mask += steepness_map * foam_randomness * foam_steepness;
		foam_mask = clamp(foam_mask, 0.0, 1.0);
		
		water_foamFBM = clamp((water_foamFBM * foam_amount) - (0.5 / foam_amount), 0.0, 1.0);
		
		float foam_smooth = clamp(water_foamFBM * foam_mask, 0.0, 1.0);
		float foam_sharp = clamp(water_foamFBM - (1.0 - foam_mask), 0.0, 1.0);
		float combined_foam = mix(foam_sharp, foam_smooth, foam_smoothness);
		
		ALBEDO = vec3(combined_foam);
		
	} else if(mode == DISTANCEMAP) {
		ALBEDO = vec3(dist_pressure.r);
		
	} else if(mode == PRESSUREMAP) {
		ALBEDO = vec3(dist_pressure.g);
		
	}
}