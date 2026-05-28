extends RefCounted
class_name LevelRepository

const LEVEL_CATALOG_PATH := "res://levels/catalog.json"

var texture_cache: Dictionary = {}
var source_image_cache: Dictionary = {}
var config_cache: Dictionary = {}


func build_catalog() -> Array[Dictionary]:
	var catalog := load_config_path(LEVEL_CATALOG_PATH)
	if catalog.has("topics") and typeof(catalog["topics"]) == TYPE_ARRAY:
		var next_topics: Array[Dictionary] = []
		var catalog_topics: Array = catalog["topics"]
		catalog_topics.sort_custom(func(a, b) -> bool:
			return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
		)
		for topic_data in catalog_topics:
			if typeof(topic_data) != TYPE_DICTIONARY:
				continue
			var topic: Dictionary = topic_data
			var levels: Array[Dictionary] = []
			var catalog_levels: Array = topic.get("levels", [])
			catalog_levels.sort_custom(func(a, b) -> bool:
				return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
			)
			for level_data in catalog_levels:
				if typeof(level_data) != TYPE_DICTIONARY:
					continue
				var level_entry: Dictionary = level_data
				var config_path := str(level_entry.get("path", ""))
				var level_config := load_config_path(config_path)
				levels.append({
					"id": str(level_entry.get("id", level_config.get("id", ""))),
					"title": config_string(level_config, "title", str(level_entry.get("title", ""))),
					"description": config_string(level_config, "description", ""),
					"config_path": config_path,
				})
			next_topics.append({
				"id": str(topic.get("id", "")),
				"name": str(topic.get("name", topic.get("id", ""))),
				"cover": str(topic.get("cover", "")),
				"levels": levels,
			})
		return next_topics
	return []


func load_level_config(level: Dictionary) -> Dictionary:
	return load_config_path(str(level.get("config_path", "")))


func load_config_path(config_path: String) -> Dictionary:
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return {}
	if config_cache.has(config_path):
		return config_cache[config_path]
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	var config: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if not config.is_empty():
		config_cache[config_path] = config
	return config


func level_thumbnail(level: Dictionary) -> Texture2D:
	var level_config := load_level_config(level)
	var image_path := level_list_image_path(level_config)
	return cached_texture(image_path) if not image_path.is_empty() else null


func topic_cover_texture(topic: Dictionary) -> Texture2D:
	var cover_path := str(topic.get("cover", ""))
	return cached_texture(cover_path) if not cover_path.is_empty() else null


func apply_level_media(level_config: Dictionary, mode: String) -> Dictionary:
	var image_path := level_image_path(level_config, mode)
	var next_texture := cached_texture(image_path) if not image_path.is_empty() else null
	if next_texture == null:
		var fallback_path := default_level_image_path(level_config)
		if not fallback_path.is_empty() and fallback_path != image_path:
			image_path = fallback_path
			next_texture = cached_texture(image_path)
	if next_texture == null:
		image_path = ""
		next_texture = placeholder_texture()
	var image := cached_source_image(image_path, next_texture)
	return {
		"texture": next_texture,
		"image": image,
		"source_size": Vector2(next_texture.get_width(), next_texture.get_height()),
	}


func cached_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var loaded: Texture2D = load(path)
	if loaded != null:
		texture_cache[path] = loaded
		return loaded
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty():
		var image_texture := ImageTexture.create_from_image(image)
		texture_cache[path] = image_texture
		return image_texture
	return null


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


func level_list_image_path(level_config: Dictionary) -> String:
	var swap_path := image_path_from_value(mode_config(level_config, "swap").get("image", null), "")
	if not swap_path.is_empty():
		return swap_path
	var knob_path := image_path_from_value(mode_config(level_config, "knob").get("image", null), "")
	if not knob_path.is_empty():
		return knob_path
	var polygon_path := image_path_from_value(mode_config(level_config, "polygon").get("image", null), "")
	if not polygon_path.is_empty():
		return polygon_path
	return ""


func level_image_path(level_config: Dictionary, mode := "") -> String:
	for candidate_mode in [mode, "swap", "knob", "polygon"]:
		if str(candidate_mode).is_empty():
			continue
		var mode_data := mode_config(level_config, str(candidate_mode))
		var mode_image_path := image_path_from_value(mode_data.get("image", null), "")
		if not mode_image_path.is_empty():
			return mode_image_path
	return default_level_image_path(level_config)


func default_level_image_path(level_config: Dictionary) -> String:
	if level_config.has("assets") and typeof(level_config["assets"]) == TYPE_DICTIONARY:
		var assets: Dictionary = level_config["assets"]
		var default_image_path := image_path_from_value(assets.get("default_image", null), "")
		if not default_image_path.is_empty():
			return default_image_path
	return image_path_from_value(level_config.get("image", null), "")


func image_path_from_value(value, fallback: String) -> String:
	if typeof(value) == TYPE_STRING:
		return str(value)
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("path", fallback))
	return fallback


func config_string(config: Dictionary, key: String, fallback: String) -> String:
	if config.has(key):
		return str(config[key])
	if config.has("metadata") and typeof(config["metadata"]) == TYPE_DICTIONARY:
		return str(config["metadata"].get(key, fallback))
	return fallback


func mode_config(level_config: Dictionary, play_mode: String) -> Dictionary:
	var mode := mode_key(play_mode)
	if not level_config.has("modes") or typeof(level_config["modes"]) != TYPE_DICTIONARY:
		return {}
	var modes: Dictionary = level_config["modes"]
	if not modes.has(mode) or typeof(modes[mode]) != TYPE_DICTIONARY:
		return {}
	return modes[mode]


func mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode
