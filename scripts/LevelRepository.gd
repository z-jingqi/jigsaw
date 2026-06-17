extends RefCounted
class_name LevelRepository

const LEVEL_CATALOG_PATH := "res://levels/catalog.json"

var texture_cache: Dictionary = {}
var thumbnail_cache: Dictionary = {}
var source_image_cache: Dictionary = {}
var config_cache: Dictionary = {}
var locale := "en"


func set_locale(next_locale: String) -> void:
	locale = normalize_locale(next_locale)


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
			var groups: Array[Dictionary] = []
			var flat_levels: Array[Dictionary] = []
			var catalog_groups: Array = topic.get("groups", [])
			if catalog_groups.is_empty() and topic.has("levels"):
				catalog_groups = [{"id": "default", "name": "Default", "sort_order": 0, "levels": topic.get("levels", [])}]
			catalog_groups.sort_custom(func(a, b) -> bool:
				return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
			)
			for group_data in catalog_groups:
				if typeof(group_data) != TYPE_DICTIONARY:
					continue
				var group: Dictionary = group_data
				var levels: Array[Dictionary] = []
				var catalog_levels: Array = group.get("levels", [])
				catalog_levels.sort_custom(func(a, b) -> bool:
					return _catalog_level_sort_order(a) < _catalog_level_sort_order(b)
				)
				for level_data in catalog_levels:
					var level_entry := _catalog_level_entry(level_data)
					if level_entry.is_empty():
						continue
					var config_path := str(level_entry.get("path", levelResPath(str(topic.get("id", "")), str(group.get("id", "")), str(level_entry.get("id", "")))))
					var level_config := load_config_path(config_path)
					var level := {
						"id": str(level_entry.get("id", level_config.get("id", ""))),
						"title": localized_config_string(level_config, "title", str(level_entry.get("title", "")), level_entry),
						"description": localized_config_string(level_config, "description", "", level_entry),
						"config_path": config_path,
						"group_id": str(group.get("id", "")),
						"group_name": localized_named(group, str(group.get("name", group.get("id", "")))),
					}
					levels.append(level)
					flat_levels.append(level)
				groups.append({
					"id": str(group.get("id", "")),
					"name": localized_named(group, str(group.get("name", group.get("id", "")))),
					"levels": levels,
				})
			next_topics.append({
				"id": str(topic.get("id", "")),
				"name": localized_named(topic, str(topic.get("name", topic.get("id", "")))),
				"cover": str(topic.get("cover", "")),
				"groups": groups,
				"levels": flat_levels,
			})
		return next_topics
	return []


func _catalog_level_entry(level_data) -> Dictionary:
	if typeof(level_data) == TYPE_STRING:
		var path := str(level_data)
		return {
			"id": path.get_base_dir().get_file(),
			"path": path,
			"sort_order": 0,
		}
	if typeof(level_data) == TYPE_DICTIONARY:
		return level_data
	return {}


func _catalog_level_sort_order(level_data) -> int:
	if typeof(level_data) == TYPE_DICTIONARY:
		return int(level_data.get("sort_order", 0))
	return 0


func levelResPath(topic_id: String, group_id: String, level_id: String) -> String:
	return "res://levels/%s/%s/%s/level.json" % [topic_id, group_id, level_id]


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


func level_thumbnail(level: Dictionary, target_size := Vector2i(260, 260)) -> Texture2D:
	var level_config := load_level_config(level)
	var image_path := level_thumbnail_source_path(level_config)
	return cached_runtime_thumbnail(image_path, target_size)


func topic_cover_texture(topic: Dictionary) -> Texture2D:
	var cover_path := str(topic.get("cover", ""))
	return cached_texture(cover_path) if not cover_path.is_empty() else null


func apply_level_media(level_config: Dictionary) -> Dictionary:
	var image_path := level_image_path(level_config)
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
	var extension := path.get_extension().to_lower()
	if ["png", "jpg", "jpeg", "webp"].has(extension):
		var file_path := image_file_path(path)
		var image := Image.load_from_file(file_path)
		if image != null and not image.is_empty():
			var image_texture := ImageTexture.create_from_image(image)
			texture_cache[path] = image_texture
			return image_texture
	var loaded: Texture2D = load(path)
	if loaded != null:
		texture_cache[path] = loaded
		return loaded
	var file_path := image_file_path(path)
	var image := Image.load_from_file(file_path)
	if image != null and not image.is_empty():
		var image_texture := ImageTexture.create_from_image(image)
		texture_cache[path] = image_texture
		return image_texture
	return null


func cached_runtime_thumbnail(path: String, target_size: Vector2i) -> Texture2D:
	if path.is_empty() or target_size.x <= 0 or target_size.y <= 0:
		return null
	var key := "%s@%dx%d" % [path, target_size.x, target_size.y]
	if thumbnail_cache.has(key):
		return thumbnail_cache[key]
	var image: Image = Image.load_from_file(image_file_path(path))
	if image == null or image.is_empty():
		return null
	var ratio: float = minf(float(target_size.x) / float(image.get_width()), float(target_size.y) / float(image.get_height()))
	var width: int = max(1, int(round(float(image.get_width()) * ratio)))
	var height: int = max(1, int(round(float(image.get_height()) * ratio)))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	thumbnail_cache[key] = texture
	return texture


func has_runtime_thumbnail(path: String, target_size: Vector2i) -> bool:
	return thumbnail_cache.has("%s@%dx%d" % [path, target_size.x, target_size.y])


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


func level_list_image_path(level_config: Dictionary) -> String:
	return default_level_image_path(level_config)


func level_thumbnail_source_path(level_config: Dictionary) -> String:
	return level_list_image_path(level_config)


func level_image_path(level_config: Dictionary) -> String:
	return default_level_image_path(level_config)


func default_level_image_path(level_config: Dictionary) -> String:
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


func localized_config_string(config: Dictionary, key: String, fallback: String, entry := {}) -> String:
	var i18n_key := "%s_i18n" % key
	if config.has(i18n_key) and typeof(config[i18n_key]) == TYPE_DICTIONARY:
		return localized_value(config[i18n_key], config_string(config, key, fallback))
	if typeof(entry) == TYPE_DICTIONARY and entry.has(i18n_key) and typeof(entry[i18n_key]) == TYPE_DICTIONARY:
		return localized_value(entry[i18n_key], str(entry.get(key, fallback)))
	return config_string(config, key, fallback)


func localized_named(data: Dictionary, fallback: String) -> String:
	if data.has("name_i18n") and typeof(data["name_i18n"]) == TYPE_DICTIONARY:
		return localized_value(data["name_i18n"], fallback)
	return fallback


func localized_value(values: Dictionary, fallback: String) -> String:
	var key := normalize_locale(locale)
	for candidate in [key, "en", "en-US", "en_US", "zh", "zh-Hans", "zh-cn", "zh_CN", "ja", "ja-JP", "_"]:
		if values.has(candidate) and not str(values[candidate]).is_empty():
			return str(values[candidate])
	return fallback


func normalize_locale(value: String) -> String:
	var lower := value.replace("_", "-").to_lower()
	if lower.begins_with("zh"):
		return "zh"
	if lower.begins_with("ja"):
		return "ja"
	return "en"


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
