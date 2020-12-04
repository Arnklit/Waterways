shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx;

uniform vec4 albedo : hint_color = vec4(0.1, 0.1, 0.1, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float refraction : hint_range(-1.0, 1.0) = 0.05;
uniform float absorption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_water : hint_black;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform vec4 foam_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_amount : hint_range(0.0, 10.0) = 2.0;
uniform sampler2D flowmap : hint_normal;
uniform bool flowmap_set = false;
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
	// Setup for flow_maps
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
	flow = (flow - 0.5) * 2.0; // remap
	
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
	vec2 water_norFBM = water.rg * 0.65 + waterx2.rg * 0.35;
	float water_foamFBM = water.b * waterx2.b;
	float combined_foam = foam_mask * water_foamFBM * foam_amount * 3.0;
	
	
	// Depthtest
	float depthTest = texture(DEPTH_TEXTURE,SCREEN_UV).r;
	depthTest = depthTest * 2.0 - 1.0;
	depthTest = PROJECTION_MATRIX[3][2] / (depthTest + PROJECTION_MATRIX[2][2]);
	depthTest += VERTEX.z;

	// Refraction
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction * depthTest * .2;
	float ref_amount = 1.0 - clamp(depthTest * absorption + albedo.a + combined_foam, 0.0, 1.0);

	ALBEDO = mix(albedo.rgb, foam_color.rgb, combined_foam);
	ROUGHNESS = roughness;
	NORMALMAP = vec3(water_norFBM, 0);
	NORMALMAP_DEPTH = normal_scale;
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
}