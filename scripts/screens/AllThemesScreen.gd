class_name AllThemesScreen
extends Control

signal close_requested
signal theme_activated(theme_id: String, source_rect: Rect2, source_texture: Texture2D)

const ThemeCardScene := preload("res://scenes/ui/foundation/ThemeCard.tscn")
const FilledPawTexture := preload("res://assets/ui/common/progress_paw.svg")
const OutlinePawTexture := preload("res://assets/ui/common/progress_paw_outline.svg")

@export var motion_tokens: MotionTokens = preload("res://themes/motion_tokens.tres")

@onready var close_button: Button = $SafeArea/Content/Header/CloseButton
@onready var backdrop: ColorRect = $Backdrop
@onready var header: Control = $SafeArea/Content/Header
@onready var pager_clip: Control = $SafeArea/Content/PagerClip
@onready var previous_page: Control = $SafeArea/Content/PagerClip/PreviousPage
@onready var current_page: Control = $SafeArea/Content/PagerClip/CurrentPage
@onready var next_page: Control = $SafeArea/Content/PagerClip/NextPage
@onready var gesture_surface: Control = $SafeArea/Content/PagerClip/GestureSurface
@onready var page_indicator: HBoxContainer = $SafeArea/Content/PageIndicator
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _pager: AllThemesPagerController
var _page_capacity := 4
var _page_count := 0
var _page_index := 0
var _reduced_motion := false
var _selection_tween: Tween
var _entry_tween: Tween
var _selecting := false
var _animation_active := false
var _animation_token := 0
var _has_been_activated := false
var _pointer_active := false
var _activation_point := Vector2.ZERO
var _all_cards: Array[ThemeCard] = []


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	gesture_surface.gui_input.connect(_on_gesture_input)
	resized.connect(_apply_layout)
	_pager = AllThemesPagerController.new(self, motion_tokens)
	_pager.drag_updated.connect(_on_page_drag_updated)
	_pager.page_settled.connect(_on_page_settled)
	_pager.activation_requested.connect(_on_pointer_activation_requested)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.pause()
	_apply_reset_state()
	call_deferred("_apply_layout")


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	play_enter()


func navigation_exit(_context: Dictionary) -> void:
	_stop_motion()
	_pointer_active = false
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
	set_meta("reduced_motion", enabled)
	for card in _all_cards:
		card.set_reduced_motion(enabled)
	if enabled and _pager != null:
		_pager.finish_to_current()
		_settle_visible_state()


func set_view_model(view_model: Variant) -> void:
	var anchor_theme_id := _page_anchor_theme_id()
	_view_model = view_model
	if anchor_theme_id.is_empty():
		anchor_theme_id = str(_read_view_model("current_theme_id", ""))
	_configure_pages(anchor_theme_id)


func refresh_view_model(view_model: Variant) -> void:
	set_view_model(view_model)


func active_motion_count() -> int:
	var count := 1 if _animation_active else 0
	count += 1 if _selection_tween != null else 0
	count += 1 if _entry_tween != null else 0
	count += _pager.active_motion_count() if _pager != null else 0
	for card in _all_cards:
		count += card.active_motion_count()
	return count


func debug_state_snapshot() -> Dictionary:
	var phase := "idle"
	if _pager != null and _pager.active_motion_count() > 0:
		phase = "settling"
	elif _pointer_active and _pager != null and _pager.is_dragging():
		phase = "gesture"
	return {
		"page_index": _page_index,
		"page_count": _page_count,
		"page_capacity": _page_capacity,
		"gesture_progress": _pager.gesture_progress() if _pager != null else 0.0,
		"active_motion_count": active_motion_count(),
		"motion_phase": phase,
		"transition_kind": "all_themes_page" if phase != "idle" else "",
	}


func debug_page_card_ids() -> Array[String]:
	var result: Array[String] = []
	for child in current_page.get_children():
		if child is ThemeCard:
			result.append((child as ThemeCard).theme_id)
	return result


