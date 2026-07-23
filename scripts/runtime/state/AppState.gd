class_name AppState
extends RefCounted

signal changed(snapshot: Dictionary, revision: int)

var _route := StringName()
var _theme_id := ""
var _level_id := ""
var _mode := StringName()
var _navigation_payload: Dictionary = {}
var _revision := 0


func update(route: StringName, payload: Dictionary = {}) -> void:
	_route = route
	_theme_id = str(payload.get("theme_id", payload.get("current_theme_id", _theme_id)))
	_level_id = str(payload.get("level_id", _level_id))
	_mode = StringName(payload.get("mode", _mode))
	_navigation_payload = payload.duplicate(true)
	_revision += 1
	changed.emit(snapshot(), _revision)


func snapshot() -> Dictionary:
	return {
		"route": String(_route),
		"theme_id": _theme_id,
		"level_id": _level_id,
		"mode": String(_mode),
		"navigation_payload": _navigation_payload.duplicate(true),
		"revision": _revision,
	}
