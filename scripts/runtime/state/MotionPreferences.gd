class_name MotionPreferences
extends RefCounted

signal changed(snapshot: Dictionary, revision: int)

var _settings: SettingsRepository
var _debug_override: Variant = null
var _revision := 0


func _init(settings: SettingsRepository) -> void:
	_settings = settings
	_settings.changed.connect(_on_settings_changed)


func snapshot() -> Dictionary:
	return {
		"reduced_motion": bool(_debug_override) if _debug_override != null else bool(_settings.snapshot().get("reduced_motion_enabled", false)),
		"revision": _revision,
	}


func set_debug_override(value: Variant) -> void:
	if value != null and typeof(value) != TYPE_BOOL:
		return
	if _debug_override == value:
		return
	_debug_override = value
	_emit_changed()


func _on_settings_changed(_snapshot: Dictionary, _settings_revision: int) -> void:
	_emit_changed()


func _emit_changed() -> void:
	_revision += 1
	changed.emit(snapshot(), _revision)
