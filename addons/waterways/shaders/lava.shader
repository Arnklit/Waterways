// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_always, cull_disabled;

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the River inspector.

// Use prefixes: albedo_, emission_, transparency_, flow_, foam_ and custom_
// to automatically put your parameters into categories in the inspector.

// If "curve" is in the name, the inspector will represent and easing curve
// mat4s will get parsed as gradients, see documentation for details

// main
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform sampler2D normal_bump_texture : hint_normal;
uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.25;

// emission
uniform mat4 emission_color = mat4(vec4(1.0, 1.0, 0.0, 0.0), vec4(1.0, 0.5, 0.0, 0.0), vec4(1.0, 0.5, 0.0, 0.0), vec4(0.0));
uniform float emission_energy : hint_range(0.0, 20.0) = 4.0;
uniform float emission_depth : hint_range(0.0, 200.0) = 3.0;
uniform float emission_depth_curve = 0.25;
uniform sampler2D emission_texture : hint_black_albedo;

// flow
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform float flow_base : hint_range(0.0, 8.0) = 0.0;
uniform float flow_steepness : hint_range(0.0, 8.0) = 2.0;
uniform float flow_distance : hint_range(0.0, 8.0) = 1.0;
uniform float flow_pressure : hint_range(0.0, 8.0) = 1.0;
uniform float flow_max : hint_range(0.0, 8.0) = 4.0;

// Internal uniforms, do not customize these
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
	if (i_valid_flowmap) {
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
	float time = TIME * flow_speed + flow_foam_noise.a;
	vec3 flow_uvA = FlowUVW(UV, flow, jump1, uv_scale, time, false);
	vec3 flow_uvB = FlowUVW(UV, flow, jump1, uv_scale, time, true);
	
	// Level 1 Lava
	vec3 lava_nor_bump_a = texture(normal_bump_texture, flow_uvA.xy).rgb;
	vec3 lava_nor_bump_b = texture(normal_bump_texture, flow_uvB.xy).rgb;
	vec3 lava_nor_bump = lava_nor_bump_a * flow_uvA.z + lava_nor_bump_b * flow_uvB.z;
	
	vec3 lava_emission_a = texture(emission_texture, flow_uvA.xy).rgb;
	vec3 lava_emission_b = texture(emission_texture, flow_uvB.xy).rgb;
	vec3 lava_emission = lava_emission_a * flow_uvA.z + lava_emission_b * flow_uvB.z;
	
	vec2 lava_norFBM = lava_nor_bump.rg;
	float lava_bumpFBM = lava_nor_bump.b; // TODO - Will we use this?
	
	// Depthtest
	float depth_tex = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	float depth_tex_unpacked = depth_tex * 2.0 - 1.0;
	float surface_dist = PROJECTION_MATRIX[3][2] / (depth_tex_unpacked + PROJECTION_MATRIX[2][2]);
	float lava_depth = surface_dist + VERTEX.z;
	
	ROUGHNESS = roughness;
	NORMALMAP = vec3(lava_norFBM, 0);
	NORMALMAP_DEPTH = normal_scale;
	
	float emission_t = clamp(lava_depth / emission_depth, 0.0, 1.0);
	emission_t = ease(emission_t, emission_depth_curve);
	
	mat4 emission_color_srgb = gradient_lin2srgb(emission_color);
	vec3 emission_color_near = vec3(emission_color_srgb[0].x, emission_color_srgb[0].y, emission_color_srgb[0].z);
	vec3 emission_color_far = vec3(emission_color_srgb[1].x, emission_color_srgb[1].y, emission_color_srgb[1].z);

	vec3 final_lava = mix(lava_emission * emission_color_near.rgb, lava_emission * emission_color_far.rgb, emission_t);
	
	ALBEDO = vec3(0.0);
	EMISSION = final_lava * emission_energy;
	
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex * 2.0 - 1.0, 1.0);
	world_pos.xyz /= world_pos.w;
	ALPHA = 1.0;
	ALPHA *= clamp(1.0 - smoothstep(world_pos.z + edge_fade, world_pos.z, VERTEX.z), 0.0, 1.0);
}