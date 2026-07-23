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


func tutorial_seen(kind: StringName, mode: String = "") -> bool:
	var tutorials: Dictionary = _data["tutorials_seen"]
	if kind == &"mode":
		return bool((tutorials.get("modes", {}) as Dictionary).get(mode, false))
	return bool(tutorials.get(String(kind), false))


func mark_tutorial_seen(kind: StringName, mode: String = "") -> Dictionary:
	if kind == &"mode" and not PLAY_MODES.has(mode):
		return {"ok": false, "error": "invalid_argument"}
	var next_data := _data.duplicate(true)
	var tutorials: Dictionary = next_data["tutorials_seen"]
	if kind == &"mode":
		var modes: Dictionary = tutorials.get("modes", {})
		if bool(modes.get(mode, false)):
			return {"ok": true, "changed": false}
		modes[mode] = true
		tutorials["modes"] = modes
	else:
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
		for theme_id in (value["completed_modes"] as Dictionary):
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
	if typeof(value.get("tutorials_seen")) == TYPE_DICTIONARY:
		var source_tutorials: Dictionary = value["tutorials_seen"]
		var tutorials: Dictionary = result["tutorials_seen"]
		tutorials["home_swipe"] = bool(source_tutorials.get("home_swipe", false))
		tutorials["home_enter"] = bool(source_tutorials.get("home_enter", false))
		var source_modes: Variant = source_tutorials.get("modes", {})
		if typeof(source_modes) == TYPE_DICTIONARY:
			var modes: Dictionary = {}
			for mode in PLAY_MODES:
				if typeof(source_modes.get(mode)) == TYPE_BOOL:
					modes[mode] = source_modes[mode]
			tutorials["modes"] = modes
		result["tutorials_seen"] = tutorials
	return result


func _defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"completed_modes": {},
		"tutorials_seen": {"home_swipe": false, "home_enter": false, "modes": {}},
	}
