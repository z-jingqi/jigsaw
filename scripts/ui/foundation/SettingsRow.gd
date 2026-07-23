class_name SettingsRow
extends HBoxContainer

signal value_changed(key: StringName, enabled: bool)

@export var setting_key := StringName()
@onready var label: Label = $Label
@onready var toggle: CheckButton = $Toggle

func configure(key: StringName, label_text: String, enabled: bool) -> void:
	setting_key = key
	label.text = label_text
	toggle.button_pressed = enabled
	toggle.tooltip_text = label_text
	toggle.accessibility_name = label_text


func _on_toggle_toggled(enabled: bool) -> void:
	value_changed.emit(setting_key, enabled)