func play_enter() -> void:
	_stop_entry_motion()
	_apply_layout()
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
	get_tree().create_timer(animation_player.get_animation(&"enter").length).timeout.connect(
		_finish_animation.bind(token), CONNECT_ONE_SHOT
	)
	var cards := _current_page_cards()
	for card in cards:
		card.modulate.a = 0.0
		card.position.y = float(card.get_meta("layout_y", card.position.y)) + 12.0
	if cards.is_empty():
		return
	_entry_tween = create_tween().set_parallel(true)
	for index in cards.size():
		var card := cards[index]
		var row_index := floori(float(index) / float(maxi(1, _column_count())))
		var delay := minf(0.07, float(row_index) * 0.035)
		_entry_tween.tween_property(card, "modulate:a", 1.0, 0.20).set_delay(delay)
		(
			_entry_tween
			. tween_property(
				card, "position:y", float(card.get_meta("layout_y", card.position.y)), 0.20
			)
			. set_delay(delay)
		)
	_entry_tween.finished.connect(_finish_entry_motion, CONNECT_ONE_SHOT)


static func page_capacity_for_width(viewport_width: float) -> int:
	return 6 if viewport_width >= 1500.0 else 4


func _configure_pages(anchor_theme_id: String) -> void:
	if _pager == null or _view_model == null:
		return
	var cards := _card_models()
	_page_capacity = page_capacity_for_width(size.x)
	_page_count = ceili(float(cards.size()) / float(_page_capacity)) if not cards.is_empty() else 0
	var anchor_index := _find_card_index(anchor_theme_id)
	_page_index = (
		clampi(floori(float(anchor_index) / float(_page_capacity)), 0, maxi(0, _page_count - 1))
		if anchor_index >= 0
		else clampi(_page_index, 0, maxi(0, _page_count - 1))
	)
	_pager.configure(_page_count, _page_index, maxf(1.0, pager_clip.size.x))
	_rebuild_page_hosts()
	_rebuild_page_indicators()
	_apply_layout()


func _rebuild_page_hosts() -> void:
	for host in [previous_page, current_page, next_page]:
		_clear_page_host(host)
	_all_cards.clear()
	if _page_count <= 0:
		previous_page.visible = false
		current_page.visible = false
		next_page.visible = false
		return
	current_page.visible = true
	_populate_page(current_page, _page_index, true)
	var has_neighbours := _page_count > 1
	previous_page.visible = has_neighbours
	next_page.visible = has_neighbours
	if has_neighbours:
		_populate_page(previous_page, posmod(_page_index - 1, _page_count), false)
		_populate_page(next_page, posmod(_page_index + 1, _page_count), false)
	_configure_focus_order()
	_reset_page_visuals()


func _populate_page(host: Control, page: int, is_current: bool) -> void:
	var cards := _card_models()
	var start := page * _page_capacity
	var finish := mini(start + _page_capacity, cards.size())
	for index in range(start, finish):
		var card := ThemeCardScene.instantiate() as ThemeCard
		host.add_child(card)
		card.set_view_model(cards[index])
		card.set_reduced_motion(_reduced_motion)
		card.set_pointer_enabled(false)
		card.focus_mode = Control.FOCUS_ALL if is_current else Control.FOCUS_NONE
		if is_current:
			card.pressed.connect(_on_keyboard_card_pressed.bind(card))
		_all_cards.append(card)


func _clear_page_host(host: Control) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


func _apply_layout() -> void:
	if _pager == null or _view_model == null:
		return
	var desired_capacity := page_capacity_for_width(size.x)
	if desired_capacity != _page_capacity:
		_configure_pages(_page_anchor_theme_id())
		return
	_pager.set_page_width(maxf(1.0, pager_clip.size.x))
	for host in [previous_page, current_page, next_page]:
		_layout_page(host)
	_reset_page_visuals()


