shader_type canvas_item;

uniform float edge_direction = 0.0;
uniform float feather_width : hint_range(0.001, 0.2) = 0.001;
uniform float card_aspect : hint_range(0.25, 1.5) = 0.62;
uniform float texture_aspect : hint_range(0.1, 4.0) = 0.62;
uniform float corner_radius : hint_range(0.0, 0.25) = 0.082;
uniform float outer_margin : hint_range(0.0, 0.15) = 0.0;


vec2 destination_uv(vec2 texture_uv) {
	vec2 result = texture_uv;
	if (texture_aspect < card_aspect) {
		float visible_height = texture_aspect / card_aspect;
		result.y = (texture_uv.y - (1.0 - visible_height) * 0.5) / visible_height;
	} else if (texture_aspect > card_aspect) {
		float visible_width = card_aspect / texture_aspect;
		result.x = (texture_uv.x - (1.0 - visible_width) * 0.5) / visible_width;
	}
	return result;
}


float rounded_rect_distance(vec2 uv, vec2 offset) {
	vec2 point = vec2(
		(uv.x - 0.5 - offset.x) * card_aspect,
		uv.y - 0.5 - offset.y
	);
	vec2 half_size = vec2(
		(0.5 - outer_margin) * card_aspect,
		0.5 - outer_margin
	);
	float radius = corner_radius * card_aspect;
	vec2 delta = abs(point) - (half_size - vec2(radius));
	return (
		length(max(delta, vec2(0.0)))
		+ min(max(delta.x, delta.y), 0.0)
		- radius
	);
}


void fragment() {
	vec2 card_uv = destination_uv(UV);
	float distance = rounded_rect_distance(card_uv, vec2(0.0));
	float antialias = max(fwidth(distance), 0.0015);
	float card_alpha = 1.0 - smoothstep(0.0, antialias, distance);
	vec4 color = texture(TEXTURE, UV);
	color.a *= card_alpha;

	float edge_alpha = 1.0;
	if (edge_direction > 0.5) {
		edge_alpha = smoothstep(0.0, feather_width, card_uv.x);
	} else if (edge_direction < -0.5) {
		edge_alpha = smoothstep(0.0, feather_width, 1.0 - card_uv.x);
	}
	color.a *= edge_alpha;
	COLOR = color;
}
