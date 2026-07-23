class_name AllThemesScreen
extends Control

signal close_requested()
signal theme_activated(theme_id: String, source_rect: Rect2)

const ThemeCardScene := preload("res://scenes/ui/foundation/ThemeCard.tscn")

@onready var close_button: Button = $SafeArea/Content/Header/CloseButton
@onready var scroll: ScrollContainer = $SafeArea/Content/Scroll
@onready var grid_content: Control = $SafeArea/Content/Scroll/GridContent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var backdrop: ColorRect = $Backdrop
@onready var header: Control = $SafeArea/Content/Header

var _view_model: Variant
var _cards: Dictionary = {}
var _reduced_motion := false
var _selection_tween: Tween
var _entry_tween: Tween
var _selecting := false
var _animation_active := false
var _animation_token := 0
var _has_been_activated := false


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	resized.connect(_apply_layout)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.pause()
	_apply_reset_state()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	play_enter()


func navigation_exit(_context: Dictionary) -> void:
	_stop_motion()
	animation_player.pause()
	_animation_active = false


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	if is_active:
		if _has_been_activated:
			_settle_visible_state()
		_has_been_activated = true
		_set_interaction_enabled(true)
	else:
		_stop_motion()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for card in _cards.values():
		var progress := card.get_node_or_null("Margin/Content/Progress") as ThemeProgress
		if progress != null:
			progress.reduced_motion = enabled
	if enabled:
		_settle_visible_state()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	_reconcile_cards()
	call_deferred("_apply_layout")


func refresh_view_model(view_model: Variant) -> void:
	set_view_model(view_model)


func active_motion_count() -> int:
	var player_motion := 1 if _animation_active else 0
	var selection_motion := 1 if _selection_tween != null else 0
	var entry_motion := 1 if _entry_tween != null else 0
	return player_motion + selection_motion + entry_motion


func debug_grid_column_count() -> int:
	return grid_column_count_for_width(scroll.size.x)


static func grid_column_count_for_width(available_width: float) -> int:
	return 3 if available_width >= 600.0 else 2


func play_enter() -> void:
	_stop_entry_motion()
	_animation_token += 1
	var token := _animation_token
	animation_player.play(&"enter")
	_animation_active = true
	if _reduced_motion:
		animation_player.seek(animation_player.get_animation(&"enter").length, true)
		animation_player.pause()
		_animation_active = false
		_apply_enter_final_state()
		return
	get_tree().create_timer(animation_player.get_animation(&"enter").length).timeout.connect(_finish_animation.bind(token), CONNECT_ONE_SHOT)
	var cards := _ordered_cards()
	for index in cards.size():
		var card: Control = cards[index]
		card.modulate.a = 0.0
		card.position.y += 12.0
	_entry_tween = create_tween().set_parallel(true)
	for index in cards.size():
		var card: Control = cards[index]
		var delay := minf(0.07, float(index / 2) * 0.035)
		_entry_tween.tween_property(card, "modulate:a", 1.0, 0.20).set_delay(delay)
		_entry_tween.tween_property(card, "position:y", _card_position(index).y, 0.20).set_delay(delay)
	_entry_tween.finished.connect(_finish_entry_motion, CONNECT_ONE_SHOT)


func _reconcile_cards() -> void:
	if _view_model == null:
		return
	var expected: Dictionary = {}
	for card_model in _view_model.cards:
		expected[str(card_model.theme_id)] = card_model
	for theme_id in _cards.keys().duplicate():
		if expected.has(theme_id):
			continue
		var stale: Control = _cards[theme_id]
		_cards.erase(theme_id)
		stale.queue_free()
	for theme_id in expected:
		var card: Control = _cards.get(theme_id)
		if card == null:
			card = ThemeCardScene.instantiate() as Control
			_cards[theme_id] = card
			grid_content.add_child(card)
			card.pressed.connect(_on_card_pressed.bind(card))
		var progress := card.get_node_or_null("Margin/Content/Progress") as ThemeProgress
		if progress != null:
			progress.reduced_motion = _reduced_motion
		card.call(&"set_view_model", expected[theme_id])


