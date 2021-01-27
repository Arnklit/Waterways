// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx, cull_disabled;

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the River inspector.

// Use prefixes: albedo_, emission_, transparency_, flow_, foam_ and custom_
// to automatically put your parameters into categories in the inspector.

// If "curve" is in the name, the inspector will represent and easing curve.
// mat4´s with "color" in their name will get parsed as gradients.

// Main
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform sampler2D normal_bump_texture : hint_normal;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.25;

// Albedo
uniform mat4 albedo_color = mat4(vec4(0.0, 0.15, 0.0, 0.0), vec4(0.8, 0.2, 0.0, 0.0), vec4(1.0, 0.5, 0.0, 0.0), vec4(0.0));
uniform float albedo_depth : hint_range(0.0, 200.0) = 10.0;
uniform float albedo_depth_curve = 0.25;

// Transparency
uniform float transparency_clarity : hint_range(0.0, 200.0) = 10.0;
uniform float transparency_depth_curve = 0.25;
uniform float transparency_refraction : hint_range(-1.0, 1.0) = 0.05;

// Flow
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;

// Foam
uniform vec4 foam_color : hint_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float foam_amount : hint_range(0.0, 4.0) = 2.0;
uniform float foam_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float foam_smoothness : hint_range(0.0, 1.0) = 0.3;

// Internal uniforms - DO NOT CUSTOMIZE THESE
uniform float i_lod0_distance : hint_range(5.0, 200.0) = 50.0;
uniform sampler2D i_texture_foam_noise : hint_white;
uniform sampler2D i_flowmap : hint_normal;
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

// ease implementation copied from math_funcs.cpp in source
float ease(float p_x, float p_c) {
	if (p_x < 0.0) {
		p_x = 0.0;
	} else if (p_x > 1.0) {
		p_x = 1.0;
	}
	if (p_c > 0.0) {
		if (p_c < 1.0) {
			return 1.0 - pow(1.0 - p_x, 1.0 / p_c);
		} else {
			return pow(p_x, p_c);
		}
	} else if (p_c < 0.0) {
		//inout ease
		
		if (p_x < 0.5) {
			return pow(p_x * 2.0, -p_c) * 0.5;
		} else {
			return (1.0 - pow(1.0 - (p_x - 0.5) * 2.0, -p_c)) * 0.5 + 0.5;
		}
	} else {
		return 0.0; // no ease (raw)
	}
}

float lin2srgb(float lin) {
	return pow(lin, 2.2);
}

mat4 gradient_lin2srgb(mat4 lin_mat) {
	mat4 srgb_mat = mat4(
		vec4(lin2srgb(lin_mat[0].x), lin2srgb(lin_mat[0].y), lin2srgb(lin_mat[0].z), lin2srgb(lin_mat[0].w)),
		vec4(lin2srgb(lin_mat[1].x), lin2srgb(lin_mat[1].y), lin2srgb(lin_mat[1].z), lin2srgb(lin_mat[1].w)),
		vec4(0.0),
		vec4(0.0)
	);
	return srgb_mat;
}

