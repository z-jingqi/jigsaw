shader_type canvas_item;

uniform bool not_started = false;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (not_started) {
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 sage = mix(vec3(0.39, 0.47, 0.42), vec3(0.70, 0.75, 0.68), luminance);
		// Keep the existing ivory sticker edge instead of tinting it green.
		float ivory = smoothstep(0.82, 0.95, luminance);
		source.rgb = mix(sage, source.rgb, ivory);
	}
	COLOR = source * item_tint;
}
