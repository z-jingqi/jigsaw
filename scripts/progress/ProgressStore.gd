extends RefCounted
class_name ProgressStore

const ProgressPersistenceScript = preload("res://scripts/progress/ProgressPersistence.gd")

var save_path := "user://jigcat_progress.json"
var progress := {}
var persistence := ProgressPersistenceScript.new()


func load_from_disk() -> void:
	progress = persistence.load_data(save_path)


func save_to_disk() -> void:
	persistence.save_data(save_path, progress)


func is_done(level_id: String, play_mode: String) -> bool:
	var key := mode_key(play_mode)
	var completed: Dictionary = progress.get("completed", {})
	if completed.has("%s:%s" % [level_id, key]):
		return true
	if progress.has(level_id) and typeof(progress[level_id]) == TYPE_DICTIONARY:
		var legacy: Dictionary = progress[level_id]
		if legacy.get(key, false):
			return true
		return key == "knob" and legacy.get("classic", false)
	return false


func mark_completed(level_id: String, play_mode: String) -> void:
	var key := mode_key(play_mode)
	var completed: Dictionary = progress.get("completed", {})
	completed["%s:%s" % [level_id, key]] = true
	progress["completed"] = completed
	var legacy: Dictionary = progress.get(level_id, {})
	legacy[key] = true
	progress[level_id] = legacy
	save_to_disk()


