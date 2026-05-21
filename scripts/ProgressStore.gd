extends RefCounted
class_name ProgressStore

var save_path := "user://jigcat_progress.json"
var progress := {}


func load_from_disk() -> void:
	if not FileAccess.file_exists(save_path):
		progress = {}
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	progress = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func save_to_disk() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(progress))


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


func tutorial_seen() -> bool:
	return bool(progress.get("tutorial_seen", progress.get("_tutorial_seen", false)))


func mark_tutorial_seen() -> void:
	progress["tutorial_seen"] = true
	progress["_tutorial_seen"] = true
	save_to_disk()


func completed_modes(level_id: String) -> Array:
	var modes := []
	if is_done(level_id, "polygon"):
		modes.append("多边形")
	if is_done(level_id, "knob"):
		modes.append("凹凸拼图")
	return modes


func topic_done_count(topic: Dictionary) -> int:
	var count := 0
	for level in topic.get("levels", []):
		if is_done(level["id"], "polygon"):
			count += 1
		if is_done(level["id"], "knob"):
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


func focus_level_id(topic: Dictionary) -> String:
	var focus := focus_level(topic)
	return str(focus.get("id", ""))


func focus_level(topic: Dictionary) -> Dictionary:
	var last_level := level_by_id(topic, str(progress.get("last_level_id", progress.get("_last_level_id", ""))))
	if not last_level.is_empty() and level_has_unfinished_mode(last_level):
		return last_level
	for level in topic.get("levels", []):
		if level_has_unfinished_mode(level):
			return level
	if not topic.get("levels", []).is_empty():
		return topic["levels"][0]
	return {}


func level_has_unfinished_mode(level: Dictionary) -> bool:
	return not is_done(level["id"], "polygon") or not is_done(level["id"], "knob")


func preferred_mode(level: Dictionary) -> String:
	var last_mode := mode_key(str(progress.get("last_mode", progress.get("_last_mode", "polygon"))))
	if last_mode == "polygon" and not is_done(level["id"], "polygon"):
		return "polygon"
	if last_mode == "knob" and not is_done(level["id"], "knob"):
		return "knob"
	if not is_done(level["id"], "polygon"):
		return "polygon"
	if not is_done(level["id"], "knob"):
		return "knob"
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
			if is_done(level["id"], "polygon") or is_done(level["id"], "knob"):
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
