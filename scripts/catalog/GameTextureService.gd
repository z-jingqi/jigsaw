extends RefCounted
class_name GameTextureService

const ROUNDED_TEXTURE_SHADER_CODE := """
shader_type canvas_item;

uniform vec2 rect_size = vec2(1.0);
uniform float corner_radius = 0.0;

void fragment() {
	vec4 color = COLOR;
	vec2 half_size = rect_size * 0.5;
	vec2 point = abs(UV * rect_size - half_size) - (half_size - vec2(corner_radius));
	float distance_to_edge = length(max(point, vec2(0.0))) + min(max(point.x, point.y), 0.0) - corner_radius;
	float edge_alpha = 1.0 - smoothstep(-1.0, 1.0, distance_to_edge);
	color.a *= edge_alpha;
	COLOR = color;
}
"""
const ICON_TINT_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 icon_color : source_color = vec4(1.0);

void fragment() {
	COLOR = vec4(icon_color.rgb, COLOR.a * icon_color.a);
}
"""

var repository
var left_rounded_topic_cover_cache: Dictionary = {}
var rounded_complete_image_cache: Dictionary = {}
var rounded_texture_shader: Shader
var icon_tint_shader: Shader


func _init(level_repository) -> void:
	repository = level_repository


func left_rounded_topic_cover_texture(topic: Dictionary, target_size: Vector2i, radius: int) -> Texture2D:
	var cache_key := "%s@%dx%d@%d" % [str(topic.get("id", "")), target_size.x, target_size.y, radius]
	if left_rounded_topic_cover_cache.has(cache_key):
		return left_rounded_topic_cover_cache[cache_key]
	var source_texture: Texture2D = repository.topic_cover_texture(topic)
	if source_texture == null or target_size.x <= 0 or target_size.y <= 0:
		return source_texture
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var scale_factor := maxf(
		float(target_size.x) / float(image.get_width()),
		float(target_size.y) / float(image.get_height())
	)
	image.resize(
		maxi(target_size.x, int(ceil(float(image.get_width()) * scale_factor))),
		maxi(target_size.y, int(ceil(float(image.get_height()) * scale_factor))),
		Image.INTERPOLATE_LANCZOS
	)
	var offset := Vector2i(
		maxi(0, (image.get_width() - target_size.x) / 2),
		maxi(0, (image.get_height() - target_size.y) / 2)
	)
	image = image.get_region(Rect2i(offset, target_size))
	image.convert(Image.FORMAT_RGBA8)
	apply_left_rounded_image_alpha(image, mini(radius, mini(target_size.x, target_size.y) / 2))
	var result := ImageTexture.create_from_image(image)
	left_rounded_topic_cover_cache[cache_key] = result
	return result


func rounded_texture_material(target_size: Vector2, radius: float) -> ShaderMaterial:
	if rounded_texture_shader == null:
		rounded_texture_shader = Shader.new()
		rounded_texture_shader.code = ROUNDED_TEXTURE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = rounded_texture_shader
	material.set_shader_parameter("rect_size", target_size)
	material.set_shader_parameter("corner_radius", radius)
	return material


func icon_tint_material(color: Color) -> ShaderMaterial:
	if icon_tint_shader == null:
		icon_tint_shader = Shader.new()
		icon_tint_shader.code = ICON_TINT_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = icon_tint_shader
	material.set_shader_parameter("icon_color", color)
	return material


func rounded_complete_image_texture(image_path: String, target_size: Vector2i, radius: int) -> Texture2D:
	var cache_key := "%s@%dx%d@%d" % [image_path, target_size.x, target_size.y, radius]
	if rounded_complete_image_cache.has(cache_key):
		return rounded_complete_image_cache[cache_key]
	var source_texture: Texture2D = repository.cached_texture(image_path)
	if source_texture == null or target_size.x <= 0 or target_size.y <= 0:
		return source_texture
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var scale_factor := minf(
		float(target_size.x) / float(image.get_width()),
		float(target_size.y) / float(image.get_height())
	)
	var width := maxi(1, int(round(float(image.get_width()) * scale_factor)))
	var height := maxi(1, int(round(float(image.get_height()) * scale_factor)))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("#FFF6E6"))
	var offset := Vector2i((target_size.x - width) / 2, (target_size.y - height) / 2)
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(width, height)), offset)
	apply_rounded_image_alpha(canvas, mini(radius, mini(target_size.x, target_size.y) / 2))
	var result := ImageTexture.create_from_image(canvas)
	rounded_complete_image_cache[cache_key] = result
	return result


func apply_rounded_image_alpha(image: Image, radius: int) -> void:
	if radius <= 0:
		return
	var width := image.get_width()
	var height := image.get_height()
	var corner_center := Vector2(radius, radius)
	for y in height:
		for x in width:
			var edge_x := minf(float(x) + 0.5, float(width - x) - 0.5)
			var edge_y := minf(float(y) + 0.5, float(height - y) - 0.5)
			if edge_x >= radius or edge_y >= radius:
				continue
			var coverage := clampf(float(radius) + 0.5 - Vector2(edge_x, edge_y).distance_to(corner_center), 0.0, 1.0)
			if coverage >= 1.0:
				continue
			var color := image.get_pixel(x, y)
			color.a *= coverage
			image.set_pixel(x, y, color)


func apply_left_rounded_image_alpha(image: Image, radius: int) -> void:
	if radius <= 0:
		return
	var width := image.get_width()
	var height := image.get_height()
	var corner_center := Vector2(radius, radius)
	for y in height:
		var edge_y := minf(float(y) + 0.5, float(height - y) - 0.5)
		if edge_y >= radius:
			continue
		for x in mini(radius, width):
			var edge_x := float(x) + 0.5
			var coverage := clampf(float(radius) + 0.5 - Vector2(edge_x, edge_y).distance_to(corner_center), 0.0, 1.0)
			if coverage >= 1.0:
				continue
			var color := image.get_pixel(x, y)
			color.a *= coverage
			image.set_pixel(x, y, color)
