shader_type spatial;

uniform sampler2D arrows : hint_albedo;
uniform sampler2D flowmap : hint_normal;
uniform bool flowmap_set = false;

void fragment() {
	vec2 base_uv = UV * vec2(10.0, 10.0);
	vec2 flow;
	if (flowmap_set) {
		flow = texture(flowmap, UV2).xy;
	} else {
		flow = vec2(0.5, 0.572);
	}
	
	flow = (flow - 0.5) * 2.0; // remap
	float phase1 = fract(TIME * -1.0);
	float phase2 = fract(phase1 + 0.5);
	float flow_mix = abs((phase1 - 0.5) * 2.0);

	vec3 arrows_phase1 = texture(arrows, base_uv + (flow * phase1)).rgb;
	vec3 arrows_phase2 = texture(arrows, base_uv + (flow * phase2)).rgb;

	ALBEDO = mix(arrows_phase1, arrows_phase2, flow_mix);
}