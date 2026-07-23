class_name LevelCard
extends ActionButton

@onready var title_label: Label = $Margin/Content/Title
@onready var status_label: Label = $Margin/Content/Status
@onready var thumbnail: TextureRect = $Margin/Content/Thumbnail

var level_id := ""
var _view_model: Variant

func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	if _view_model != null:
		_apply_view_model()

func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func _apply_view_model() -> void:
	level_id = str(_read("level_id"))
	title_label.text = str(_read("title"))
	disabled = bool(_read("locked"))
	thumbnail.texture = _read("thumbnail") as Texture2D
	var states: Array = _read("modes")
	var status_parts: Array[String] = []
	for mode in states:
		var mode_name := str(_read_from(mode, "mode", ""))
		var state_name := str(_read_from(mode, "status", ""))
		status_parts.append(state_name if mode_name.is_empty() else "%s: %s" % [mode_name, state_name])
	status_label.text = " · ".join(status_parts)
	tooltip_text = title_label.text
	accessibility_name = tooltip_text


func _read(field: String) -> Variant:
	return _read_from(_view_model, field, [] if field == "modes" else null)


func _read_from(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	if source == null:
		return fallback
	return source.get(field)
