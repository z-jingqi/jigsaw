class_name LevelFocusOverlay
extends Control

signal mode_selected(level_id: String, mode: StringName, start_policy: StringName)
signal closed

const ModeStatusIconScene := preload("res://scenes/ui/foundation/ModeStatusIcon.tscn")
const LIFT_DURATION := 0.14
const LAND_DURATION := 0.34
const PEER_SWEEP_DURATION := 0.44
const CLOSE_DURATION := 0.38
const CONTROL_REVEAL_DELAY := 0.34
const LIFT_SCALE := Vector2(1.045, 1.045)

@onready var input_blocker: Control = $InputBlocker
@onready var card_layer: Control = $CardLayer
@onready var options: HBoxContainer = $Options
@onready var start_button: ActionButton = $StartButton
@onready var start_label: Label = $StartButton/Label

var _view_model: Variant
var _selected_option: Variant
var _selected_card: LevelCard
var _scroll: ScrollContainer
var _saved_scroll_position := 0
var _card_state: Dictionary = {}
var _peer_states: Array[Dictionary] = []
var _active_tween: Tween
var _phase := &"idle"
var _reduced_motion := false
var _options_target_position := Vector2.ZERO
var _button_target_position := Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.pressed.connect(_on_start_pressed)
	resized.connect(_apply_layout)
	_apply_layout()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	start_button.set_reduced_motion(enabled)
	for child in options.get_children():
		child.set_reduced_motion(enabled)


func refresh_view_model(view_model: Variant) -> void:
	if not is_active():
		return
	var preferred_mode := StringName(_read_from(_selected_option, "mode", &""))
	_view_model = view_model
	if is_instance_valid(_selected_card):
		_selected_card.set_view_model(view_model)
		_selected_card.set_focus_variant(true)
	_reconcile_options(preferred_mode)


func open(
	card: LevelCard,
	view_model: Variant,
	peer_cards: Array[Control],
	scroll_control: ScrollContainer
) -> bool:
	if is_active() or not is_instance_valid(card) or not is_instance_valid(scroll_control):
		return false
	_view_model = view_model
	_selected_card = card
	_scroll = scroll_control
	_saved_scroll_position = scroll_control.scroll_vertical
	visible = true
	_phase = &"opening"
	_reconcile_options()
	_capture_card_states(peer_cards)
	_move_selected_card_to_overlay()
	_apply_layout()
	_prepare_controls_for_open()
	if _reduced_motion:
		_apply_open_end_state()
		_phase = &"focused"
		return true
	_animate_open()
	return true


func request_close() -> void:
	if not is_active() or _phase == &"closing":
		return
	_kill_active_tween()
	_phase = &"closing"
	_restore_scroll_position()
	if _reduced_motion:
		_finish_close(true)
		return
	var target_position := _selected_original_position_in_overlay()
	var lift_position := _selected_card.position + Vector2(0.0, -24.0)
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(_selected_card):
		_active_tween.tween_property(_selected_card, "position", lift_position, LIFT_DURATION)
		_active_tween.tween_property(_selected_card, "scale", LIFT_SCALE, LIFT_DURATION)
		(
			_active_tween
			. tween_property(_selected_card, "position", target_position, CLOSE_DURATION)
			. set_delay(LIFT_DURATION * 0.72)
		)
		(
			_active_tween
			. tween_property(
				_selected_card, "size", _card_state.get("size", _selected_card.size), CLOSE_DURATION
			)
			. set_delay(LIFT_DURATION * 0.72)
		)
		(
			_active_tween
			. tween_property(_selected_card, "scale", _card_state.scale, CLOSE_DURATION)
			. set_delay(LIFT_DURATION * 0.72)
		)
	for peer_index in _peer_states.size():
		var state := _peer_states[peer_index]
		var peer := state.get("card") as Control
		if not is_instance_valid(peer):
			continue
		var delay := float(_peer_states.size() - 1 - peer_index) * 0.018
		_active_tween.tween_property(peer, "position", state.position, CLOSE_DURATION).set_delay(
			delay
		)
		_active_tween.tween_property(peer, "scale", state.scale, CLOSE_DURATION).set_delay(delay)
	_active_tween.tween_property(options, "modulate:a", 0.0, LIFT_DURATION)
	_active_tween.tween_property(
		options, "position", _options_target_position + Vector2(0.0, 56.0), LIFT_DURATION
	)
	_active_tween.tween_property(start_button, "modulate:a", 0.0, LIFT_DURATION)
	_active_tween.tween_property(
		start_button, "position", _button_target_position + Vector2(0.0, 56.0), LIFT_DURATION
	)
	_active_tween.finished.connect(_finish_close.bind(true))


