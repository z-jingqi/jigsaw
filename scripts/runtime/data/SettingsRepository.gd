class_name SettingsRepository
extends RefCounted

signal changed(snapshot: Dictionary, revision: int)

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://jigcat/settings_v1.json"

var _store: AtomicJsonStore
var _path: String
var _data := _defaults()
var _revision := 0


func _init(store: AtomicJsonStore = null, path: String = DEFAULT_PATH) -> void:
	_store = store if store != null else AtomicJsonStore.new()
	_path = path


func load() -> void:
	var loaded := _store.load_dictionary(_path)
	_data = _validated(loaded)
	_revision += 1
	changed.emit(snapshot(), _revision)


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func revision() -> int:
	return _revision


func set_value(key: StringName, value: bool) -> Dictionary:
	if key not in [&"haptics_enabled", &"music_enabled", &"sound_effects_enabled", &"reduced_motion_enabled"]:
		return {"ok": false, "error": "invalid_setting"}
	if bool(_data[key]) == value:
		return {"ok": true, "changed": false}
	var previous := _data.duplicate(true)
	_data[key] = value
	var saved := _store.write_dictionary(_path, _data)
	if not bool(saved.get("ok", false)):
		_data = previous
		return saved
	_revision += 1
	changed.emit(snapshot(), _revision)
	return {"ok": true, "changed": true}


func _validated(value: Dictionary) -> Dictionary:
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _defaults()
	var result := _defaults()
	for key in result:
		if key == "schema_version":
			continue
		if typeof(value.get(key)) == TYPE_BOOL:
			result[key] = value[key]
	return result


func _defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"haptics_enabled": true,
		"music_enabled": true,
		"sound_effects_enabled": true,
		"reduced_motion_enabled": false,
	}
