class_name VirtualLevelGrid
extends RefCounted

signal level_selected(level_id: String)
signal card_visible(card: Control, view_model: Variant)
signal card_hidden(card: Control)

const CREATION_BUDGET_USEC := 3000

var _scroll: ScrollContainer
var _content: Control
var _card_scene: PackedScene
var _items: Array = []
var _columns := 2
var _gap := Vector2(12.0, 24.0)
var _card_size := Vector2(150.0, 180.0)
var _footer_space := 0.0
var _visible: Dictionary = {}
var _pool: Array[Control] = []
var _pending: Array[int] = []
var _pending_tree: SceneTree
var _scroll_changed: Callable
var _hidden_box_level_id := ""


func _init(scroll: ScrollContainer, content: Control, card_scene: PackedScene) -> void:
	_scroll = scroll
	_content = content
	_card_scene = card_scene
	_scroll_changed = render_visible.unbind(1)
	_scroll.get_v_scroll_bar().value_changed.connect(_scroll_changed)


func configure(
	items: Array, columns: int, gap: Vector2, card_size: Vector2, footer_space := 0.0
) -> void:
	var retain_position := (
		not _items.is_empty() and (columns != _columns or card_size != _card_size)
	)
	var old_row_height := maxf(1.0, _card_size.y + _gap.y)
	var top_index := int(floor(_scroll.scroll_vertical / old_row_height)) * _columns
	var bar := _scroll.get_v_scroll_bar()
	var at_bottom := (
		_scroll.scroll_vertical > 0 and _scroll.scroll_vertical >= bar.max_value - bar.page - 1
	)
	_items = items
	_columns = maxi(1, columns)
	_gap = gap
	_card_size = card_size
	_footer_space = maxf(0.0, footer_space)
	_relayout()
	for index in _visible:
		var card: Control = _visible[index]
		card.custom_minimum_size = _card_size
		card.size = _card_size
		card.position = _item_position(int(index))
	if retain_position:
		var target := int(floor(float(top_index) / _columns) * (_card_size.y + _gap.y))
		if at_bottom:
			target = maxi(0, int(_content.custom_minimum_size.y - _scroll.size.y))
		_scroll.set_deferred("scroll_vertical", target)
	render_visible()


func refresh_items(items: Array) -> void:
	_items = items
	for index in _visible.keys():
		if int(index) >= _items.size():
			_release_index(int(index))
		else:
			var card: Control = _visible[index]
			if is_instance_valid(card):
				card.call(&"set_view_model", _items[int(index)])
				_apply_box_transition_state(card)
				card_visible.emit(card, _items[int(index)])
	render_visible()


func render_visible() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_content):
		return
	var row_height := _card_size.y + _gap.y
	var first_row := maxi(0, int(floor(_scroll.scroll_vertical / maxf(1.0, row_height))) - 1)
	var last_row := mini(
		_row_count() - 1,
		int(ceil((_scroll.scroll_vertical + _scroll.size.y) / maxf(1.0, row_height))) + 1
	)
	var wanted: Dictionary = {}
	for row in range(first_row, last_row + 1):
		for column in _columns:
			var index := row * _columns + column
			if index < _items.size():
				wanted[index] = true
	for index in _visible.keys().duplicate():
		if not wanted.has(index):
			_release_index(int(index))
	_pending.clear()
	for index in wanted:
		if not _visible.has(index):
			_pending.append(int(index))
	if _pending_tree == null:
		_render_pending()


func scroll_to_item(level_id: String) -> void:
	for index in _items.size():
		if str(_item_value(_items[index], "level_id", "")) == level_id:
			var row := index / _columns
			_scroll.scroll_vertical = int(row * (_card_size.y + _gap.y))
			render_visible()
			return


func clear() -> void:
	_pending.clear()
	if (
		is_instance_valid(_pending_tree)
		and _pending_tree.process_frame.is_connected(_render_pending)
	):
		_pending_tree.process_frame.disconnect(_render_pending)
	_pending_tree = null
	for index in _visible.keys().duplicate():
		_release_index(int(index))
	for card in _pool:
		if is_instance_valid(card):
			card.queue_free()
	_pool.clear()
	_items = []


