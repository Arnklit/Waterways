shader_type canvas_item;

uniform float size = 512.0;
uniform sampler2D input_texture;

vec3 nm2flow(vec2 x) {
    x -= vec2(0.5);
    vec3 rv = vec3(sign(x.x)*vec2(-x.y, x.x), -1.0);
    return normalize(rv);
}

void fragment() {
    vec4 texture_sample = textureLod(input_texture, UV, 0.0);
    vec3 flowmap = nm2flow(texture_sample.xy) * 0.5 + 0.5;
    COLOR = vec4(flowmap, 1.0);
}