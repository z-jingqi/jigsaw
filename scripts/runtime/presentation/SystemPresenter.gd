class_name SystemPresenter
extends RefCounted

const ViewModelsScript := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _settings: Variant
var _motion: Variant
var _strings: Variant
var _revision := 0


func _init(settings: Variant, motion: Variant, strings: Variant) -> void:
	_settings = settings
	_motion = motion
	_strings = strings
	_settings.changed.connect(_on_source_changed)
	_motion.changed.connect(_on_motion_changed)


func settings(pending: Dictionary = {}, error_text: Dictionary = {}) -> AppViewModels.SettingsViewModel:
	var value: Dictionary = _settings.snapshot()
	return ViewModelsScript.SettingsViewModel.new({
		"revision": _revision,
		"haptics_enabled": value["haptics_enabled"],
		"music_enabled": value["music_enabled"],
		"sound_effects_enabled": value["sound_effects_enabled"],
		"pending": pending,
		"error_text": error_text,
	})


func guide(step: StringName, description: String, can_skip: bool = true) -> AppViewModels.GuideViewModel:
	return ViewModelsScript.GuideViewModel.new({
		"revision": _revision,
		"step": step,
		"description": description,
		"can_skip": can_skip,
		"reduced_motion": _motion.snapshot()["reduced_motion"],
	})


func completion(data: Dictionary) -> AppViewModels.CompletionViewModel:
	var value := data.duplicate(true)
	value["revision"] = _revision
	value["title"] = value.get("title", _strings.text("complete"))
	value["description"] = value.get("description", "")
	value["primary_action_text"] = value.get("primary_action_text", _strings.text("return_levels"))
	return ViewModelsScript.CompletionViewModel.new(value)


func _on_source_changed(_snapshot: Dictionary, _source_revision: int) -> void:
	_revision += 1


func _on_motion_changed(_snapshot: Dictionary, _source_revision: int) -> void:
	_revision += 1
