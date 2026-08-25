shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.25) = 0.06;
uniform float rect_aspect : hint_range(0.2, 4.0) = 1.333;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(1.0);

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


void fragment() {
	vec2 local_uv = local_position / max(rect_size, vec2(1.0));
	vec2 point = vec2((local_uv.x - 0.5) * rect_aspect, local_uv.y - 0.5);
	vec2 half_size = vec2(0.5 * rect_aspect, 0.5);
	float radius = corner_radius;
	vec2 delta = abs(point) - (half_size - vec2(radius));
	float distance = length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - radius;
	if (distance > 0.0) {
		discard;
	}
	float antialias = max(fwidth(distance), 0.0015);
	vec4 color = texture(TEXTURE, UV);
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(luminance), color.rgb, saturation);
	color.a *= opacity * (1.0 - smoothstep(-antialias, 0.0, distance));
	COLOR = color;
}
