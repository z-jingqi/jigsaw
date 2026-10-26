extends Control
## Three fixed mode identities, read directly from their completed state.

const ORDER := [&"polygon", &"knob", &"swap"]
const COMPLETE := {
	&"polygon": preload("res://assets/ui/mode-status/polygon-complete.svg"),
	&"knob": preload("res://assets/ui/mode-status/knob-complete.svg"),
	&"swap": preload("res://assets/ui/mode-status/swap-complete.svg"),
}
const INCOMPLETE := {
	&"polygon": preload("res://assets/ui/mode-status/polygon-incomplete.svg"),
	&"knob": preload("res://assets/ui/mode-status/knob-incomplete.svg"),
	&"swap": preload("res://assets/ui/mode-status/swap-incomplete.svg"),
}
var _slots: Array[TextureRect] = []
var _completed: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slots()


func set_modes(states: Array, enabled := true) -> void:
	_ensure_slots()
	_completed.clear()
	for state in states:
		if StringName(state.get("status")) == &"completed" and enabled:
			_completed[StringName(state.get("mode"))] = true
	for i in ORDER.size():
		_slots[i].texture = COMPLETE[ORDER[i]] if _completed.has(ORDER[i]) else INCOMPLETE[ORDER[i]]


func configure(side: float, gap: float) -> void:
	_ensure_slots()
	for i in _slots.size():
		_slots[i].position = Vector2(float(i) * (side + gap), 0)
		_slots[i].size = Vector2.ONE * side
	size = Vector2(side * 3.0 + gap * 2.0, side)


func completed_count() -> int:
	return _completed.size()


func _ensure_slots() -> void:
	if not _slots.is_empty():
		return
	for mode in ORDER:
		var icon := TextureRect.new()
		icon.name = String(mode).capitalize()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = INCOMPLETE[mode]
		add_child(icon)
		_slots.append(icon)
