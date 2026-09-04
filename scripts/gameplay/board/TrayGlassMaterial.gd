extends RefCounted
class_name TrayGlassMaterial

## A warm, quiet frosted material that suppresses tabletop detail without
## making the tray feel like an opaque panel.
const BLUR_RADIUS_PIXELS := 14.0
const BACK_BUFFER_MARGIN_PIXELS := 20.0
const BACKGROUND_SATURATION := 0.50
const GLASS_TINT := Color(0.96, 0.86, 0.68, 0.46)


static func create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius_pixels = 14.0;
uniform float background_saturation = 0.50;
uniform vec4 glass_tint : source_color = vec4(0.96, 0.86, 0.68, 0.46);

void fragment() {
	vec2 offset = SCREEN_PIXEL_SIZE * blur_radius_pixels;
	vec3 background = texture(screen_texture, SCREEN_UV).rgb * 0.20;
	background += texture(screen_texture, clamp(SCREEN_UV + vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.12;
	background += texture(screen_texture, clamp(SCREEN_UV - vec2(offset.x, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.12;
	background += texture(screen_texture, clamp(SCREEN_UV + vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).rgb * 0.12;
	background += texture(screen_texture, clamp(SCREEN_UV - vec2(0.0, offset.y), vec2(0.0), vec2(1.0))).rgb * 0.12;
	background += texture(screen_texture, clamp(SCREEN_UV + offset, vec2(0.0), vec2(1.0))).rgb * 0.08;
	background += texture(screen_texture, clamp(SCREEN_UV - offset, vec2(0.0), vec2(1.0))).rgb * 0.08;
	background += texture(screen_texture, clamp(SCREEN_UV + vec2(offset.x, -offset.y), vec2(0.0), vec2(1.0))).rgb * 0.08;
	background += texture(screen_texture, clamp(SCREEN_UV + vec2(-offset.x, offset.y), vec2(0.0), vec2(1.0))).rgb * 0.08;
	float luminance = dot(background, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted_background = mix(vec3(luminance), background, background_saturation);
	vec3 frosted_color = mix(muted_background, glass_tint.rgb, glass_tint.a);
	COLOR = vec4(frosted_color, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blur_radius_pixels", BLUR_RADIUS_PIXELS)
	material.set_shader_parameter("background_saturation", BACKGROUND_SATURATION)
	material.set_shader_parameter("glass_tint", GLASS_TINT)
	return material
