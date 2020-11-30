shader_type spatial;

uniform sampler2D flowmap : hint_normal;
uniform bool flowmap_set = false;

void fragment() {
	vec2 flow;
	if (flowmap_set) {
		flow = texture(flowmap, UV2).xy;
	} else {
		flow = vec2(0.5, 0.572);
	}
	
	ALBEDO = vec3(flow, 0.0);
}