func reset_immediately() -> void:
	if not is_active():
		return
	_kill_active_tween()
	_finish_close(false)


func is_active() -> bool:
	return _phase != &"idle"


func focused_level_id() -> String:
	return str(_read("level_id", "")) if is_active() else ""


func active_motion_count() -> int:
	var count := 1 if _active_tween != null else 0
	count += start_button.active_motion_count()
	for child in options.get_children():
		count += child.active_motion_count()
	return count


func debug_snapshot() -> Dictionary:
	var left_swept_peers := 0
	for state in _peer_states:
		var peer := state.get("card") as Control
		if not is_instance_valid(peer):
			continue
		if peer.get_global_rect().end.x <= 0.0:
			left_swept_peers += 1
	return {
		"active": is_active(),
		"phase": String(_phase),
		"level_id": focused_level_id(),
		"scroll_position": _scroll.scroll_vertical if is_instance_valid(_scroll) else -1,
		"saved_scroll_position": _saved_scroll_position,
		"peer_count": _peer_states.size(),
		"left_swept_peer_count": left_swept_peers,
		"option_count": options.get_child_count(),
		"focused_card_rect":
		_selected_card.get_global_rect() if is_instance_valid(_selected_card) else Rect2(),
	}


func _reconcile_options(preferred_mode := StringName()) -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var available: Array = []
	for option_model in _read("modes", []):
		if not bool(_read_from(option_model, "enabled", false)):
			continue
		var option := ModeStatusIconScene.instantiate() as ModeStatusIcon
		options.add_child(option)
		option.set_variant(&"focus")
		option.set_interactive(true)
		option.set_reduced_motion(_reduced_motion)
		option.set_view_model(option_model)
		option.selection_requested.connect(_on_option_selected)
		available.append(option_model)
	_selected_option = _option_for_mode(available, preferred_mode)
	if _selected_option == null:
		_selected_option = _default_option(available)
	_refresh_selection()
	options.queue_sort()


func _default_option(available: Array) -> Variant:
	for status in [&"in_progress", &"not_started", &"completed"]:
		for option_model in available:
			if StringName(_read_from(option_model, "status", &"")) == status:
				return option_model
	return null


func _option_for_mode(available: Array, mode: StringName) -> Variant:
	if mode.is_empty():
		return null
	for option_model in available:
		if StringName(_read_from(option_model, "mode", &"")) == mode:
			return option_model
	return null


func _on_option_selected(mode: StringName, _policy: StringName) -> void:
	for option_model in _read("modes", []):
		if StringName(_read_from(option_model, "mode", &"")) == mode:
			_selected_option = option_model
			break
	_refresh_selection()


func _refresh_selection() -> void:
	var selected_mode := StringName(_read_from(_selected_option, "mode", &""))
	for child in options.get_children():
		child.set_selected(child.mode() == selected_mode)
	start_button.disabled = selected_mode.is_empty()
	var action_text := str(_read_from(_selected_option, "action_label", ""))
	start_label.text = action_text if not action_text.is_empty() else "开始拼图"


func _on_start_pressed() -> void:
	if _selected_option == null or start_button.disabled:
		return
	mode_selected.emit(
		focused_level_id(),
		StringName(_read_from(_selected_option, "mode", &"")),
		StringName(_read_from(_selected_option, "action", &"start"))
	)


