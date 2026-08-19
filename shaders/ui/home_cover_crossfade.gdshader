shader_type canvas_item;

uniform float edge_direction = 0.0;
uniform float feather_width : hint_range(0.001, 0.2) = 0.001;
uniform float card_aspect : hint_range(0.25, 1.5) = 0.62;
uniform float corner_radius : hint_range(0.0, 0.25) = 0.082;
uniform float outer_margin : hint_range(0.0, 0.15) = 0.0;


float rounded_rect_distance(vec2 uv, vec2 offset) {
	vec2 scale = vec2(1.0, 1.0 / card_aspect);
	vec2 point = (uv - vec2(0.5) - offset) * scale;
	vec2 half_size = vec2(0.5 - outer_margin, 0.5 / card_aspect - outer_margin);
	vec2 inner = half_size - vec2(corner_radius);
	vec2 delta = abs(point) - inner;
	return length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - corner_radius;
}


void fragment() {
	float distance = rounded_rect_distance(UV, vec2(0.0));
	float antialias = max(fwidth(distance), 0.0015);
	float card_alpha = 1.0 - smoothstep(0.0, antialias, distance);
	vec4 color = texture(TEXTURE, UV);
	color.a *= card_alpha;

	float edge_alpha = 1.0;
	if (edge_direction > 0.5) {
		edge_alpha = smoothstep(0.0, feather_width, UV.x);
	} else if (edge_direction < -0.5) {
		edge_alpha = smoothstep(0.0, feather_width, 1.0 - UV.x);
	}
	color.a *= edge_alpha;
	COLOR = color;
}
