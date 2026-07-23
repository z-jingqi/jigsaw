class_name VirtualLevelGrid
extends RefCounted

signal level_selected(level_id: String)
signal card_visible(card: Control, view_model: Variant)
signal card_hidden(card: Control)

var _scroll: ScrollContainer
var _content: Control
var _card_scene: PackedScene
var _items: Array = []
var _columns := 2
var _gap := Vector2(12.0, 24.0)
var _card_size := Vector2(150.0, 180.0)
var _visible: Dictionary = {}
var _pool: Array[Control] = []


func _init(scroll: ScrollContainer, content: Control, card_scene: PackedScene) -> void:
	_scroll = scroll
	_content = content
	_card_scene = card_scene
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: render_visible())


func configure(items: Array, columns: int, gap: Vector2, card_size: Vector2) -> void:
	_items = items
	_columns = maxi(1, columns)
	_gap = gap
	_card_size = card_size
	_relayout()
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
				card_visible.emit(card, _items[int(index)])
	render_visible()


func render_visible() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_content):
		return
	var row_height := _card_size.y + _gap.y
	var first_row := maxi(0, int(floor(_scroll.scroll_vertical / maxf(1.0, row_height))) - 1)
	var last_row := mini(_row_count() - 1, int(ceil((_scroll.scroll_vertical + _scroll.size.y) / maxf(1.0, row_height))) + 1)
	var wanted: Dictionary = {}
	for row in range(first_row, last_row + 1):
		for column in _columns:
			var index := row * _columns + column
			if index < _items.size():
				wanted[index] = true
	for index in _visible.keys().duplicate():
		if not wanted.has(index):
			_release_index(int(index))
	for index in wanted:
		if not _visible.has(index):
			_acquire_index(int(index))


func scroll_to_item(level_id: String) -> void:
	for index in _items.size():
		if str(_item_value(_items[index], "level_id", "")) == level_id:
			var row := index / _columns
			_scroll.scroll_vertical = int(row * (_card_size.y + _gap.y))
			render_visible()
			return


func clear() -> void:
	for index in _visible.keys().duplicate():
		_release_index(int(index))
	for card in _pool:
		if is_instance_valid(card):
			card.queue_free()
	_pool.clear()


func column_count() -> int:
	return _columns


func active_card_count() -> int:
	return _visible.size()


func _relayout() -> void:
	var row_count := _row_count()
	var content_width := float(_columns) * _card_size.x + float(_columns - 1) * _gap.x
	_content.custom_minimum_size = Vector2(content_width, maxf(0.0, float(row_count) * _card_size.y + maxf(0.0, float(row_count - 1)) * _gap.y))


func _row_count() -> int:
	return ceili(float(_items.size()) / float(_columns))


func _acquire_index(index: int) -> void:
	var card: Control = _pool.pop_back() if not _pool.is_empty() else _card_scene.instantiate() as Control
	if card == null:
		return
	card.visible = true
	var button := card as Button
	button.disabled = false
	card.size = _card_size
	card.custom_minimum_size = _card_size
	card.position = _item_position(index)
	card.call(&"set_view_model", _items[index])
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
