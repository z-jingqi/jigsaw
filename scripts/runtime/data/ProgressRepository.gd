class_name ProgressRepository
extends RefCounted

signal changed(snapshot: Dictionary, revision: int)

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://jigcat/progress_v1.json"
const PLAY_MODES := ["polygon", "knob", "swap"]

var _store: AtomicJsonStore
var _path: String
var _data := _defaults()
var _revision := 0


func _init(store: AtomicJsonStore = null, path: String = DEFAULT_PATH) -> void:
	_store = store if store != null else AtomicJsonStore.new()
	_path = path


func load() -> void:
	_data = _validated(_store.load_dictionary(_path))
	_revision += 1
	changed.emit(snapshot(), _revision)


func flush() -> Dictionary:
	if _store.has_method(&"flush"):
		return _store.call(&"flush")
	return {"ok": true}


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func revision() -> int:
	return _revision


func is_mode_completed(theme_id: String, level_id: String, mode: String) -> bool:
	return completed_modes_for_level(theme_id, level_id).has(mode)


func completed_modes_for_level(theme_id: String, level_id: String) -> Array[String]:
	var themes: Dictionary = _data["completed_modes"]
	var levels: Dictionary = themes.get(theme_id, {})
	var modes: Array = levels.get(level_id, [])
	var result: Array[String] = []
	for mode in modes:
		if typeof(mode) == TYPE_STRING and PLAY_MODES.has(mode):
			result.append(mode)
	return result


func mark_mode_completed(theme_id: String, level_id: String, mode: String) -> Dictionary:
	if theme_id.is_empty() or level_id.is_empty() or not PLAY_MODES.has(mode):
		return {"ok": false, "error": "invalid_argument"}
	var modes := completed_modes_for_level(theme_id, level_id)
	if modes.has(mode):
		return {"ok": true, "changed": false}
	modes.append(mode)
	modes.sort()
	var next_data := _data.duplicate(true)
	var themes: Dictionary = next_data["completed_modes"]
	var levels: Dictionary = themes.get(theme_id, {})
	levels[level_id] = modes
	themes[theme_id] = levels
	next_data["completed_modes"] = themes
	return _commit(next_data)


func is_level_visited(theme_id: String, level_id: String) -> bool:
	var visited: Dictionary = _data["visited_levels"]
	return (visited.get(theme_id, []) as Array).has(level_id)


func mark_level_visited(theme_id: String, level_id: String) -> Dictionary:
	if theme_id.is_empty() or level_id.is_empty():
		return {"ok": false, "error": "invalid_argument"}
	if is_level_visited(theme_id, level_id):
		return {"ok": true, "changed": false}
	return mark_level_visits([{"theme_id": theme_id, "level_id": level_id}])


func mark_level_visits(entries: Array) -> Dictionary:
	var next_data := _data.duplicate(true)
	var visited: Dictionary = next_data["visited_levels"]
	for entry in entries:
		if not entry is Dictionary:
			continue
		var theme_id := str(entry.get("theme_id", ""))
		var level_id := str(entry.get("level_id", ""))
		if theme_id.is_empty() or level_id.is_empty():
			continue
		var levels: Array = visited.get(theme_id, [])
		if not levels.has(level_id):
			levels.append(level_id)
			visited[theme_id] = levels
	if next_data == _data:
		return {"ok": true, "changed": false}
	return _commit(next_data)


func tutorial_seen(kind: StringName) -> bool:
	var tutorials: Dictionary = _data["tutorials_seen"]
	return bool(tutorials.get(String(kind), false))


func mark_tutorial_seen(kind: StringName) -> Dictionary:
	if kind not in [&"home_swipe", &"home_enter"]:
		return {"ok": false, "error": "invalid_argument"}
	var next_data := _data.duplicate(true)
	var tutorials: Dictionary = next_data["tutorials_seen"]
	if bool(tutorials.get(String(kind), false)):
		return {"ok": true, "changed": false}
	tutorials[String(kind)] = true
	next_data["tutorials_seen"] = tutorials
	return _commit(next_data)


func _commit(next_data: Dictionary) -> Dictionary:
	var saved := _store.write_dictionary(_path, next_data)
	if not bool(saved.get("ok", false)):
		return saved
	_data = next_data
	_revision += 1
	changed.emit(snapshot(), _revision)
	return {"ok": true, "changed": true}


func _validated(value: Dictionary) -> Dictionary:
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _defaults()
	var result := _defaults()
	if typeof(value.get("completed_modes")) == TYPE_DICTIONARY:
		var completed: Dictionary = {}
		for theme_id in value["completed_modes"] as Dictionary:
			var source_levels: Variant = value["completed_modes"][theme_id]
			if typeof(theme_id) != TYPE_STRING or typeof(source_levels) != TYPE_DICTIONARY:
				continue
			var levels: Dictionary = {}
			for level_id in source_levels:
				var source_modes: Variant = source_levels[level_id]
				if typeof(level_id) != TYPE_STRING or typeof(source_modes) != TYPE_ARRAY:
					continue
				var modes: Array[String] = []
				for mode in source_modes:
					if typeof(mode) == TYPE_STRING and PLAY_MODES.has(mode) and not modes.has(mode):
						modes.append(mode)
				if not modes.is_empty():
					levels[level_id] = modes
			if not levels.is_empty():
				completed[theme_id] = levels
		result["completed_modes"] = completed
	if typeof(value.get("visited_levels")) == TYPE_DICTIONARY:
		var visited: Dictionary = {}
		for theme_id in value["visited_levels"]:
			var source_levels: Variant = value["visited_levels"][theme_id]
			if typeof(theme_id) != TYPE_STRING or typeof(source_levels) != TYPE_ARRAY:
				continue
			var levels: Array[String] = []
			for level_id in source_levels:
				if (
					typeof(level_id) == TYPE_STRING
					and not level_id.is_empty()
					and not levels.has(level_id)
				):
					levels.append(level_id)
			if not levels.is_empty():
				visited[theme_id] = levels
		result["visited_levels"] = visited
	if typeof(value.get("tutorials_seen")) == TYPE_DICTIONARY:
		var source_tutorials: Dictionary = value["tutorials_seen"]
		var tutorials: Dictionary = result["tutorials_seen"]
		tutorials["home_swipe"] = bool(source_tutorials.get("home_swipe", false))
		tutorials["home_enter"] = bool(source_tutorials.get("home_enter", false))
		result["tutorials_seen"] = tutorials
	return result


func _defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"completed_modes": {},
		"visited_levels": {},
		"tutorials_seen": {"home_swipe": false, "home_enter": false},
	}
