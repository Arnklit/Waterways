shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx;

uniform vec4 albedo : hint_color = vec4(0.1, 0.1, 0.1, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float refraction : hint_range(-1.0, 1.0) = 0.05;
uniform float absorption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_normal : hint_normal;
uniform sampler2D texture_foam : hint_white;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D distance_map : hint_black;
uniform sampler2D flow_map : hint_normal;
uniform vec2 uv_tiling = vec2(1.0, 1.0);

void fragment() {
	vec2 base_uv = UV * uv_tiling;
	vec2 flow = texture(flow_map, UV2).xy;
	flow = (flow - 0.5) * 2.0; // remap
	float phase1 = fract(TIME * -flow_speed);
	float phase2 = fract(phase1 + 0.5);
	float flow_mix = abs((phase1 - 0.5) * 2.0);
		
	float depthTest = texture(DEPTH_TEXTURE,SCREEN_UV).r;
	depthTest = depthTest * 2.0 - 1.0;
	depthTest = PROJECTION_MATRIX[3][2] / (depthTest + PROJECTION_MATRIX[2][2]);
	depthTest += VERTEX.z;

	float foam_tex_phase1 = texture(texture_foam, base_uv + (flow * phase1 * flow_speed)).r;
	float foam_tex_phase2 = texture(texture_foam, base_uv + (flow * phase2 * flow_speed)).r;
	float foam = clamp(mix(foam_tex_phase1, foam_tex_phase2, flow_mix) * 4.0 - 1.5, 0.0, 1.0);
	float foam_mask = texture( distance_map, UV2).r * 3.0;

	ALBEDO = mix(albedo.rgb, vec3(1.0, 1.0, 1.0), foam * foam_mask);
	//ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	vec3 normal_tex_phase1 = texture(texture_normal, base_uv + (flow * phase1 * flow_speed)).rgb;
	vec3 normal_tex_phase2 = texture(texture_normal, base_uv + (flow * phase2 * flow_speed)).rgb;
	vec3 normal_tex2_phase1 = texture(texture_normal, base_uv * vec2(2.0, 2.0) + (flow * phase1 * flow_speed)).rgb;
	vec3 normal_tex2_phase2 = texture(texture_normal, base_uv * vec2(2.0, 2.0) + (flow * phase2 * flow_speed)).rgb;
	NORMALMAP = mix((normal_tex_phase1 * .65 + normal_tex2_phase1 * 0.35), (normal_tex_phase2 * .65 + normal_tex2_phase2 * 0.35), flow_mix);
	NORMALMAP_DEPTH = normal_scale;
	// Refraction
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction * depthTest * .2;
	float ref_amount = 1.0 - clamp(depthTest * absorption + albedo.a, 0.0, 1.0);
	//float ref_amount = 1.0 - clamp(foam * foam_mask + albedo.a, 0.0, 1.0);	
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;


}