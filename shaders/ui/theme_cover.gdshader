shader_type canvas_item;
uniform float aspect = 0.666667;
uniform float texture_aspect = 0.666667;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec2 uv = UV;
 if (texture_aspect > aspect) { uv.x = (uv.x - 0.5) * aspect / texture_aspect + 0.5; }
 else { uv.y = (uv.y - 0.5) * texture_aspect / aspect + 0.5; }
 vec2 p = abs((UV - 0.5) * vec2(aspect, 1.0)) - vec2(aspect * 0.5 - 0.02, 0.48);
 float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 0.02;
 float alpha = 1.0 - smoothstep(-0.001, 0.001, d);
 COLOR = tint * texture(TEXTURE, uv) * vec4(1.0, 1.0, 1.0, alpha);
}
