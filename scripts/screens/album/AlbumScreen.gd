class_name AlbumScreen
extends Control

signal back_requested
signal theme_selected(theme_id: String)
signal all_requested
signal artwork_selected(theme_id: String, level_id: String)

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const VirtualGrid := preload("res://scripts/screens/levels/VirtualLevelGrid.gd")
const CardScene := preload("res://scenes/screens/album/AlbumCard.tscn")

@onready var scroll: NaturalScrollContainer = $Scroll
@onready var grid: Control = $Scroll/Grid
var _model: Dictionary = {}
var _cards_by_key: Dictionary = {}
var _grid: VirtualLevelGrid
var _thumbnails: AlbumThumbnailLoader
var _active := true
var _render_version := 0


func _ready() -> void:
	Clean.icon_button($BackButton)
	Clean.icon_button($AllButton)
	_grid = VirtualGrid.new(scroll, grid, CardScene)
	_grid.level_selected.connect(_select_card)
	_grid.card_visible.connect(_watch_card)
	_grid.card_hidden.connect(_release_card)
	$BackButton.pressed.connect(back_requested.emit)
	$AllButton.pressed.connect(all_requested.emit)
	resized.connect(_layout)
	$Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func set_thumbnail_loader(loader: AlbumThumbnailLoader) -> void:
	_thumbnails = loader
	for card in _grid.visible_cards():
		_watch_card(card, {})


func navigation_enter(payload: Dictionary, _context: Dictionary) -> void:
	render(payload.get("view_model", {}), int(payload.get("scroll_position", 0)))


func render(model: Dictionary, position_y := 0) -> void:
	_render_version += 1
	_grid.clear()
	_model = model
	_cards_by_key.clear()
	for card in model.cards:
		_cards_by_key[str(card.level_id)] = card
	scroll.stop_motion()
	scroll.scroll_vertical = 0
	$Title.text = str(model.title)
	$Summary.text = str(model.summary)
	$BackButton.accessibility_name = str(model.back_label)
	$AllButton.text = ""
	$AllButton.accessibility_name = str(model.all_label)
	$AllButton.visible = str(model.kind) == "themes"
	$EmptyLabel.text = str(model.empty_label)
	$EmptyLabel.visible = model.cards.is_empty()
	_layout()
	get_tree().process_frame.connect(
		_restore_scroll.bind(position_y, _render_version), CONNECT_ONE_SHOT
	)


func navigation_set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	scroll.set_interaction_enabled(enabled)
	for card in _grid.visible_cards():
		if enabled:
			_watch_card(card, {})
		else:
			_release_card(card)


func navigation_prepare_transition() -> void:
	scroll.stop_motion()


func navigation_exit(_context: Dictionary) -> void:
	scroll.stop_motion()
	_grid.clear()


func scroll_position() -> int:
	return scroll.scroll_vertical


func active_motion_count() -> int:
	return int(scroll.is_physics_processing())


func debug_state_snapshot() -> Dictionary:
	var loaded := 0
	for card in _grid.visible_cards():
		loaded += int(card.image_ready())
	return {
		"kind": _model.get("kind", ""),
		"theme_id": _model.get("theme_id", ""),
		"total": _model.get("total", 0),
		"item_count": _model.get("cards", []).size(),
		"active_cards": _grid.active_card_count(),
		"allocated_cards": _grid.allocated_card_count(),
		"loaded_cards": loaded,
		"columns": _grid.column_count(),
		"scroll_position": scroll_position(),
		"thumbnails": _thumbnails.debug_state_snapshot() if is_instance_valid(_thumbnails) else {},
	}


func _restore_scroll(position_y: int, version: int) -> void:
	if is_inside_tree() and version == _render_version:
		scroll.scroll_vertical = position_y
		_grid.render_visible()


func _select_card(key: String) -> void:
	var card: Dictionary = _cards_by_key.get(key, {})
	if card.is_empty():
		return
	if str(_model.kind) == "themes":
		theme_selected.emit(str(card.theme_id))
	else:
		artwork_selected.emit(str(card.theme_id), str(card.artwork_id))


func _watch_card(card: Control, _data: Variant) -> void:
	if _active and is_instance_valid(_thumbnails):
		_thumbnails.watch(card as AlbumCard)


func _release_card(card: Control) -> void:
	if is_instance_valid(_thumbnails):
		_thumbnails.unwatch(card as AlbumCard)


func _layout() -> void:
	if not is_node_ready() or _model.is_empty():
		return
	var portrait := size.x < size.y
	var u := minf(size.x / 390.0, size.y / 700.0) if portrait else size.y / 390.0
	var margin := Clean.SPACE_24 * u
	var safe := Clean.safe_insets(size)
	Buttons.place_navigation($BackButton, self)
	$Title.position = Vector2(margin, 76 * u)
	$Title.size = Vector2(size.x - margin * 2, 48 * u)
	Clean.label($Title, roundi(30 * u), false)
	$Summary.position = Vector2(margin, $Title.position.y + $Title.size.y + Clean.SPACE_8 * u)
	$Summary.size = Vector2(size.x - margin * 2, 27 * u)
	Clean.label($Summary, roundi(20 * u), true)
	Buttons.place_navigation($AllButton, self, true)
	for item in [$Title, $Summary]:
		item.position.y += safe.y
	var top: float = $Summary.position.y + $Summary.size.y + Clean.SPACE_24 * u
	scroll.position = Vector2(margin, top)
	scroll.size = Vector2(size.x - margin * 2, maxf(1, size.y - top - Clean.SPACE_24 * u - safe.w))
	$EmptyLabel.position = scroll.position
	$EmptyLabel.size = scroll.size
	$EmptyLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Clean.label($EmptyLabel, roundi(18 * u), true)
	$EmptyLabel.add_theme_font_size_override("font_size", roundi(18 * u))
	var columns := 2 if portrait else 4
	var gap := Vector2.ONE * Clean.SPACE_16 * u
	if not portrait:
		var fitting_width := scroll.size.y / (1.0 / 0.75 + 0.36)
		columns = maxi(columns, ceili((scroll.size.x + gap.x) / (fitting_width + gap.x)))
	var width := (scroll.size.x - gap.x * (columns - 1)) / columns
	_grid.configure(_model.cards, columns, gap, Vector2(width, width / 0.75 + width * 0.36))


func _exit_tree() -> void:
	if _grid != null:
		_grid.dispose()
		_grid = null
	_thumbnails = null
