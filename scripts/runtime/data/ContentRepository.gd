class_name ContentRepository
extends RefCounted

const LevelRepositoryScript := preload("res://scripts/catalog/LevelRepository.gd")
const ModeAvailability := preload("res://scripts/catalog/LevelModeAvailability.gd")

var _repository: Variant


func _init(repository: Variant = null) -> void:
	_repository = repository if repository != null else LevelRepositoryScript.new()


func topics() -> Array[Dictionary]:
	return _repository.build_catalog()


func topic_by_id(topic_id: String) -> Dictionary:
	for topic in topics():
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func level_by_id(topic_id: String, level_id: String) -> Dictionary:
	var topic := topic_by_id(topic_id)
	for level in topic.get("levels", []):
		if typeof(level) == TYPE_DICTIONARY and str(level.get("id", "")) == level_id:
			return level
	return {}


func available_modes(level: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if level.has("available_modes"):
		result.assign(level.available_modes)
		return result
	return ModeAvailability.from_config(_repository, _repository.load_level_config(level))


func topic_cover(topic: Dictionary) -> Texture2D:
	return _repository.topic_cover_texture(topic)


func topic_background(topic: Dictionary) -> Texture2D:
	return _repository.topic_background_texture(topic)


func level_thumbnail(level: Dictionary) -> Texture2D:
	return _repository.level_thumbnail(level)


func level_thumbnail_path(level: Dictionary) -> String:
	if level.has("thumbnail_path"):
		return str(level.thumbnail_path)
	var config: Dictionary = _repository.load_level_config(level)
	return _repository.level_thumbnail_source_path(config)


func stable_piece_ids(level: Dictionary, mode: String) -> Array[String]:
	var config: Dictionary = _repository.load_level_config(level)
	var mode_data: Dictionary = _repository.mode_config(config, mode)
	var result: Array[String] = []
	if mode == "swap":
		var total := maxi(0, int(mode_data.get("cols", 0))) * maxi(0, int(mode_data.get("rows", 0)))
		for index in total:
			result.append("swap_tile_%02d" % index)
		return result
	if mode == "knob":
		for row in maxi(0, int(mode_data.get("rows", 0))):
			for column in maxi(0, int(mode_data.get("cols", 0))):
				result.append("knob_%d_%d" % [row, column])
		return result
	for piece_data in mode_data.get("pieces", []):
		if typeof(piece_data) == TYPE_DICTIONARY:
			result.append(str(piece_data.get("id", "")))
	result = result.filter(func(piece_id: String) -> bool: return not piece_id.is_empty())
	return result


func level_config(level: Dictionary) -> Dictionary:
	return _repository.load_level_config(level)


func level_media(level_config: Dictionary) -> Dictionary:
	return _repository.apply_level_media(level_config)


func level_preview_texture(level_config: Dictionary) -> Texture2D:
	return _repository.level_preview_texture(level_config)


func level_image_path(level_config: Dictionary) -> String:
	return _repository.level_image_path(level_config)


func config_with_theme_background(level_config: Dictionary, topic: Dictionary) -> Dictionary:
	var result := level_config.duplicate(true)
	var background_path := str(topic.get("level_background", ""))
	if background_path.is_empty():
		return result
	var palette_value: Variant = topic.get("ui_palette", {})
	var palette: Dictionary = palette_value if typeof(palette_value) == TYPE_DICTIONARY else {}
	result["_topic_ui_palette"] = palette.duplicate(true)
	result["background"] = {
		"type": "image",
		"path": background_path,
		"color": str(palette.get("surface", "#F5F0E3")),
	}
	return result
