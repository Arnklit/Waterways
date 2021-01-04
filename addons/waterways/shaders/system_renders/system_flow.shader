shader_type spatial;
render_mode unshaded;

uniform sampler2D flowmap : hint_normal;
varying vec3 binormal_world;

void vertex() {
	binormal_world = (WORLD_MATRIX * vec4(BINORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 flow = texture(flowmap, UV2).rg * 2.0 - 1.0;
	float rotation = atan(-binormal_world.x, -binormal_world.z);
	float cosine = cos(rotation);
	float sine = sin(rotation);
	mat2 rotation_mat = mat2(vec2(cosine, -sine), vec2(sine, cosine));
	vec2 new_flow = rotation_mat * flow;
	ALBEDO = vec3((new_flow), 0.0) * 0.5 + 0.5; // repack flowmap
	//ALBEDO = vec3(0.5, 0.5, 0.0); 
}