shader_type canvas_item;

uniform sampler2D input_texture;

void fragment() {
	float value = dot(texture(input_texture, UV).xy, vec2(0.0, 1.0));
	//value = value * 0.5 + 1.0; // pack values
	COLOR = vec4(value, value, value, 1.0);
}