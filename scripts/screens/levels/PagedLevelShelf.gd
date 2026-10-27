extends Control
## Bare two-by-two boxes; only bounded box layers move across the fixed page.
signal level_selected(level_id: String)
signal card_visible(card: Control, view_model: Variant)
signal card_hidden(card: Control)
signal page_changed(index: int)
signal gesture_progress(visual_page: float)
signal gesture_finished(committed: bool, target: int)

const CardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const PAGE_SIZE := 4
var _items: Array = []
var _pages: Dictionary = {}
var _page := 0
var _visual_page := 0.0
const Gesture := preload("res://scripts/ui/navigation/PagingGesture.gd")
var _gesture := Gesture.new()
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
var _opening_card := false
var _hidden_id := ""
var _interactive := true
var _reduced := false
var _tween: Tween
var _configured := false
var _pointer := -2
var _dragging := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	_layout_pages()


func configure(items: Array, focus_level_id := "") -> void:
	_items = items
	if not _configured:
		_page = 0
		for i in _items.size():
			if str(_items[i].level_id) == focus_level_id:
				_page = i / PAGE_SIZE
				break
		_visual_page = float(_page)
		_configured = true
	_page = clampi(_page, 0, maxi(0, page_count() - 1))
	_ensure_pages()
	_refresh_models()
	page_changed.emit(_page)


func refresh_items(items: Array) -> void:
	_items = items
	if not _opening_card:
		settle()
	_page = clampi(_page, 0, maxi(0, page_count() - 1))
	_ensure_pages()
	_refresh_models()
	page_changed.emit(_page)


func page_count() -> int:
	return ceili(float(_items.size()) / PAGE_SIZE)


func page_index() -> int:
	return _page


func request_page(index: int) -> void:
	if _pointer != -2:
		_set_card_interaction(false)
	Arena.release(self)
	if not _interactive or page_count() == 0:
		return
	_kill_motion()
	_pointer = -2
	_dragging = false
	_opening_card = false
	_page = clampi(index, 0, page_count() - 1)
	_ensure_pages()
	page_changed.emit(_page)
	_set_card_interaction(_interactive)
	if _reduced or is_equal_approx(_visual_page, float(_page)):
		_visual_page = float(_page)
		_finish_page()
		return
	# A new intent owns the current presentation position, never a queued endpoint.
	var duration := clampf(absf(float(_page) - _visual_page) * 0.32, 0.10, 0.42)
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_visual_page, _visual_page, float(_page), duration)
	_tween.finished.connect(_finish_page)


func _kill_motion() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _set_visual_page(value: float) -> void:
	var previous_center := roundi(_visual_page)
	_visual_page = value
	if roundi(value) != previous_center:
		_ensure_pages()
	else:
		_position_layers()


func _position_layers() -> void:
	for index in _pages:
		var layer: Control = _pages[index]
		layer.position = Vector2((float(index) - _visual_page) * size.x, 0)
		layer.visible = absf(float(index) - _visual_page) < 1.0
	_set_card_interaction(_interactive and not _dragging)


func settle() -> void:
	Arena.release(self)
	_kill_motion()
	_pointer = -2
	_dragging = false
	_page = clampi(_page, 0, maxi(0, page_count() - 1))
	_visual_page = float(_page)
	_ensure_pages()
	_layout_pages()
	_set_card_interaction(_interactive)
	page_changed.emit(_page)


func _finish_page() -> void:
	_tween = null
	_visual_page = float(_page)
	_ensure_pages()
	_layout_pages()
	_set_card_interaction(_interactive)
	for card in visible_cards():
		card_visible.emit(card, card.get("_view_model"))


func set_interaction_enabled(enabled: bool) -> void:
	_interactive = enabled
	if not enabled:
		stop_motion()
	_set_card_interaction(enabled)
	if (
		enabled
		and not _opening_card
		and _hidden_id.is_empty()
		and not is_equal_approx(_visual_page, float(_page))
	):
		request_page(_page)


func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	if enabled:
		settle()
	for layer: Control in _pages.values():
		for card in layer.get_children():
			card.set_reduced_motion(enabled)


