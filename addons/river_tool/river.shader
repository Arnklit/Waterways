shader_type spatial;
render_mode depth_draw_always, specular_schlick_ggx;

uniform vec4 albedo : hint_color = vec4(0.1, 0.1, 0.1, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float refraction : hint_range(-1.0, 1.0) = 0.05;
uniform float absorption : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	float depthTest = texture(DEPTH_TEXTURE,SCREEN_UV).r;
	depthTest = depthTest * 2.0 - 1.0;
	depthTest = PROJECTION_MATRIX[3][2] / (depthTest + PROJECTION_MATRIX[2][2]);
	depthTest += VERTEX.z;

	vec2 base_uv = UV;
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	vec3 normal_tex = texture(texture_normal,base_uv + vec2(0.0, -.25 * TIME * flow_speed)).rgb;
	vec3 normal_tex2 = texture(texture_normal,base_uv * vec2(2.0, 2.0) + vec2(0.0, -.25 * TIME * flow_speed)).rgb;
	vec3 normal_tex4 = texture(texture_normal,base_uv * vec2(4.0, 4.0) + vec2(0.0, -.25 * TIME * flow_speed)).rgb;
	NORMALMAP = (normal_tex + normal_tex2 * 0.5 + normal_tex4 * 0.25) / 1.75;
	NORMALMAP_DEPTH = normal_scale;
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction * depthTest * .2;
	float ref_amount = 1.0 - clamp(depthTest * absorption + albedo.a, 0.0, 1.0);
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
}