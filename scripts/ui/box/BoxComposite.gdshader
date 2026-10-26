shader_type canvas_item;
render_mode blend_premul_alpha;
// Transparent 3D viewport resolves contain premultiplied edge coverage.
// Compositing as straight alpha multiplies those edge pixels twice (dark dashes).
varying vec4 canvas_tint;
void vertex() { canvas_tint = COLOR; }
void fragment() {
    vec4 resolved = texture(TEXTURE, UV);
    COLOR = vec4(resolved.rgb * canvas_tint.rgb * canvas_tint.a, resolved.a * canvas_tint.a);
}