func _render_pending() -> void:
	_pending_tree = null
	if not is_instance_valid(_scroll) or not _scroll.is_inside_tree():
		return
	var started := Time.get_ticks_usec()
	while not _pending.is_empty():
		_acquire_index(_pending.pop_front())
		if Time.get_ticks_usec() - started >= CREATION_BUDGET_USEC:
			break
	if not _pending.is_empty():
		_pending_tree = _scroll.get_tree()
		_pending_tree.process_frame.connect(_render_pending, CONNECT_ONE_SHOT)


func column_count() -> int:
	return _columns


func allocated_card_count() -> int:
	return _visible.size() + _pool.size()


func dispose() -> void:
	clear()
	if is_instance_valid(_scroll):
		var bar := _scroll.get_v_scroll_bar()
		if bar.value_changed.is_connected(_scroll_changed):
			bar.value_changed.disconnect(_scroll_changed)
	_scroll_changed = Callable()
	_items = []
	_scroll = null
	_content = null


func active_card_count() -> int:
	return _visible.size()


func visible_cards() -> Array[Control]:
	var result: Array[Control] = []
	var indices := _visible.keys()
	indices.sort()
	for index in indices:
		var card := _visible[index] as Control
		if is_instance_valid(card):
			result.append(card)
	return result


func card_for_level_id(level_id: String) -> Control:
	for card in visible_cards():
		if str(card.get("level_id")) == level_id:
			return card
	return null


func set_box_transition_source(level_id: String, hidden: bool) -> void:
	if hidden:
		_hidden_box_level_id = level_id
	elif _hidden_box_level_id == level_id:
		_hidden_box_level_id = ""
	for card in visible_cards():
		_apply_box_transition_state(card)


func _apply_box_transition_state(card: Control) -> void:
	# This grid also hosts album cards, which have no box presentation.
	if card.has_method(&"set_box_transition_hidden"):
		card.call(&"set_box_transition_hidden", str(card.get("level_id")) == _hidden_box_level_id)


func _relayout() -> void:
	var row_count := _row_count()
	_content.custom_minimum_size = Vector2(
		0.0,
		maxf(
			0.0,
			(
				float(row_count) * _card_size.y
				+ maxf(0.0, float(row_count - 1)) * _gap.y
				+ _footer_space
			)
		)
	)


func _row_count() -> int:
	return ceili(float(_items.size()) / float(_columns))


func _acquire_index(index: int) -> void:
	var card: Control = (
		_pool.pop_back() if not _pool.is_empty() else _card_scene.instantiate() as Control
	)
	if card == null:
		return
	card.visible = true
	var button := card as Button
	button.disabled = false
	card.custom_minimum_size = _card_size
	card.size = _card_size
	card.position = _item_position(index)
	card.call(&"set_view_model", _items[index])
	_apply_box_transition_state(card)
	if not card.has_meta(&"virtual_grid_wired"):
		button.pressed.connect(_on_card_pressed.bind(button))
		card.set_meta(&"virtual_grid_wired", true)
	_content.add_child(card)
	_visible[index] = card
	card_visible.emit(card, _items[index])


func _release_index(index: int) -> void:
	var card: Control = _visible.get(index)
	_visible.erase(index)
	if not is_instance_valid(card):
		return
	card_hidden.emit(card)
	card.get_parent().remove_child(card)
	card.visible = false
	_pool.append(card)


func _item_position(index: int) -> Vector2:
	var row := index / _columns
	var column := index % _columns
	return Vector2(float(column) * (_card_size.x + _gap.x), float(row) * (_card_size.y + _gap.y))


func _on_card_pressed(card: Button) -> void:
	if card.disabled:
		return
	level_selected.emit(str(card.get("level_id")))


func _item_value(item: Variant, field: String, fallback: Variant) -> Variant:
	return item.get(field, fallback) if item is Dictionary else item.get(field)
