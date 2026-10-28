shader_type canvas_item;
// Both live and cached boxes use the uncropped viewport silhouette, whose
// transparent padding leaves room for a short, down-right shadow.
uniform vec4 shadow_color : source_color = vec4(0.24, 0.21, 0.18, 0.16);
uniform vec2 shadow_offset = vec2(0.010, 0.012);
uniform vec2 softness = vec2(0.018, 0.0135);
varying vec4 shadow_tint;

void vertex() { shadow_tint = COLOR; }

float coverage(sampler2D silhouette, vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        return 0.0;
    }
    return texture(silhouette, uv).a;
}

void fragment() {
    vec2 uv = UV - shadow_offset;
    float mask = 0.0;
    float total = 0.0;
    // Gaussian-weighted disk taps avoid the visible parallel bands of a sparse
    // square kernel, especially along the long straight bottom of the carton.
    for (int i = 0; i < 25; i++) {
        float radius = sqrt((float(i) + 0.5) / 25.0);
        float angle = float(i) * 2.39996323;
        float weight = exp(-3.0 * radius * radius);
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * softness * 2.0;
        mask += coverage(TEXTURE, uv + offset) * weight;
        total += weight;
    }
    COLOR = vec4(shadow_color.rgb, shadow_color.a * mask / total) * shadow_tint;
}
