class_name ModeOption
extends ActionButton

signal selection_requested(mode: StringName, start_policy: StringName)

@onready var name_label: Label = $Margin/Content/Text/Name
@onready var status_label: Label = $Margin/Content/Text/Status
@onready var action_label: Label = $Margin/Content/Action

var _view_model: Variant
var _selection_committed := false


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	pressed.connect(_on_pressed)
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	_selection_committed = false
	if is_node_ready():
		_apply_view_model()


func set_interaction_enabled(enabled: bool) -> void:
	disabled = not enabled or not bool(_read("enabled", false))


func _on_pressed() -> void:
	if _selection_committed or disabled:
		return
	_selection_committed = true
	selection_requested.emit(StringName(_read("mode", "")), StringName(_read("action", "start")))


func _apply_view_model() -> void:
	var enabled := bool(_read("enabled", false))
	var status := String(_read("status", "unavailable"))
	var action := String(_read("action", "start"))
	name_label.text = str(_read("label", ""))
	status_label.text = _status_text(status)
	action_label.text = _action_text(action) if enabled else "Unavailable"
	disabled = not enabled
	accessibility_name = "%s, %s, %s" % [name_label.text, status_label.text, action_label.text]
	accessibility_description = ""
	tooltip_text = accessibility_name
	modulate.a = 1.0 if enabled else 0.48


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback


func _status_text(status: String) -> String:
	match status:
		"completed":
			return "Completed"
		"in_progress":
			return "In progress"
		"not_started":
			return "Not started"
		_:
			return "Unavailable"


func _action_text(action: String) -> String:
	match action:
		"resume":
			return "Continue"
		"replay":
			return "Replay"
		_:
			return "Start"