func _ensure_pages() -> void:
	var wanted: Array[int] = []
	var center := roundi(_visual_page)
	for index in [center - 1, center + 1, center, _page]:
		if index >= 0 and index < page_count() and not wanted.has(index):
			wanted.append(index)
	for index in _pages.keys():
		var expected := mini(PAGE_SIZE, maxi(0, _items.size() - int(index) * PAGE_SIZE))
		if not wanted.has(int(index)) or _pages[index].get_child_count() != expected:
			var old: Control = _pages[index]
			for card in old.get_children():
				card_hidden.emit(card)
			remove_child(old)
			old.queue_free()
			_pages.erase(index)
	for index in wanted:
		if _pages.has(index):
			continue
		var layer := Control.new()
		layer.name = "BoxPage%d" % index
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		_pages[index] = layer
		for slot in PAGE_SIZE:
			var item_index := index * PAGE_SIZE + slot
			if item_index >= _items.size():
				break
			var card := CardScene.instantiate() as Control
			card.set_meta("shelf_layout", true)
			card.set_view_model(_items[item_index])
			card.pressed.connect(_on_card_pressed.bind(card))
			layer.add_child(card)
			card.set_reduced_motion(_reduced)
			card.set_box_transition_hidden(str(card.level_id) == _hidden_id)
			card.set_shelf_interaction_enabled(
				_interactive and absf(index - _visual_page) < 1.0 and not _dragging
			)
			if index == _page:
				card_visible.emit(card, _items[item_index])
	_layout_pages()


func _refresh_models() -> void:
	for index in _pages:
		var layer: Control = _pages[index]
		for slot in layer.get_child_count():
			var item_index := int(index) * PAGE_SIZE + slot
			if item_index < _items.size():
				var card := layer.get_child(slot)
				card.set_view_model(_items[item_index])
				card.set_box_transition_hidden(str(card.level_id) == _hidden_id)


func _layout_pages() -> void:
	var native := Metrics.unit(get_viewport_rect().size) if is_inside_tree() else 1.0
	var gap := Metrics.GAP * native
	# Tall phones leave breathing room below the group, not between each box
	# rows. Compact screens still use their available half-height.
	var usable_card_width := maxf(44 * native, (size.x - gap - 12 * native) * 0.5)
	var row_height := minf(size.y * 0.5, usable_card_width / 0.75 + 55 * native)
	var card_height := maxf(44 * native, row_height - 24 * native)
	var card_width := minf(usable_card_width, card_height * 0.67)
	var left := (size.x - card_width * 2 - gap) * 0.5
	for index in _pages:
		var layer: Control = _pages[index]
		layer.size = size
		layer.position = Vector2((float(index) - _visual_page) * size.x, 0)
		layer.visible = absf(float(index) - _visual_page) < 1.0
		for slot in layer.get_child_count():
			var card: Control = layer.get_child(slot)
			card.custom_minimum_size = Vector2(card_width, card_height)
			card.size = Vector2(card_width, card_height)
			card.position = Vector2(
				left + (slot % 2) * (card_width + gap),
				(slot / 2 + 1) * row_height - 9 * native - card_height
			)
	_set_card_interaction(_interactive and not _dragging)
	queue_redraw()


func _on_resized() -> void:
	# The scalar is normalized to page width, so a viewport change can reflow
	# both visible layers without forcing either one to its target endpoint.
	stop_motion()
	_layout_pages()
	if _interactive and not _opening_card and _hidden_id.is_empty():
		request_page(_page)


func _set_card_interaction(enabled: bool) -> void:
	for index in _pages:
		for card in _pages[index].get_children():
			card.set_shelf_interaction_enabled(enabled and _pages[index].visible)


func _on_card_pressed(card: Control) -> void:
	if not _interactive or _dragging or card.disabled:
		return
	_kill_motion()
	for index in _pages:
		if card.get_parent() == _pages[index]:
			_page = int(index)
			break
	_opening_card = true
	page_changed.emit(_page)
	# Leave the layer at its exact visible offset until the coordinator reads it.
	level_selected.emit(str(card.level_id))


