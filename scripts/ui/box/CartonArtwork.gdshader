shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 0.16;
uniform float opacity : hint_range(0.0, 1.0) = 0.56;
void fragment() {
    vec3 color = texture(artwork, UV).rgb;
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, saturation);
    ALBEDO = mix(vec3(1.0), color, opacity);
}