func _layout_page(host: Control) -> void:
	var columns := _column_count()
	var gap_x := 16.0 if columns == 2 else 18.0
	var gap_y := 18.0
	var available := host.size.max(Vector2.ONE)
	var card_width := (available.x - float(columns - 1) * gap_x) / float(columns)
	var row_height := (available.y - gap_y) * 0.5
	var card_height := minf(row_height, card_width * 1.58)
	var total_height := card_height * 2.0 + gap_y
	var start_y := maxf(0.0, (available.y - total_height) * 0.5)
	for index in host.get_child_count():
		var card := host.get_child(index) as Control
		if card == null:
			continue
		var column := index % columns
		var row := floori(float(index) / float(columns))
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = card.size
		card.position = Vector2(
			float(column) * (card_width + gap_x), start_y + float(row) * (card_height + gap_y)
		)
		card.set_meta("layout_y", card.position.y)


func _column_count() -> int:
	return 3 if _page_capacity == 6 else 2


func _reset_page_visuals() -> void:
	var width := maxf(1.0, pager_clip.size.x)
	previous_page.position = Vector2(-width, 0.0)
	current_page.position = Vector2.ZERO
	next_page.position = Vector2(width, 0.0)
	previous_page.modulate.a = 1.0
	current_page.modulate.a = 1.0
	next_page.modulate.a = 1.0


func _on_page_drag_updated(direction: int, progress: float, offset: float) -> void:
	var width := maxf(1.0, pager_clip.size.x)
	previous_page.position.x = -width + offset
	current_page.position.x = offset
	next_page.position.x = width + offset
	current_page.modulate.a = 1.0 - progress * 0.18
	previous_page.modulate.a = 0.76 + progress * 0.24 if direction < 0 else 1.0
	next_page.modulate.a = 0.76 + progress * 0.24 if direction > 0 else 1.0


func _on_page_settled(index: int, _committed: bool) -> void:
	_page_index = index
	_rebuild_page_hosts()
	_rebuild_page_indicators()
	_apply_layout()


