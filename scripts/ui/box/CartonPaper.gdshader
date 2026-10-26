shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 paper_color : source_color = vec4(1.0);
varying vec3 paper_position;
void vertex() { paper_position = VERTEX; }
void fragment() {
    float fiber = fract(sin(dot(floor(paper_position * vec3(650.0, 300.0, 650.0)), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    ALBEDO = paper_color.rgb * (0.975 + 0.05 * fiber);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
