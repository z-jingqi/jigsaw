shader_type canvas_item;

uniform vec2 control_size = vec2(160.0, 248.0);
uniform float corner_radius_px : hint_range(0.0, 64.0) = 22.0;
uniform float shade_strength : hint_range(0.0, 1.0) = 0.72;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

float rounded_rect_sdf(vec2 point, vec2 half_size, float radius) {
	vec2 distance_to_edge = abs(point) - (half_size - vec2(radius));
	return length(max(distance_to_edge, vec2(0.0)))
		+ min(max(distance_to_edge.x, distance_to_edge.y), 0.0)
		- radius;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 pixel = local_position - control_size * 0.5;
	float radius = min(corner_radius_px, min(control_size.x, control_size.y) * 0.48);
	float distance = rounded_rect_sdf(pixel, control_size * 0.5, radius);
	float antialias = max(fwidth(distance) * 1.25, 0.75);
	float mask = 1.0 - smoothstep(-antialias, antialias, distance);
	float local_y = clamp(local_position.y / max(control_size.y, 1.0), 0.0, 1.0);
	float shade = smoothstep(0.50, 1.0, local_y) * shade_strength;
	texel.rgb = mix(texel.rgb, vec3(0.075, 0.035, 0.016), shade);
	texel.a *= mask;
	COLOR = texel;
}