func _rebuild_page_indicators() -> void:
	for child in page_indicator.get_children():
		page_indicator.remove_child(child)
		child.queue_free()
	page_indicator.visible = _page_count > 1
	if _page_count <= 1:
		return
	for page in _visible_indicator_pages():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(44.0, 44.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var paw := TextureRect.new()
		var active := page == _page_index
		var side := 38.0 if active else 28.0
		paw.texture = FilledPawTexture if active else OutlinePawTexture
		paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paw.set_anchors_preset(Control.PRESET_CENTER)
		paw.position = -Vector2(side, side) * 0.5
		paw.size = Vector2(side, side)
		slot.add_child(paw)
		page_indicator.add_child(slot)
	page_indicator.tooltip_text = "第 %d 页，共 %d 页" % [_page_index + 1, _page_count]
	page_indicator.set_meta("accessibility_name", page_indicator.tooltip_text)


func _visible_indicator_pages() -> Array[int]:
	var result: Array[int] = []
	var visible_count := mini(7, _page_count)
	var half_window := floori(float(visible_count) / 2.0)
	var start := clampi(_page_index - half_window, 0, _page_count - visible_count)
	for page in range(start, start + visible_count):
		result.append(page)
	return result


func _on_gesture_input(event: InputEvent) -> void:
	if _selecting or _page_count <= 0:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_begin_pointer(mouse.position)
		else:
			_end_pointer(mouse.position)
		gesture_surface.accept_event()
	elif event is InputEventMouseMotion and _pointer_active:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_activation_point = motion.position
			_pager.drag_by(motion.relative.x)
			gesture_surface.accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_end_pointer(touch.position)
		gesture_surface.accept_event()
	elif event is InputEventScreenDrag and _pointer_active:
		var drag := event as InputEventScreenDrag
		_activation_point = drag.position
		_pager.drag_by(drag.relative.x)
		gesture_surface.accept_event()


func _begin_pointer(pointer_position: Vector2) -> void:
	_pointer_active = true
	_activation_point = pointer_position
	_pager.begin()


func _end_pointer(pointer_position: Vector2) -> void:
	if not _pointer_active:
		return
	_activation_point = pointer_position
	_pager.end()
	_pointer_active = false


func _on_pointer_activation_requested() -> void:
	var global_point: Vector2 = (
		gesture_surface.get_global_transform_with_canvas() * _activation_point
	)
	for child in current_page.get_children():
		var card := child as ThemeCard
		if card != null and card.get_global_rect().has_point(global_point):
			_activate_card(card)
			return


func _on_keyboard_card_pressed(card: ThemeCard) -> void:
	_activate_card(card)


func _activate_card(card: ThemeCard) -> void:
	if _selecting or card.disabled:
		return
	_selecting = true
	_set_interaction_enabled(false)
	var source_rect := card.source_rect()
	var source_texture := card.source_texture()
	if _reduced_motion:
		theme_activated.emit(card.theme_id, source_rect, source_texture)
		return
	_selection_tween = create_tween()
	_selection_tween.tween_interval(0.08)
	_selection_tween.tween_callback(
		func() -> void: theme_activated.emit(card.theme_id, source_rect, source_texture)
	)
	_selection_tween.finished.connect(_finish_selection_motion, CONNECT_ONE_SHOT)


func _on_close_pressed() -> void:
	if _selecting:
		return
	if _pager != null:
		_pager.finish_to_current()
	close_requested.emit()


func _set_interaction_enabled(enabled: bool) -> void:
	_selecting = not enabled
	close_button.disabled = not enabled
	gesture_surface.mouse_filter = (
		Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	)
	for card in _all_cards:
		card.disabled = not enabled


func _configure_focus_order() -> void:
	var controls: Array[Control] = [close_button]
	for child in current_page.get_children():
		if child is ThemeCard:
			controls.append(child as Control)
	FocusNavigation.configure_linear(controls)


func _current_page_cards() -> Array[ThemeCard]:
	var result: Array[ThemeCard] = []
	for child in current_page.get_children():
		if child is ThemeCard:
			result.append(child as ThemeCard)
	return result


func _card_models() -> Array:
	var cards: Variant = _read_view_model("cards", [])
	return cards if cards is Array else []


func _find_card_index(theme_id: String) -> int:
	if theme_id.is_empty():
		return -1
	var cards := _card_models()
	for index in cards.size():
		if str(_read_card(cards[index], "theme_id", "")) == theme_id:
			return index
	return -1


func _page_anchor_theme_id() -> String:
	if _view_model == null or _page_count <= 0:
		return ""
	var cards := _card_models()
	var index := _page_index * _page_capacity
	if index < 0 or index >= cards.size():
		return ""
	return str(_read_card(cards[index], "theme_id", ""))


func _read_view_model(field: String, fallback: Variant) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	if _view_model == null:
		return fallback
	var value: Variant = _view_model.get(field)
	return fallback if value == null else value


func _read_card(card: Variant, field: String, fallback: Variant) -> Variant:
	if card is Dictionary:
		return card.get(field, fallback)
	if card == null:
		return fallback
	var value: Variant = card.get(field)
	return fallback if value == null else value


func _stop_motion() -> void:
	_stop_selection_motion()
	_stop_entry_motion()
	if _pager != null:
		_pager.cancel_motion()
	_animation_active = false
	_pointer_active = false


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
	_reset_page_visuals()
	for card in _current_page_cards():
		card.modulate.a = 1.0
		card.position.y = float(card.get_meta("layout_y", card.position.y))


func _apply_enter_final_state() -> void:
	backdrop.modulate.a = 1.0
	header.modulate.a = 1.0
	header.position.y = 0.0
	pager_clip.modulate.a = 1.0
	pager_clip.position.y = 0.0
	page_indicator.modulate.a = 1.0


func _apply_reset_state() -> void:
	backdrop.modulate.a = 0.0
	header.modulate.a = 0.0
	header.position.y = -10.0
	pager_clip.modulate.a = 0.0
	pager_clip.position.y = 24.0
	page_indicator.modulate.a = 0.0


func _exit_tree() -> void:
	_stop_motion()