func _capture_card_states(peer_cards: Array[Control]) -> void:
	_selected_card.cancel_motion()
	_selected_card.scale = Vector2.ONE
	_card_state = {
		"parent": _selected_card.get_parent(),
		"index": _selected_card.get_index(),
		"position": _selected_card.position,
		"size": _selected_card.size,
		"custom_minimum_size": _selected_card.custom_minimum_size,
		"scale": _selected_card.scale,
		"modulate": _selected_card.modulate,
		"pivot_offset": _selected_card.pivot_offset,
		"mouse_filter": _selected_card.mouse_filter,
		"z_index": _selected_card.z_index,
	}
	_peer_states.clear()
	for peer in peer_cards:
		if not is_instance_valid(peer) or peer == _selected_card:
			continue
		if peer.has_method(&"cancel_motion"):
			peer.call(&"cancel_motion")
		var sweep_distance := size.x + peer.position.x + peer.size.x + 120.0
		(
			_peer_states
			. append(
				{
					"card": peer,
					"position": peer.position,
					"focus_position": peer.position + Vector2(-sweep_distance, 0.0),
					"scale": peer.scale,
					"modulate": peer.modulate,
					"pivot_offset": peer.pivot_offset,
					"mouse_filter": peer.mouse_filter,
				}
			)
		)
		peer.pivot_offset = peer.size * 0.5
		peer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _move_selected_card_to_overlay() -> void:
	var global_origin := _selected_card.get_global_transform().origin
	var original_parent := _selected_card.get_parent()
	original_parent.remove_child(_selected_card)
	card_layer.add_child(_selected_card)
	_selected_card.position = card_layer.get_global_transform().affine_inverse() * global_origin
	_selected_card.custom_minimum_size = Vector2.ZERO
	_selected_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_card.z_index = 10
	_selected_card.set_focus_variant(true)


func _prepare_controls_for_open() -> void:
	_options_target_position = options.position
	_button_target_position = start_button.position
	options.modulate.a = 0.0
	options.position = _options_target_position + Vector2(0.0, 72.0)
	start_button.modulate.a = 0.0
	start_button.position = _button_target_position + Vector2(0.0, 72.0)


func _animate_open() -> void:
	var target_rect := _focus_card_target_rect()
	var lift_position := _selected_card.position + Vector2(0.0, -24.0)
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_selected_card, "position", lift_position, LIFT_DURATION)
	_active_tween.tween_property(_selected_card, "scale", LIFT_SCALE, LIFT_DURATION)
	(
		_active_tween
		. tween_property(_selected_card, "position", target_rect.position, LAND_DURATION)
		. set_delay(LIFT_DURATION * 0.72)
	)
	_active_tween.tween_property(_selected_card, "size", target_rect.size, LAND_DURATION).set_delay(
		LIFT_DURATION * 0.72
	)
	_active_tween.tween_property(_selected_card, "scale", Vector2.ONE, LAND_DURATION).set_delay(
		LIFT_DURATION * 0.72
	)
	for peer_index in _peer_states.size():
		var state := _peer_states[peer_index]
		var peer := state.get("card") as Control
		if not is_instance_valid(peer):
			continue
		var delay := float(peer_index) * 0.018
		(
			_active_tween
			. tween_property(peer, "position", state.focus_position, PEER_SWEEP_DURATION)
			. set_delay(delay)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_IN)
		)
		(
			_active_tween
			. tween_property(peer, "scale", Vector2(0.96, 0.96), PEER_SWEEP_DURATION)
			. set_delay(delay)
		)
	(
		_active_tween
		. tween_property(options, "position", _options_target_position, LAND_DURATION)
		. set_delay(CONTROL_REVEAL_DELAY)
	)
	_active_tween.tween_property(options, "modulate:a", 1.0, LAND_DURATION * 0.62).set_delay(
		CONTROL_REVEAL_DELAY
	)
	(
		_active_tween
		. tween_property(start_button, "position", _button_target_position, LAND_DURATION)
		. set_delay(CONTROL_REVEAL_DELAY + 0.04)
	)
	_active_tween.tween_property(start_button, "modulate:a", 1.0, LAND_DURATION * 0.62).set_delay(
		CONTROL_REVEAL_DELAY + 0.04
	)
	_active_tween.finished.connect(_on_open_finished)


