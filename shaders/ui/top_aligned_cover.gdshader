shader_type canvas_item;

uniform float rect_aspect = 1.0;
uniform float texture_aspect = 1.0;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


void fragment() {
	vec2 sample_uv = UV;
	if (texture_aspect > rect_aspect) {
		float visible_width = rect_aspect / texture_aspect;
		sample_uv.x = (UV.x - 0.5) * visible_width + 0.5;
	} else {
		float visible_height = texture_aspect / rect_aspect;
		sample_uv.y = UV.y * visible_height;
	}
	COLOR = texture(TEXTURE, sample_uv) * vertex_modulate;
}
