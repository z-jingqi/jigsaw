shader_type canvas_item;

uniform bool not_started = false;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (not_started) {
		// Soften unplayed glyphs while retaining the shared green palette.
		source.rgb = mix(source.rgb, vec3(0.71, 0.76, 0.65), 0.42);
	}
	COLOR = source * item_tint;
}
