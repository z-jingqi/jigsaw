shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 ink : source_color = vec4(1.0);
// The carrier is wider than the actual print so subpixel top-face lines can
// integrate coverage rather than intermittently disappear during rasterization.
uniform float relative_width = 0.125;
void fragment() {
    float distance_to_line = abs(UV.y - 0.5);
    float footprint = max(fwidth(UV.y), 0.0001);
    float lo = max(distance_to_line - footprint * 0.5, -relative_width * 0.5);
    float hi = min(distance_to_line + footprint * 0.5, relative_width * 0.5);
    float coverage = clamp((hi - lo) / footprint, 0.0, 1.0);
    ALBEDO = ink.rgb;
    ALPHA = coverage * ink.a;
}
