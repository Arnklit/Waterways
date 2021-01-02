shader_type canvas_item;

uniform vec4 color1 = vec4(0.25, 0.25, 0.70, 1.0);
uniform vec4 color2 = vec4(0.25, 0.50, 0.70, 1.0);

void fragment() {
	vec4 mixed_color = mix(color1, color2, UV.x);
	COLOR = mixed_color;
}