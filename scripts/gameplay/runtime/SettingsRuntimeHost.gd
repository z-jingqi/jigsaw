class_name SettingsRuntimeHost
extends RefCounted

const SettingsModalScene := preload("res://scenes/modals/SettingsModal.tscn")

const SETTING_KEYS := [&"haptics_enabled", &"music_enabled", &"sound_effects_enabled"]

var game: Node
var modal: Control


func _init(owner: Node) -> void:
	game = owner


func show() -> void:
	clear()
	modal = SettingsModalScene.instantiate() as Control
	game.modal_root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.connect(&"setting_changed", _on_setting_changed)
	modal.connect(&"close_requested", _on_close_requested)
	game.current_modal = "settings"
	game.modal_open = true
	modal.call(&"navigation_enter", {
		"view_model": game.system_presenter.settings(),
		"labels": {
			"title": game._t("settings_title"),
			"haptics": game._t("haptics"),
			"music": game._t("music"),
			"sound_effects": game._t("sfx"),
		},
	}, {"reduced_motion": game._reduced_motion_enabled()})


func request_close() -> void:
	if is_instance_valid(modal):
		modal.call(&"request_close")


func clear() -> void:
	if not is_instance_valid(modal):
		return
	modal.call(&"navigation_exit", {})
	modal.queue_free()
	modal = null


func shutdown() -> void:
	clear()
	game = null


func active_motion_count() -> int:
	return int(modal.call(&"active_motion_count")) if is_instance_valid(modal) else 0


func _on_setting_changed(key: StringName, enabled: bool) -> void:
	if key not in SETTING_KEYS:
		_render_error(key, "invalid_argument")
		return
	var confirmed: Dictionary = game.settings_repository.snapshot()
	var previous := bool(confirmed.get(key, false))
	var persisted: Dictionary = game.settings_repository.set_value(key, enabled)
	if not bool(persisted.get("ok", false)):
		_render_error(key, str(persisted.get("error", "save_failed")))
		return
	var applied: Dictionary = game.apply_settings_snapshot()
	if bool(applied.get("ok", false)):
		_render_confirmed()
		return
	game.settings_repository.set_value(key, previous)
	game.apply_settings_snapshot()
	_render_error(key, str(applied.get("error", "apply_failed")))


func _render_confirmed() -> void:
	if is_instance_valid(modal):
		modal.call(&"render_view_model", game.system_presenter.settings())


func _render_error(key: StringName, error_code: String) -> void:
	if is_instance_valid(modal):
		modal.call(&"render_view_model", game.system_presenter.settings({}, {key: error_code}))


func _on_close_requested() -> void:
	clear()
	game.current_modal = ""
	game.modal_open = false
