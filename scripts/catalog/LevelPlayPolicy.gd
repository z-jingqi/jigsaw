extends RefCounted
class_name LevelPlayPolicy

const PLAY_MODES := ["polygon", "knob", "swap"]
const BoardSessionIdentityScript := preload("res://scripts/gameplay/runtime/BoardSessionIdentity.gd")

var repository
var progress_store
var session_repository


func _init(level_repository, player_progress, player_session) -> void:
	repository = level_repository
	progress_store = player_progress
	session_repository = player_session


func level_list_focus_level_id(topic: Dictionary) -> String:
	var current: Dictionary = session_repository.current()
	var current_level: Dictionary = progress_store.level_by_id(topic, str(current.get("level_id", ""))) if str(current.get("theme_id", "")) == str(topic.get("id", "")) else {}
	if not current_level.is_empty():
		var current_modes := available_modes_for_level(current_level)
		if (
			level_has_unfinished_available_mode(current_level, current_modes)
			and _level_has_session_progress(topic, current_level, current_modes)
		):
			return str(current_level.get("id", ""))
	for level in topic.get("levels", []):
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var available_modes := available_modes_for_level(level)
		if level_has_unfinished_available_mode(level, available_modes):
			return str(level.get("id", ""))
	var levels: Array = topic.get("levels", [])
	return str(levels[0].get("id", "")) if not levels.is_empty() and typeof(levels[0]) == TYPE_DICTIONARY else ""


func level_has_unfinished_available_mode(level: Dictionary, available_modes: Array[String]) -> bool:
	var level_id := str(level.get("id", ""))
	for play_mode in available_modes:
		if not progress_store.is_done(level_id, play_mode):
			return true
	return false


func compute_level_locks(topic: Dictionary) -> Dictionary:
	var unlocked := {}
	var budget := 1
	for level in topic.get("levels", []):
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var level_id := str(level.get("id", ""))
		if budget > 0:
			unlocked[level_id] = true
			budget -= 1
			if not progress_store.completed_modes(level_id).is_empty():
				budget += maxi(1, int(level.get("unlock_grant", 1)))
		else:
			unlocked[level_id] = false
	return unlocked


func level_mode_state(topic: Dictionary, level: Dictionary, play_mode: String) -> String:
	if progress_store.is_done(str(level.get("id", "")), play_mode):
		return "done"
	var config: Dictionary = repository.load_level_config(level)
	var piece_ids: Array[String] = BoardSessionIdentityScript.piece_ids(config, play_mode)
	if not session_repository.play_state(str(topic.get("id", "")), str(level.get("id", "")), mode_key(play_mode), piece_ids).is_empty():
		return "active"
	return "todo"


func _level_has_session_progress(topic: Dictionary, level: Dictionary, play_modes: Array[String]) -> bool:
	for play_mode in play_modes:
		if level_mode_state(topic, level, play_mode) != "todo":
			return true
	return false


func available_modes_for_level(level: Dictionary) -> Array[String]:
	return available_modes_for_config(repository.load_level_config(level))


func available_modes_for_config(level_config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for play_mode in PLAY_MODES:
		if level_has_mode_data(level_config, play_mode):
			result.append(play_mode)
	return result


func level_has_mode_data(level_config: Dictionary, play_mode: String) -> bool:
	var mode := mode_key(play_mode)
	if mode == "swap":
		return not repository.level_image_path(level_config).is_empty()
	if mode == "knob":
		var knob_config: Dictionary = repository.mode_config(level_config, play_mode)
		return not knob_config.is_empty() and not repository.level_image_path(level_config).is_empty()
	var mode_data: Dictionary = repository.mode_config(level_config, play_mode)
	if mode_data.is_empty():
		return false
	var pieces = mode_data.get("pieces", [])
	return typeof(pieces) == TYPE_ARRAY and not pieces.is_empty()


func preferred_available_mode(level: Dictionary, available_modes: Array[String]) -> String:
	if available_modes.is_empty():
		return ""
	var preferred := mode_key(progress_store.preferred_mode(level))
	if available_modes.has(preferred):
		return preferred
	return available_modes[0]


func topic_available_mode_total(topic: Dictionary) -> int:
	var total := 0
	for level in topic.get("levels", []):
		total += available_modes_for_level(level).size()
	return total


func topic_available_done_count(topic: Dictionary) -> int:
	var done := 0
	for level in topic.get("levels", []):
		for play_mode in available_modes_for_level(level):
			if progress_store.is_done(level["id"], play_mode):
				done += 1
	return done


func topic_mode_total(topic: Dictionary, play_mode: String) -> int:
	var total := 0
	for level in topic.get("levels", []):
		if available_modes_for_level(level).has(mode_key(play_mode)):
			total += 1
	return total


func topic_mode_done_count(topic: Dictionary, play_mode: String) -> int:
	var done := 0
	var key := mode_key(play_mode)
	for level in topic.get("levels", []):
		if available_modes_for_level(level).has(key) and progress_store.is_done(level["id"], key):
			done += 1
	return done


static func mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode
