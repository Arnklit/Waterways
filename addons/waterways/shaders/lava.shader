// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx, cull_disabled;

// flow
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;

uniform sampler2D normal_bump_texture : hint_normal;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.25;

uniform sampler2D albedo_texture : hint_black;

uniform sampler2D emission_texture : hint_black;

uniform float lod0_distance : hint_range(5.0, 200.0) = 50.0;

uniform sampler2D flowmap : hint_normal;
uniform sampler2D distmap : hint_white;
uniform bool valid_flowmap = false;
uniform int uv2_sides = 2;

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

void fragment() {
	// Sample the UV2 textures. To avoid issues with the UV2 seams, margins
	// are left on the textures, so the UV2 needs to be rescaled to cut off
	// the margins.
	vec2 custom_UV = (UV2 + 1.0 / float(uv2_sides)) * (float(uv2_sides) / float(uv2_sides + 2));
	vec4 flow_foam_noise = textureLod(flowmap, custom_UV, 0.0);
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
	
	flow = (flow - 0.5) * 2.0; // unpack the flow vectors
	
	// Calculate the steepness map
	vec3 flow_viewspace = flow.x * TANGENT + flow.y * BINORMAL;
	vec3 up_viewspace = (INV_CAMERA_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float steepness_map = max(0.0, dot(flow_viewspace, up_viewspace)) * 4.0;
	
	float flow_force = min(flow_base + steepness_map * flow_steepness + distance_map * flow_distance + pressure_map * flow_pressure, flow_max);
	flow *= flow_force;
	
	vec2 jump1 = vec2(0.24, 0.2083333);
	vec2 jump2 = vec2(0.20, 0.25);
	vec2 jump3 = vec2(0.22, 0.27);
	float time = TIME * flow_speed + flow_foam_noise.a;
	vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_scale, time, false);
	vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_scale, time, true);
	vec3 flowx2_uvA = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, false);
	vec3 flowx2_uvB = FlowUVW(UV, flow, jump2, uv_scale * 2.0, time, true);
	
	// Level 1 Lava
	vec3 lava_nor_bump_a = texture(normal_bump_texture, flow_uvA.xy).rgb;
	vec3 lava_nor_bump_b = texture(normal_bump_texture, flow_uvB.xy).rgb;
	vec3 lava_nor_bump = lava_nor_bump_a * flow_uvA.z + lava_nor_bump_b * flow_uvB.z;
	
	vec3 lava_albedo_a = texture(albedo_texture, flow_uvA.xy).rgb;
	vec3 lava_albedo_b = texture(albedo_texture, flow_uvB.xy).rgb;
	vec3 lave_albedo = lava_albedo_a * flow_uvA.z + lava_albedo_b * flow_uvB.z;
	
	vec3 lava_emission_a = texture(emission_texture, flow_uvA.xy).rgb;
	vec3 lava_emission_b = texture(emission_texture, flow_uvB.xy).rgb;
	vec3 lava_emission = lava_emission_a * flow_uvA.z + lava_emission_b * flow_uvB.z;
	
	vec2 lava_norFBM = lava_nor_bump.rg;
	float lava_bumpFBM = lava_nor_bump.b; // TODO - Will we use this?

	// Level 2 Water, only add in if closer than lod 0 distance
	if (-VERTEX.z < lod0_distance) {
		vec3 waterx2_a = texture(normal_bump_texture, flowx2_uvA.xy).rgb;
		vec3 waterx2_b = texture(normal_bump_texture, flowx2_uvB.xy, 0.0).rgb;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;

		water_norFBM *= 0.65;
		water_norFBM += waterx2.rg * 0.35;
	}
	
	SPECULAR = 0.25; // Supposedly clear water has approximately a 0.25 specular value
	ROUGHNESS = roughness;
	NORMALMAP = vec3(water_norFBM, 0);
	NORMALMAP_DEPTH = normal_scale;
	
	ALBEDO = 
	// TODO - Go over to using texelfetch to get the texture to avoid edge artifacts
	EMISSION += textureLod(SCREEN_TEXTURE, ref_ofs, ROUGHNESS * water_depth2 * 2.0).rgb * ref_amount;

	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
	TRANSMISSION = vec3(0.9);

	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex * 2.0 - 1.0, 1.0);
	world_pos.xyz /= world_pos.w;
	ALPHA *= clamp(1.0 - smoothstep(world_pos.z + edge_fade, world_pos.z, VERTEX.z), 0.0, 1.0);
}