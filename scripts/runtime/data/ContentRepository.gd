class_name ContentRepository
extends RefCounted

const LevelRepositoryScript := preload("res://scripts/catalog/LevelRepository.gd")

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
	var config: Dictionary = _repository.load_level_config(level)
	var result: Array[String] = []
	for mode in ["polygon", "knob", "swap"]:
		if _has_mode_data(config, mode):
			result.append(mode)
	return result


func topic_cover(topic: Dictionary) -> Texture2D:
	return _repository.topic_cover_texture(topic)


func level_thumbnail(level: Dictionary) -> Texture2D:
	return _repository.level_thumbnail(level)


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


func _has_mode_data(config: Dictionary, mode: String) -> bool:
	if mode == "swap":
		return not _repository.level_image_path(config).is_empty()
	var mode_data: Dictionary = _repository.mode_config(config, mode)
	if mode == "knob":
		return not mode_data.is_empty() and not _repository.level_image_path(config).is_empty()
	return typeof(mode_data.get("pieces", [])) == TYPE_ARRAY and not (mode_data.get("pieces", []) as Array).is_empty()