func _input(event: InputEvent) -> void:
	if Arena.block_secondary(get_viewport(), event):
		get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _interactive or not is_visible_in_tree():
		return
	var navigator := get_tree().root.get_node_or_null("Game/AppNavigator")
	if navigator != null and navigator.current_route() != &"levels":
		return
	var native := Clean.canvas_scale(get_viewport_rect().size, get_window())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_swipe(event.position, -1, native)
		elif _pointer == -1:
			_end_swipe(event.position, native)
	elif event is InputEventMouseMotion and _pointer == -1:
		_move_swipe(event.position, native)
	elif event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			_cancel_swipe()
		elif event.pressed:
			_begin_swipe(event.position, event.index, native)
		elif event.index == _pointer:
			_end_swipe(event.position, native)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move_swipe(event.position, native)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		stop_motion()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		if _interactive and not _opening_card and _hidden_id.is_empty():
			request_page(_page)


func _begin_swipe(point: Vector2, pointer: int, native: float) -> void:
	if _pointer != -2:
		_cancel_swipe()
		return
	if not get_global_rect().has_point(point):
		return
	if Arena.is_edge_candidate(self, point, native) or not Arena.reserve(self, pointer):
		return
	_kill_motion()
	_gesture.begin(point, _visual_page, size.x, native, page_count())
	_page = _gesture.origin_page
	page_changed.emit(_page)
	_pointer = pointer
	_dragging = false
	_set_card_interaction(_interactive)


func _move_swipe(point: Vector2, _native: float) -> void:
	if not Arena.owns(self, _pointer):
		return
	var value: float = _gesture.move(point)
	if _gesture.axis == 2:
		_set_card_interaction(false)
		return
	if _gesture.axis == 1:
		_dragging = true
		_set_card_interaction(false)
		_set_visual_page(value)
		gesture_progress.emit(value)
		get_viewport().set_input_as_handled()


func _end_swipe(point: Vector2, _native: float) -> void:
	Arena.release(self)
	_pointer = -2
	if _gesture.axis == 0:
		call_deferred("_resume_after_tap")
		return
	var target: int = _gesture.release_target(point)
	gesture_finished.emit(target != _gesture.origin_page, target)
	_dragging = false
	# Consume the release before GUI dispatch: a completed/cancelled drag is not a tap.
	get_viewport().set_input_as_handled()
	request_page(target)


func _cancel_swipe() -> void:
	if _pointer == -2:
		return
	var target: int = _gesture.origin_page
	gesture_finished.emit(false, target)
	_set_card_interaction(false)
	_pointer = -2
	_dragging = false
	request_page(target)


func _resume_after_tap() -> void:
	if _interactive and not _opening_card and _hidden_id.is_empty() and _tween == null:
		request_page(_page)


func visible_cards() -> Array[Control]:
	var result: Array[Control] = []
	for layer: Control in _pages.values():
		if layer.visible:
			for card in layer.get_children():
				result.append(card)
	return result


func card_for_level_id(level_id: String) -> Control:
	for card in visible_cards():
		if str(card.level_id) == level_id:
			return card
	return null


func set_box_transition_source(level_id: String, hidden: bool) -> void:
	var restoring := not hidden and _hidden_id == level_id
	if hidden:
		_hidden_id = level_id
	elif _hidden_id == level_id:
		_hidden_id = ""
		_opening_card = false
	for layer: Control in _pages.values():
		for card in layer.get_children():
			card.set_box_transition_hidden(str(card.level_id) == _hidden_id)
	if restoring and _interactive and not is_equal_approx(_visual_page, float(_page)):
		request_page(_page)


func prepare_box_return(level_id: String) -> void:
	if _hidden_id == level_id:
		for index in _items.size():
			if str(_items[index].level_id) == level_id:
				_page = index / PAGE_SIZE
				break
		settle()


func stop_motion() -> void:
	Arena.release(self)
	if _pointer != -2:
		_page = _gesture.origin_page
		gesture_finished.emit(false, _page)
	_kill_motion()
	_pointer = -2
	_dragging = false
	_set_card_interaction(false)
	_set_card_interaction(_interactive)


func active_motion_count() -> int:
	return int(_tween != null)


func debug_snapshot() -> Dictionary:
	var positions := {}
	for index in _pages:
		positions[str(index)] = _pages[index].position
	return {
		"page": _page,
		"count": page_count(),
		"pending": -1,
		"visual_page": _visual_page,
		"dragging": _dragging,
		"shelf_rects": [],
		"box_layer_positions": positions,
		"allocated_pages": _pages.size(),
		"active_motion_count": active_motion_count()
	}


func dispose() -> void:
	Arena.release(self)
	if _tween != null:
		_tween.kill()
		_tween = null
