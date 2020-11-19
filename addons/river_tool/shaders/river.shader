shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx;

uniform vec4 albedo : hint_color = vec4(0.1, 0.1, 0.1, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float refraction : hint_range(-1.0, 1.0) = 0.05;
uniform float absorption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_water : hint_black;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D flowmap : hint_normal;
uniform bool flowmap_set = false;
uniform vec2 uv_tiling = vec2(1.0, 1.0);

void fragment() {
	// Setup for flow_maps
	vec2 base_uv = UV * uv_tiling;
	vec2 flow;
	float foam_mask;
	if (flowmap_set) {
		flow = texture(flowmap, UV2).xy;
		foam_mask = texture(flowmap, UV2).b * 2.0;
	} else {
		flow = vec2(0.5, 0.572);
		foam_mask = 0.0;
	}
	
	flow = (flow - 0.5) * 2.0; // remap
	float phase1 = fract(TIME * -flow_speed);
	float phase2 = fract(phase1 + 0.5);
	float flow_mix = abs((phase1 - 0.5) * 2.0);
	
	// Sample the water texture 4 times to use for both normals and foam
	// At 2 different scales and two different phases
	vec3 water_x1_phase1 = texture(texture_water, base_uv + (flow * phase1 * flow_speed)).rgb;
	vec3 water_x1_phase2 = texture(texture_water, base_uv + (flow * phase2 * flow_speed)).rgb;
	vec3 water_x2_phase1 = texture(texture_water, base_uv * vec2(2.0, 2.0) + (flow * phase1 * flow_speed)).rgb;
	vec3 water_x2_phase2 = texture(texture_water, base_uv * vec2(2.0, 2.0) + (flow * phase2 * flow_speed)).rgb;
	// Mix the water texture's 2 phases for x1 scale and x2 scale
	vec3 water_x1 = mix(water_x1_phase1, water_x1_phase2, flow_mix);
	vec3 water_x2 = mix(water_x2_phase1, water_x2_phase2, flow_mix);

	// Mix the two scales together for the foam pattern
	float foam = clamp((water_x1.b * .65 + water_x2.b * 0.35) * 4.0 - 1.5, 0.0, 1.0);

	// Depthtest
	float depthTest = texture(DEPTH_TEXTURE,SCREEN_UV).r;
	depthTest = depthTest * 2.0 - 1.0;
	depthTest = PROJECTION_MATRIX[3][2] / (depthTest + PROJECTION_MATRIX[2][2]);
	depthTest += VERTEX.z;

	// Refraction
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction * depthTest * .2;
	float ref_amount = 1.0 - clamp(depthTest * absorption + albedo.a, 0.0, 1.0);


	ALBEDO = mix(albedo.rgb, vec3(1.0, 1.0, 1.0), foam * foam_mask);
	ROUGHNESS = roughness;
	NORMALMAP = vec3(water_x1.rg * .65 + water_x1.rg * 0.35, 1.0);
	NORMALMAP_DEPTH = normal_scale;
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
}