func _apply_layout() -> void:
	if _view_model == null:
		return
	var columns := grid_column_count_for_width(scroll.size.x)
	var regular := columns == 3
	var gap_x := 16.0 if regular else 12.0
	var gap_y := 16.0
	var width := maxf(1.0, scroll.size.x)
	var card_width := (width - float(columns - 1) * gap_x) / float(columns)
	var card_size := Vector2(card_width, maxf(208.0, card_width * 1.42))
	var cards := _ordered_cards()
	for index in cards.size():
		var card: Control = cards[index]
		card.size = card_size
		card.custom_minimum_size = card_size
		card.position = _card_position(index, columns, gap_x, gap_y, card_size)
	var rows := ceili(float(cards.size()) / float(columns))
	grid_content.custom_minimum_size = Vector2(width, maxf(0.0, float(rows) * card_size.y + maxf(0.0, float(rows - 1)) * gap_y))


func _card_position(index: int, columns := -1, gap_x := 0.0, gap_y := 0.0, card_size := Vector2.ZERO) -> Vector2:
	if columns < 0:
		columns = grid_column_count_for_width(scroll.size.x)
		var regular := columns == 3
		gap_x = 16.0 if regular else 12.0
		gap_y = 16.0
		var width := maxf(1.0, scroll.size.x)
		card_size = Vector2((width - float(columns - 1) * gap_x) / float(columns), 0.0)
	var row := index / columns
	var column := index % columns
	return Vector2(float(column) * (card_size.x + gap_x), float(row) * (card_size.y + gap_y))


func _ordered_cards() -> Array[Control]:
	var result: Array[Control] = []
	if _view_model == null:
		return result
	for card_model in _view_model.cards:
		var card: Control = _cards.get(str(card_model.theme_id))
		if card != null:
			result.append(card)
	return result


func _on_close_pressed() -> void:
	if _selecting:
		return
	close_requested.emit()


func _on_card_pressed(card: Control) -> void:
	if _selecting or card.disabled:
		return
	_selecting = true
	_set_interaction_enabled(false)
	var theme_id := str(card.get("theme_id"))
	var source_rect: Rect2 = card.call(&"source_rect")
	if _reduced_motion:
		theme_activated.emit(theme_id, source_rect)
		return
	_selection_tween = create_tween()
	_selection_tween.tween_interval(0.08)
	_selection_tween.tween_callback(func() -> void: theme_activated.emit(theme_id, source_rect))
	_selection_tween.finished.connect(_finish_selection_motion, CONNECT_ONE_SHOT)


func _set_interaction_enabled(enabled: bool) -> void:
	_selecting = not enabled
	close_button.disabled = not enabled
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for card in _cards.values():
		(card as Button).disabled = not enabled


func _stop_motion() -> void:
	_stop_selection_motion()
	_stop_entry_motion()
	_animation_active = false


func _stop_selection_motion() -> void:
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = null


func _finish_selection_motion() -> void:
	_selection_tween = null


func _stop_entry_motion() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_entry_tween = null


func _finish_entry_motion() -> void:
	_entry_tween = null


func _finish_animation(token: int) -> void:
	if token != _animation_token:
		return
	animation_player.pause()
	_animation_active = false
	_apply_enter_final_state()


func _settle_visible_state() -> void:
	_stop_entry_motion()
	_animation_token += 1
	animation_player.play(&"enter")
	animation_player.seek(animation_player.get_animation(&"enter").length, true)
	animation_player.pause()
	_animation_active = false
	_apply_enter_final_state()
	var cards := _ordered_cards()
	for index in cards.size():
		var card: Control = cards[index]
		card.modulate.a = 1.0
		card.position = _card_position(index)


func _apply_enter_final_state() -> void:
	backdrop.modulate.a = 1.0
	header.modulate.a = 1.0
	header.position.y = 0.0
	scroll.modulate.a = 1.0
	scroll.position.y = 0.0


func _apply_reset_state() -> void:
	backdrop.modulate.a = 0.0
	header.modulate.a = 0.0
	header.position.y = -10.0
	scroll.modulate.a = 0.0
	scroll.position.y = 24.0
