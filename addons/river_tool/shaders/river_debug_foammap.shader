shader_type spatial;

uniform sampler2D flowmap : hint_black;
uniform bool flowmap_set = false;

void fragment() {
	float foam_mask;
	if (flowmap_set) {
		foam_mask = texture(flowmap, UV2).b;
	} else {
		foam_mask = 0.0;
	}
	
	ALBEDO = vec3(foam_mask);
}