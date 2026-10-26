extends Control
## Fixed ledges; only the bounded two-by-two box layers move between pages.
signal level_selected(level_id: String)
signal card_visible(card: Control, view_model: Variant)
signal card_hidden(card: Control)
signal page_changed(index: int)

const CardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const PAGE_SIZE := 4
var _items: Array = []
var _pages: Dictionary = {}
var _page := 0
var _pending_page := -1
var _hidden_id := ""
var _interactive := true
var _reduced := false
var _tween: Tween
var _configured := false
var _pointer := -2
var _start := Vector2.ZERO
var _dragging := false
var _shelves: Array[Rect2] = []


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
		_configured = true
	_page = clampi(_page, 0, maxi(0, page_count() - 1))
	_ensure_pages()
	_refresh_models()
	page_changed.emit(_page)


func refresh_items(items: Array) -> void:
	_items = items
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
	if not _interactive or page_count() < 2:
		return
	var target := clampi(index, 0, page_count() - 1)
	if _tween != null:
		_pending_page = target
		return
	if target == _page:
		return
	var previous := _page
	_page = target
	_ensure_pages(previous)
	page_changed.emit(_page)
	if _reduced:
		_finish_page()
		return
	var direction := signi(_page - previous)
	var old_layer: Control = _pages[previous]
	var new_layer: Control = _pages[_page]
	old_layer.visible = true
	new_layer.visible = true
	old_layer.position = Vector2.ZERO
	new_layer.position = Vector2(direction * size.x, 0)
	_set_card_interaction(false)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(old_layer, "position:x", -direction * size.x, 0.32)
	_tween.tween_property(new_layer, "position:x", 0.0, 0.32)
	_tween.finished.connect(_finish_page)


func settle() -> void:
	var previous := _page
	if _tween != null:
		_tween.kill()
		_tween = null
	if _pending_page >= 0:
		_page = clampi(_pending_page, 0, maxi(0, page_count() - 1))
	_pending_page = -1
	_pointer = -2
	_dragging = false
	_ensure_pages()
	_layout_pages()
	_set_card_interaction(_interactive)
	if previous != _page:
		page_changed.emit(_page)


func _finish_page() -> void:
	_tween = null
	_ensure_pages()
	_layout_pages()
	_set_card_interaction(_interactive)
	for card in visible_cards():
		card_visible.emit(card, card.get("_view_model"))
	if _pending_page >= 0:
		var target := _pending_page
		_pending_page = -1
		request_page(target)


func set_interaction_enabled(enabled: bool) -> void:
	_interactive = enabled
	if not enabled:
		settle()
	_set_card_interaction(enabled and _tween == null)


func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled
	if enabled:
		settle()
	for layer: Control in _pages.values():
		for card in layer.get_children():
			card.set_reduced_motion(enabled)


func _ensure_pages(extra := -1) -> void:
	var wanted: Array[int] = []
	for index in [_page - 1, _page + 1, extra, _page]:
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
			card.set_shelf_interaction_enabled(_interactive and index == _page and _tween == null)
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
	var native := (
		Clean.canvas_scale(get_viewport_rect().size, get_window()) if is_inside_tree() else 1.0
	)
	var gap := 18.0 * native
	var row_height := size.y * 0.5
	var card_height := maxf(44 * native, row_height - 24 * native)
	var card_width := minf((size.x - gap - 12 * native) * 0.5, card_height * 0.67)
	var left := (size.x - card_width * 2 - gap) * 0.5
	_shelves.clear()
	for row in 2:
		_shelves.append(
			Rect2(2 * native, (row + 1) * row_height - 9 * native, size.x - 4 * native, 4 * native)
		)
	for index in _pages:
		var layer: Control = _pages[index]
		layer.size = size
		if _tween == null:
			layer.position = Vector2.ZERO
			layer.visible = int(index) == _page
		for slot in layer.get_child_count():
			var card: Control = layer.get_child(slot)
			card.custom_minimum_size = Vector2(card_width, card_height)
			card.size = Vector2(card_width, card_height)
			card.position = Vector2(
				left + (slot % 2) * (card_width + gap),
				(slot / 2 + 1) * row_height - 9 * native - card_height
			)
	queue_redraw()


func _draw() -> void:
	if _items.is_empty():
		return
	for shelf in _shelves:
		draw_rect(shelf, Color("F5EFE4"))
		draw_line(
			shelf.position,
			Vector2(shelf.end.x, shelf.position.y),
			Color("FFFCF6"),
			maxf(1, shelf.size.y * 0.25)
		)
		draw_line(
			Vector2(shelf.position.x, shelf.end.y),
			shelf.end,
			Color("DDD4C4"),
			maxf(1, shelf.size.y * 0.2)
		)


func _on_resized() -> void:
	settle()


func _set_card_interaction(enabled: bool) -> void:
	for index in _pages:
		for card in _pages[index].get_children():
			card.set_shelf_interaction_enabled(enabled and int(index) == _page)


func _on_card_pressed(card: Control) -> void:
	if _interactive and _tween == null and not _dragging and not card.disabled:
		level_selected.emit(str(card.level_id))


func _input(event: InputEvent) -> void:
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
		if event.pressed:
			_begin_swipe(event.position, event.index, native)
		elif event.index == _pointer:
			_end_swipe(event.position, native)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_move_swipe(event.position, native)


func _begin_swipe(point: Vector2, pointer: int, native: float) -> void:
	if point.x < 24.0 * native or not get_global_rect().has_point(point):
		return
	_start = point
	_pointer = pointer
	_dragging = false


func _move_swipe(point: Vector2, native: float) -> void:
	var delta := point - _start
	if absf(delta.x) > 12 * native and absf(delta.x) > absf(delta.y):
		_dragging = true
		_set_card_interaction(false)
		get_viewport().set_input_as_handled()


func _end_swipe(point: Vector2, native: float) -> void:
	_pointer = -2
	if not _dragging:
		return
	_dragging = false
	if absf(point.x - _start.x) > 36 * native:
		request_page(_page + (-1 if point.x > _start.x else 1))
	_set_card_interaction(_interactive and _tween == null)
	get_viewport().set_input_as_handled()


func visible_cards() -> Array[Control]:
	var result: Array[Control] = []
	if _pages.has(_page):
		for card in _pages[_page].get_children():
			result.append(card)
	return result


func card_for_level_id(level_id: String) -> Control:
	for card in visible_cards():
		if str(card.level_id) == level_id:
			return card
	return null


func set_box_transition_source(level_id: String, hidden: bool) -> void:
	if hidden:
		_hidden_id = level_id
	elif _hidden_id == level_id:
		_hidden_id = ""
	for layer: Control in _pages.values():
		for card in layer.get_children():
			card.set_box_transition_hidden(str(card.level_id) == _hidden_id)


func active_motion_count() -> int:
	return int(_tween != null)


func debug_snapshot() -> Dictionary:
	var positions := {}
	for index in _pages:
		positions[str(index)] = _pages[index].position
	return {
		"page": _page,
		"count": page_count(),
		"pending": _pending_page,
		"shelf_rects": _shelves,
		"box_layer_positions": positions,
		"allocated_pages": _pages.size(),
		"active_motion_count": active_motion_count()
	}


func dispose() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