void fragment() {
	// Sample the UV2 textures. To avoid issues with the UV2 seams, margins
	// are left on the textures, so the UV2 needs to be rescaled to cut off
	// the margins.
	vec2 custom_UV = (UV2 + 1.0 / float(i_uv2_sides)) * (float(i_uv2_sides) / float(i_uv2_sides + 2));
	vec4 flow_foam_noise = textureLod(i_flowmap, custom_UV, 0.0);
	vec2 dist_pressure = textureLod(i_distmap, custom_UV, 0.0).xy;
	
	vec2 flow;
	float distance_map;
	float pressure_map;
	float foam_mask;
	if (i_valid_flowmap) {
		flow = flow_foam_noise.xy;
		distance_map = (1.0 - dist_pressure.r) * 2.0;
		pressure_map = dist_pressure.g * 2.0;
		foam_mask = flow_foam_noise.b;
	} else {
		flow = vec2(0.5, 0.572);
		distance_map = 0.5;
		pressure_map = 0.5;
		foam_mask = 0.0;
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
	
	// Level 1 Water
	vec3 water_a = texture(normal_bump_texture, flow_uvA.xy).rgb;
	vec3 water_b = texture(normal_bump_texture, flow_uvB.xy).rgb;
	vec3 water = water_a * flow_uvA.z + water_b * flow_uvB.z;

	vec2 water_norFBM = water.rg;
	float water_foamFBM = water.b;

	// Level 2 Water, only add in if closer than lod 0 distance
	if (-VERTEX.z < i_lod0_distance) {
		vec3 waterx2_a = texture(normal_bump_texture, flowx2_uvA.xy).rgb;
		vec3 waterx2_b = texture(normal_bump_texture, flowx2_uvB.xy, 0.0).rgb;
		vec3 waterx2 = waterx2_a * flowx2_uvA.z + waterx2_b * flowx2_uvB.z;

		water_norFBM *= 0.65;
		water_norFBM += waterx2.rg * 0.35;
		water_foamFBM *= waterx2.b * 2.0;
	}
	
	float foam_randomness = texture(i_texture_foam_noise, UV * uv_scale.xy).r;
	
	foam_mask += steepness_map * foam_steepness * foam_randomness;
	foam_mask = clamp(foam_mask, 0.0, 1.0);
	water_foamFBM = clamp((water_foamFBM * foam_amount) - (0.5 / foam_amount), 0.0, 1.0);
	float foam_smooth = clamp(water_foamFBM * foam_mask, 0.0, 1.0);
	float foam_sharp = clamp(water_foamFBM - (1.0 - foam_mask), 0.0, 1.0);
	float combined_foam = mix(foam_sharp, foam_smooth, foam_smoothness);

	// Depthtest
	float depth_tex = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	float depth_tex_unpacked = depth_tex * 2.0 - 1.0;
	float surface_dist = PROJECTION_MATRIX[3][2] / (depth_tex_unpacked + PROJECTION_MATRIX[2][2]);
	float water_depth = surface_dist + VERTEX.z;
	
	
	float alb_t = clamp(water_depth / albedo_depth, 0.0, 1.0);
	alb_t = ease(alb_t, albedo_depth_curve);
	SPECULAR = 0.25; // Supposedly clear water has approximately a 0.25 specular value
	ROUGHNESS = roughness;
	NORMALMAP = vec3(water_norFBM, 0);
	NORMALMAP_DEPTH = normal_scale;

	
	// Refraction - has to be done after normal is set
	vec3 unpacted_normals = NORMALMAP * 2.0 - 1.0;
	//vec3 ref_normal = normalize( mix(NORMAL, TANGENT * unpacted_normals.x + BINORMAL * unpacted_normals.y + NORMAL, NORMALMAP_DEPTH) );
	vec3 ref_normal = normalize(TANGENT * unpacted_normals.x + BINORMAL * unpacted_normals.y) * NORMALMAP_DEPTH * .1;
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * transparency_refraction;
	float clar_t = clamp(water_depth / transparency_clarity, 0.0, 1.0);
	clar_t = ease(clar_t, transparency_depth_curve);
	float ref_amount = 1.0 - clamp(clar_t + combined_foam, 0.0, 1.0);

	// Depthtest 2
	float depth_tex2 = textureLod(DEPTH_TEXTURE, ref_ofs, 0.0).r;
	float depth_tex_unpacked2 = depth_tex2 * 2.0 - 1.0;
	float surface_dist2 = PROJECTION_MATRIX[3][2] / (depth_tex_unpacked2 + PROJECTION_MATRIX[2][2]);
	float water_depth2 = surface_dist2 + VERTEX.z;
	
	if (surface_dist2 < -VERTEX.z) {
		ref_ofs = SCREEN_UV;
	} else {
		clar_t = clamp(water_depth2 / transparency_clarity, 0.0, 1.0);
		clar_t = ease(clar_t, transparency_depth_curve);
		ref_amount = 1.0 - clamp(clar_t + combined_foam, 0.0, 1.0);
		alb_t = clamp(water_depth2 / albedo_depth, 0.0, 1.0);
		alb_t = ease(alb_t, albedo_depth_curve);
	}
	mat4 albedo_color_srgb = gradient_lin2srgb(albedo_color);
	vec3 albedo_color_near = vec3(albedo_color_srgb[0].x, albedo_color_srgb[0].y, albedo_color_srgb[0].z);
	vec3 albedo_color_far = vec3(albedo_color_srgb[1].x, albedo_color_srgb[1].y, albedo_color_srgb[1].z);
	vec3 alb_mix = mix(albedo_color_near.rgb, albedo_color_far.rgb, alb_t);
	ALBEDO = mix(alb_mix, foam_color.rgb, combined_foam);
	// TODO - Go over to using texelfetch to get the texture to avoid edge artifacts
	EMISSION += textureLod(SCREEN_TEXTURE, ref_ofs, ROUGHNESS * water_depth2).rgb * ref_amount;

	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
	TRANSMISSION = vec3(0.9);

	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex * 2.0 - 1.0, 1.0);
	world_pos.xyz /= world_pos.w;
	ALPHA *= clamp(1.0 - smoothstep(world_pos.z + edge_fade, world_pos.z, VERTEX.z), 0.0, 1.0);
}