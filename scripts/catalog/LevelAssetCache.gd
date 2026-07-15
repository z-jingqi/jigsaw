extends RefCounted
class_name LevelAssetCache

var texture_cache: Dictionary = {}
var source_image_cache: Dictionary = {}


func cached_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var extension := path.get_extension().to_lower()
	if ["png", "jpg", "jpeg", "webp"].has(extension):
		var direct_image := Image.load_from_file(image_file_path(path))
		if direct_image != null and not direct_image.is_empty():
			var direct_texture := ImageTexture.create_from_image(direct_image)
			texture_cache[path] = direct_texture
			return direct_texture
	var loaded: Texture2D = load(path)
	if loaded != null:
		texture_cache[path] = loaded
		return loaded
	var fallback_image := Image.load_from_file(image_file_path(path))
	if fallback_image != null and not fallback_image.is_empty():
		var fallback_texture := ImageTexture.create_from_image(fallback_image)
		texture_cache[path] = fallback_texture
		return fallback_texture
	return null


func runtime_thumbnail(path: String, target_size: Vector2i) -> Texture2D:
	if path.is_empty() or target_size.x <= 0 or target_size.y <= 0:
		return null
	var source_texture: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		source_texture = load(path) as Texture2D
	if source_texture != null and source_texture.get_width() <= target_size.x and source_texture.get_height() <= target_size.y:
		return source_texture
	var image: Image = source_texture.get_image() if source_texture != null else Image.load_from_file(image_file_path(path))
	if image == null or image.is_empty():
		return null
	var ratio: float = minf(
		1.0,
		minf(float(target_size.x) / float(image.get_width()), float(target_size.y) / float(image.get_height()))
	)
	var width: int = max(1, int(round(float(image.get_width()) * ratio)))
	var height: int = max(1, int(round(float(image.get_height()) * ratio)))
	if image.get_width() != width or image.get_height() != height:
		image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func image_file_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func placeholder_texture() -> Texture2D:
	var image := Image.create(640, 640, false, Image.FORMAT_RGBA8)
	image.fill(Color("#F6EBD4"))
	return ImageTexture.create_from_image(image)


func cached_source_image(path: String, source_texture: Texture2D) -> Image:
	if not path.is_empty() and source_image_cache.has(path):
		return source_image_cache[path]
	var image := source_texture.get_image()
	if not path.is_empty():
		source_image_cache[path] = image
	return image
