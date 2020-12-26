shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;

vec3 nm2flow(vec2 x) {
    x -= vec2(0.5);
    vec3 rv = vec3(sign(x.x)*vec2(-x.y, x.x), -1.0);
    return rv;
}

void fragment() {
    // Create two copies of the flowmap sligtly offset by each other and combine
    // them with lighten to remove seam
    vec4 texture1 = texture(input_texture, UV + vec2(1.0 / size), 0.0);
    vec4 texture2 = texture(input_texture, UV - vec2(1.0 / size), 0.0);
    vec3 flowmap1 = nm2flow(texture1.xy);
    vec3 flowmap2 = nm2flow(texture2.xy);
    vec3 combined_texture = 0.5*normalize(mix(flowmap1, flowmap2, 0.5))+vec3(0.5);
    COLOR = vec4(combined_texture, 1.0);
}