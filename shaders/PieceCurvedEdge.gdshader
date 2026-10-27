shader_type canvas_item;
render_mode unshaded;

// Cached local height-gradient data, separate from untouched original artwork UV.
uniform sampler2D slope_field : filter_linear, repeat_disable;
uniform vec2 field_origin;
uniform vec2 field_size;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 original = COLOR;
	vec2 local_slope = texture(slope_field, (local_position - field_origin) / field_size).rg;
	vec2 gradient = vec2(dot(local_slope, dFdx(local_position)), dot(local_slope, dFdy(local_position)));
	vec2 screen_slope = gradient / max(length(gradient), 0.00001) * length(local_slope);
	vec3 normal = normalize(vec3(-screen_slope, 1.0));
	vec3 light_direction = normalize(vec3(-0.55, -0.70, 1.0));
	float diffuse = max(dot(normal, light_direction), 0.0);
	float illumination = (0.55 + 0.45 * diffuse) / (0.55 + 0.45 * light_direction.z);
	COLOR = vec4(original.rgb * illumination, original.a);
}
