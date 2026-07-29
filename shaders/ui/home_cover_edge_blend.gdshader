shader_type canvas_item;

uniform float edge_direction = 0.0;
uniform float feather_width : hint_range(0.01, 0.2) = 0.08;
uniform float feather_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 feather_color : source_color = vec4(1.0, 0.9569, 0.8627, 1.0);


void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float edge_mask = 1.0;
	if (edge_direction > 0.5) {
		edge_mask = smoothstep(0.0, feather_width, UV.x);
	} else if (edge_direction < -0.5) {
		edge_mask = smoothstep(0.0, feather_width, 1.0 - UV.x);
	}
	float feather_amount = (1.0 - edge_mask) * feather_strength * 0.32;
	color.rgb = mix(color.rgb, feather_color.rgb, feather_amount);
	COLOR = color;
}
