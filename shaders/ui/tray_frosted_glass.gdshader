shader_type canvas_item;
render_mode unshaded;

// Sample the same background texture used by TabletopPresentation. Compatibility
// does not reliably expose pixels from a different CanvasLayer via screen texture.
uniform sampler2D background_texture : source_color, repeat_disable, filter_linear;
uniform vec4 tint_color : source_color = vec4(0.886, 0.910, 0.859, 0.82);
uniform float blur_radius : hint_range(1.0, 12.0, 0.5) = 5.0;
uniform float viewport_aspect = 1.0;
uniform float texture_aspect = 1.0;
uniform bool top_aligned = false;

vec2 background_uv(vec2 screen_uv) {
	vec2 sample_uv = screen_uv;
	if (texture_aspect > viewport_aspect) {
		float visible_width = viewport_aspect / texture_aspect;
		sample_uv.x = (screen_uv.x - 0.5) * visible_width + 0.5;
	} else {
		float visible_height = texture_aspect / viewport_aspect;
		sample_uv.y = top_aligned
			? screen_uv.y * visible_height
			: (screen_uv.y - 0.5) * visible_height + 0.5;
	}
	return clamp(sample_uv, vec2(0.0), vec2(1.0));
}

vec3 background_sample(vec2 screen_uv) {
	return texture(background_texture, background_uv(screen_uv)).rgb;
}

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 backdrop = background_sample(SCREEN_UV) * 0.20;
	backdrop += background_sample(SCREEN_UV + vec2(step_size.x, 0.0)) * 0.12;
	backdrop += background_sample(SCREEN_UV - vec2(step_size.x, 0.0)) * 0.12;
	backdrop += background_sample(SCREEN_UV + vec2(0.0, step_size.y)) * 0.12;
	backdrop += background_sample(SCREEN_UV - vec2(0.0, step_size.y)) * 0.12;
	backdrop += background_sample(SCREEN_UV + step_size) * 0.08;
	backdrop += background_sample(SCREEN_UV - step_size) * 0.08;
	backdrop += background_sample(SCREEN_UV + vec2(step_size.x, -step_size.y)) * 0.08;
	backdrop += background_sample(SCREEN_UV + vec2(-step_size.x, step_size.y)) * 0.08;
	COLOR = vec4(mix(backdrop, tint_color.rgb, tint_color.a), 1.0);
}