func _on_open_finished() -> void:
	_active_tween = null
	if _phase == &"opening":
		_phase = &"focused"


func _apply_open_end_state() -> void:
	var target_rect := _focus_card_target_rect()
	_selected_card.position = target_rect.position
	_selected_card.size = target_rect.size
	for state in _peer_states:
		var peer := state.get("card") as Control
		if not is_instance_valid(peer):
			continue
		peer.position = state.focus_position
		peer.scale = Vector2(0.96, 0.96)
		peer.modulate = state.modulate
	options.position = _options_target_position
	options.modulate.a = 1.0
	start_button.position = _button_target_position
	start_button.modulate.a = 1.0


func _finish_close(emit_closed: bool) -> void:
	_kill_active_tween()
	_restore_scroll_position()
	for state in _peer_states:
		var peer := state.get("card") as Control
		if not is_instance_valid(peer):
			continue
		peer.position = state.position
		peer.scale = state.scale
		peer.modulate = state.modulate
		peer.pivot_offset = state.pivot_offset
		peer.mouse_filter = state.mouse_filter
	_restore_selected_card()
	_peer_states.clear()
	_card_state.clear()
	_view_model = null
	_selected_option = null
	_selected_card = null
	_scroll = null
	_phase = &"idle"
	visible = false
	if emit_closed:
		closed.emit()


func _restore_selected_card() -> void:
	if not is_instance_valid(_selected_card) or _card_state.is_empty():
		return
	var original_parent := _card_state.get("parent") as Control
	if not is_instance_valid(original_parent):
		return
	card_layer.remove_child(_selected_card)
	original_parent.add_child(_selected_card)
	original_parent.move_child(
		_selected_card,
		mini(int(_card_state.get("index", 0)), original_parent.get_child_count() - 1)
	)
	_selected_card.set_focus_variant(false)
	_selected_card.position = _card_state.position
	_selected_card.size = _card_state.size
	_selected_card.custom_minimum_size = _card_state.custom_minimum_size
	_selected_card.scale = _card_state.scale
	_selected_card.modulate = _card_state.modulate
	_selected_card.pivot_offset = _card_state.pivot_offset
	_selected_card.mouse_filter = _card_state.mouse_filter
	_selected_card.z_index = int(_card_state.z_index)


func _restore_scroll_position() -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = _saved_scroll_position


func _selected_original_position_in_overlay() -> Vector2:
	var original_parent := _card_state.get("parent") as Control
	if not is_instance_valid(original_parent):
		return _selected_card.position if is_instance_valid(_selected_card) else Vector2.ZERO
	var target_global := original_parent.get_global_transform() * (_card_state.position as Vector2)
	return card_layer.get_global_transform().affine_inverse() * target_global


func _focus_card_target_rect() -> Rect2:
	var card_width := clampf(size.x * 0.55, 520.0, 660.0)
	var card_size := Vector2(card_width, card_width * 1.17)
	var top := clampf(size.y * 0.19, 430.0, 560.0)
	return Rect2(Vector2((size.x - card_size.x) * 0.5, top), card_size)


func _apply_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var options_width := minf(760.0, size.x - 120.0)
	options.size = Vector2(options_width, 224.0)
	options.position = Vector2((size.x - options_width) * 0.5, size.y * 0.535)
	var button_width := minf(620.0, size.x * 0.52)
	start_button.size = Vector2(button_width, 160.0)
	start_button.position = Vector2(
		(size.x - button_width) * 0.5,
		minf(size.y - 220.0, maxf(options.position.y + options.size.y + 96.0, size.y * 0.67))
	)
	_options_target_position = options.position
	_button_target_position = start_button.position
	if _phase == &"focused" and is_instance_valid(_selected_card):
		var target_rect := _focus_card_target_rect()
		_selected_card.position = target_rect.position
		_selected_card.size = target_rect.size


func _kill_active_tween() -> void:
	if _active_tween == null:
		return
	_active_tween.kill()
	_active_tween = null


func _read(field: String, fallback: Variant = null) -> Variant:
	return _read_from(_view_model, field, fallback)


func _read_from(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	if source == null:
		return fallback
	return source.get(field)
