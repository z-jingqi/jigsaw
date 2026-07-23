class_name LevelCard
extends ActionButton

@onready var title_label: Label = $Margin/Content/Title
@onready var status_label: Label = $Margin/Content/Status

var level_id := ""

func _ready() -> void:
	kind = Kind.CARD
	super._ready()

func set_view_model(view_model: Variant) -> void:
	level_id = str(view_model.get("level_id"))
	title_label.text = str(view_model.get("title"))
	disabled = bool(view_model.get("locked"))
	var states: Array = view_model.get("modes", [])
	var status_parts: Array[String] = []
	for mode in states:
		status_parts.append(str(mode.get("status", "")))
	status_label.text = " · ".join(status_parts)
	tooltip_text = title_label.text
	accessibility_name = tooltip_text
