shader_type canvas_item;
render_mode unshaded;

// Prototype: the unchanged polygon supplies coverage and the original artwork UV.
// Height is flat in the centre, then bends down quadratically to the cut edge.
uniform vec2 outline[64];
uniform int outline_count = 0;
uniform float curve_width = 12.0;
uniform float depth_ratio = 0.36;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 original = COLOR;
	float distance_to_edge = 100000.0;
	for (int i = 0; i < outline_count; i++) {
		vec2 a = outline[i];
		vec2 b = outline[(i + 1) % outline_count];
		vec2 edge = b - a;
		float along = clamp(dot(local_position - a, edge) / max(dot(edge, edge), 0.00001), 0.0, 1.0);
		distance_to_edge = min(distance_to_edge, length(local_position - a - along * edge));
	}
	float t = clamp(distance_to_edge / curve_width, 0.0, 1.0);
	// Derivatives give screen-space orientation, so lighting stays fixed while dragging/rotating.
	// Blend adjacent closest-edge normals only within a small corner radius.
	// This rounds the distance-field medial crease, not the artwork or silhouette.
	vec2 local_gradient = vec2(0.0);
	float total_weight = 0.0;
	float corner_radius = curve_width * 0.24;
	for (int i = 0; i < outline_count; i++) {
		vec2 a = outline[i];
		vec2 edge = outline[(i + 1) % outline_count] - a;
		float along = clamp(dot(local_position - a, edge) / max(dot(edge, edge), 0.00001), 0.0, 1.0);
		vec2 delta = local_position - a - along * edge;
		float d = length(delta);
		float weight = exp(-(d - distance_to_edge) / corner_radius);
		local_gradient += delta / max(d, 0.00001) * weight;
		total_weight += weight;
	}
	local_gradient /= max(total_weight, 0.00001);
	vec2 gradient = vec2(dot(local_gradient, dFdx(local_position)), dot(local_gradient, dFdy(local_position)));
	vec2 inward = gradient / max(length(gradient), 0.00001) * length(local_gradient);
	float slope = 2.0 * depth_ratio * (1.0 - t);
	vec3 normal = normalize(vec3(-inward * slope, 1.0));
	vec3 light_direction = normalize(vec3(-0.55, -0.70, 1.0));
	float diffuse = max(dot(normal, light_direction), 0.0);
	float illumination = (0.55 + 0.45 * diffuse) / (0.55 + 0.45 * light_direction.z);
	// Diffuse only: no gloss, noise, blur, UV displacement, or opacity modification.
	COLOR = vec4(original.rgb * illumination, original.a);
}
