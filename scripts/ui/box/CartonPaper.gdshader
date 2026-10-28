shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 paper_color : source_color = vec4(1.0);
uniform bool front_panel = false;
varying vec3 paper_position;
void vertex() { paper_position = VERTEX; }
void fragment() {
    vec3 grain_cell = floor(paper_position * vec3(420.0, 180.0, 420.0));
    float fiber = fract(sin(dot(grain_cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453) - 0.5;
    // Suppress subpixel fibers in shelf thumbnails, retain them on the live box.
    float footprint = length(fwidth(paper_position) * vec3(420.0, 180.0, 420.0));
    float grain = fiber * 0.035 / max(1.0, footprint);
    float relief = 0.0;
    if (front_panel) {
        float aa = max(fwidth(paper_position.x), fwidth(paper_position.y));
        float light_edge = min(paper_position.x + 1.125, 3.0 - paper_position.y);
        float dark_edge = min(1.125 - paper_position.x, paper_position.y);
        relief += (1.0 - smoothstep(0.0, 0.012 + aa, light_edge)) * 0.035;
        relief -= (1.0 - smoothstep(0.0, 0.014 + aa, dark_edge)) * 0.10;
    }
    ALBEDO = paper_color.rgb * (0.93 + grain + relief);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