func mark_last_played(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	progress["last_topic_id"] = str(topic.get("id", ""))
	progress["last_level_id"] = str(level.get("id", ""))
	progress["last_mode"] = mode_key(play_mode)
	progress["_last_topic_id"] = progress["last_topic_id"]
	progress["_last_level_id"] = progress["last_level_id"]
	progress["_last_mode"] = progress["last_mode"]
	save_to_disk()


func play_state(topic: Dictionary, level: Dictionary, play_mode: String) -> Dictionary:
	var states: Dictionary = progress.get("play_states", {})
	var state = states.get(play_state_key(topic, level, play_mode), {})
	return state if typeof(state) == TYPE_DICTIONARY else {}


func save_play_state(topic: Dictionary, level: Dictionary, play_mode: String, state: Dictionary) -> void:
	if topic.is_empty() or level.is_empty() or state.is_empty():
		return
	var states: Dictionary = progress.get("play_states", {})
	states[play_state_key(topic, level, play_mode)] = state
	progress["play_states"] = states
	mark_last_played(topic, level, play_mode)


func clear_play_state(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
	var states: Dictionary = progress.get("play_states", {})
	states.erase(play_state_key(topic, level, play_mode))
	progress["play_states"] = states
	save_to_disk()


func clear_level_progress(topic: Dictionary, level: Dictionary) -> void:
	if level.is_empty():
		return
	var level_id := str(level.get("id", ""))
	var completed: Dictionary = progress.get("completed", {})
	for play_mode in ["polygon", "knob", "swap"]:
		completed.erase("%s:%s" % [level_id, mode_key(play_mode)])
	progress["completed"] = completed
	progress.erase(level_id)
	var states: Dictionary = progress.get("play_states", {})
	for play_mode in ["polygon", "knob", "swap"]:
		states.erase(play_state_key(topic, level, play_mode))
	progress["play_states"] = states
	save_to_disk()


func clear_all_progress() -> void:
	progress = {}
	save_to_disk()


func play_state_key(topic: Dictionary, level: Dictionary, play_mode: String) -> String:
	return "%s/%s:%s" % [
		str(topic.get("id", "")),
		str(level.get("id", "")),
		mode_key(play_mode),
	]


func tutorial_seen(play_mode := "") -> bool:
	var key := mode_key(play_mode)
	if not key.is_empty():
		var modes: Dictionary = progress.get("tutorial_seen_modes", {})
		if modes.has(key):
			return bool(modes[key])
	return bool(progress.get("tutorial_seen", progress.get("_tutorial_seen", false)))


func mark_tutorial_seen(play_mode := "") -> void:
	var key := mode_key(play_mode)
	if key.is_empty():
		progress["tutorial_seen"] = true
		progress["_tutorial_seen"] = true
	else:
		var modes: Dictionary = progress.get("tutorial_seen_modes", {})
		modes[key] = true
		progress["tutorial_seen_modes"] = modes
	save_to_disk()


func haptics_enabled() -> bool:
	return bool(progress.get("haptics_enabled", true))


func set_haptics_enabled(enabled: bool) -> void:
	progress["haptics_enabled"] = enabled
	save_to_disk()


func music_enabled() -> bool:
	return bool(progress.get("music_enabled", true))


func set_music_enabled(enabled: bool) -> void:
	progress["music_enabled"] = enabled
	save_to_disk()


func sound_effects_enabled() -> bool:
	return bool(progress.get("sound_effects_enabled", true))


func set_sound_effects_enabled(enabled: bool) -> void:
	progress["sound_effects_enabled"] = enabled
	save_to_disk()


func reduced_motion_enabled() -> bool:
	return bool(progress.get("reduced_motion_enabled", false))


func set_reduced_motion_enabled(enabled: bool) -> void:
	progress["reduced_motion_enabled"] = enabled
	save_to_disk()


func edge_contrast_mode() -> String:
	var mode := str(progress.get("edge_contrast_mode", "auto"))
	return mode if ["auto", "dark", "light"].has(mode) else "auto"


func set_edge_contrast_mode(mode: String) -> void:
	progress["edge_contrast_mode"] = mode if ["auto", "dark", "light"].has(mode) else "auto"
	save_to_disk()


func random_rotation_enabled() -> bool:
	return bool(progress.get("random_rotation_enabled", false))


func set_random_rotation_enabled(enabled: bool) -> void:
	progress["random_rotation_enabled"] = enabled
	save_to_disk()


func completed_modes(level_id: String) -> Array:
	var modes := []
	if is_done(level_id, "polygon"):
		modes.append("polygon")
	if is_done(level_id, "knob"):
		modes.append("knob")
	if is_done(level_id, "swap"):
		modes.append("swap")
	return modes


func topic_done_count(topic: Dictionary) -> int:
	var count := 0
	for level in topic.get("levels", []):
		if is_done(level["id"], "polygon"):
			count += 1
		if is_done(level["id"], "knob"):
			count += 1
		if is_done(level["id"], "swap"):
			count += 1
	return count


func mode_done_count(topic: Dictionary, play_mode: String) -> int:
	var count := 0
	for level in topic.get("levels", []):
		if is_done(level["id"], play_mode):
			count += 1
	return count


func last_topic_or_first(topics: Array[Dictionary]) -> Dictionary:
	var topic := topic_by_id(topics, str(progress.get("last_topic_id", progress.get("_last_topic_id", ""))))
	if not topic.is_empty():
		return topic
	return topics[0] if not topics.is_empty() else {}


func topic_by_id(topics: Array[Dictionary], topic_id: String) -> Dictionary:
	for topic in topics:
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func level_by_id(topic: Dictionary, level_id: String) -> Dictionary:
	for level in topic.get("levels", []):
		if str(level.get("id", "")) == level_id:
			return level
	return {}


func last_level_in_topic(topic: Dictionary) -> Dictionary:
	return level_by_id(topic, str(progress.get("last_level_id", progress.get("_last_level_id", ""))))


func level_has_progress(topic: Dictionary, level: Dictionary, play_modes: Array[String]) -> bool:
	var level_id := str(level.get("id", ""))
	for play_mode in play_modes:
		if is_done(level_id, play_mode) or not play_state(topic, level, play_mode).is_empty():
			return true
	return false


func focus_level_id(topic: Dictionary) -> String:
	var focus := focus_level(topic)
	return str(focus.get("id", ""))


func focus_level(topic: Dictionary) -> Dictionary:
	var last_level := last_level_in_topic(topic)
	if not last_level.is_empty() and level_has_unfinished_mode(last_level):
		return last_level
	for level in topic.get("levels", []):
		if level_has_unfinished_mode(level):
			return level
	if not topic.get("levels", []).is_empty():
		return topic["levels"][0]
	return {}


func level_has_unfinished_mode(level: Dictionary) -> bool:
	return not is_done(level["id"], "polygon") or not is_done(level["id"], "knob") or not is_done(level["id"], "swap")


func preferred_mode(level: Dictionary) -> String:
	var last_mode := mode_key(str(progress.get("last_mode", progress.get("_last_mode", "polygon"))))
	if last_mode == "polygon" and not is_done(level["id"], "polygon"):
		return "polygon"
	if last_mode == "knob" and not is_done(level["id"], "knob"):
		return "knob"
	if last_mode == "swap" and not is_done(level["id"], "swap"):
		return "swap"
	if not is_done(level["id"], "polygon"):
		return "polygon"
	if not is_done(level["id"], "knob"):
		return "knob"
	if not is_done(level["id"], "swap"):
		return "swap"
	return last_mode


func resume_target(topics: Array[Dictionary]) -> Dictionary:
	var topic := last_topic_or_first(topics)
	if topic.is_empty():
		return {}
	var level := focus_level(topic)
	if level.is_empty():
		return {}
	return {
		"topic": topic,
		"level": level,
		"mode": preferred_mode(level),
	}


func last_completed_level(topics: Array[Dictionary]) -> Dictionary:
	for topic in topics:
		for level in topic.get("levels", []):
			if is_done(level["id"], "polygon") or is_done(level["id"], "knob") or is_done(level["id"], "swap"):
				return level
	return {}


func first_unfinished_level(topics: Array[Dictionary]) -> Dictionary:
	for topic in topics:
		for level in topic.get("levels", []):
			if level_has_unfinished_mode(level):
				return {
					"topic": topic,
					"level": level,
					"mode": preferred_mode(level),
				}
	return {}


static func mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode
