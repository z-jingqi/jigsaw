shader_type canvas_item;

uniform float edge_direction = 0.0;
uniform float feather_width : hint_range(0.001, 0.2) = 0.001;


void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float edge_alpha = 1.0;
	if (edge_direction > 0.5) {
		edge_alpha = smoothstep(0.0, feather_width, UV.x);
	} else if (edge_direction < -0.5) {
		edge_alpha = smoothstep(0.0, feather_width, 1.0 - UV.x);
	}
	color.a *= edge_alpha;
	COLOR = color;
}
