class_name HomeScreen
extends Control

signal selected_theme_changed(theme_id: String)
signal theme_activated(theme_id: String)
signal menu_requested
signal themes_requested

const Layout := preload("res://scripts/screens/home/HomeLayout.gd")
const ThemeTitleMotion := preload("res://scripts/screens/home/ThemeTitleMotion.gd")
@onready var deck := $Deck
@onready var menu_button: Button = $MenuButton
@onready var start_button: Button = $StartButton
var _themes: Array = []
var _selected_index := 0
var _title_motion: RefCounted


func _ready() -> void:
	_title_motion = ThemeTitleMotion.new(
		$ThemeName,
		$IncomingThemeName,
		[$TitleCloudLeft as Control, $TitleCloudRight as Control],
		func() -> void: Layout.apply(self)
	)
	deck.selected.connect(_on_selected)
	deck.browse_motion.connect(_on_browse_motion)
	menu_button.pressed.connect(menu_requested.emit)
	$ThemesButton.pressed.connect(themes_requested.emit)
	$UndoButton.pressed.connect(deck.undo)
	start_button.pressed.connect(_on_enter_pressed)
	resized.connect(_on_resized)
	Layout.apply(self)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload.view_model)


func navigation_prepare_transition() -> void:
	deck.cancel()


func navigation_exit(_context: Dictionary) -> void:
	deck.cancel()


func navigation_set_active(enabled: bool) -> void:
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled:
		deck.cancel()


func set_reduced_motion(enabled: bool) -> void:
	set_meta("reduced_motion", enabled)
	deck.reduced_motion = enabled
	if enabled:
		deck.cancel()


func set_view_model(model: Variant) -> void:
	_themes = model.themes
	_selected_index = model.selected_index
	deck.configure(_themes, _selected_index)
	_update_information()


func select_theme(theme_id: String) -> void:
	for i in _themes.size():
		if str(_themes[i].theme_id) == theme_id:
			deck.select_theme(i)
			return


func _on_selected(index: int) -> void:
	_selected_index = index
	_update_information()
	selected_theme_changed.emit(str(_themes[index].theme_id))


func _update_information() -> void:
	var can_undo: bool = not deck.history.is_empty()
	$UndoButton.visible = can_undo
	$UndoButton.disabled = not can_undo
	$UndoButton.queue_redraw()
	if _themes.is_empty():
		start_button.disabled = true
		return
	var model: Variant = _themes[_selected_index]
	$ThemeName.autowrap_mode = TextServer.AUTOWRAP_OFF
	$ThemeName.max_lines_visible = 1
	$ThemeName.clip_text = true
	start_button.text = "进入主题" if model.playable else "敬请期待"
	start_button.disabled = not model.playable
	var next_model: Variant = _themes[posmod(_selected_index + 1, _themes.size())]
	_title_motion.set_current(str(model.title), str(next_model.title))


func _on_browse_motion(
	current_index: int,
	next_index: int,
	outgoing_progress: float,
	incoming_progress: float,
	committed: bool
) -> void:
	if (
		current_index < 0
		or current_index >= _themes.size()
		or next_index < 0
		or next_index >= _themes.size()
	):
		return
	_title_motion.apply_progress(
		str(_themes[current_index].title),
		str(_themes[next_index].title),
		outgoing_progress,
		incoming_progress,
		committed,
		bool(get_meta("reduced_motion", false))
	)


func _on_enter_pressed() -> void:
	if (
		not _themes.is_empty()
		and _themes[_selected_index].playable
		and deck.active_motion_count() == 0
	):
		theme_activated.emit(str(_themes[_selected_index].theme_id))


func transition_source_rect() -> Rect2:
	return deck.source_rect()


func transition_source_texture() -> Texture2D:
	return _themes[_selected_index].cover_texture if not _themes.is_empty() else null


func active_motion_count() -> int:
	return deck.active_motion_count()


func _on_resized() -> void:
	_title_motion.relayout()


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"cover_pool_size": 4,
		"visible_cover_count": mini(3, _themes.size()),
		"undo_count": deck.history.size(),
		"playable": not start_button.disabled,
		"reduced_motion": deck.reduced_motion,
	}


func debug_begin_drag() -> void:
	deck.begin(Vector2.ZERO)


func debug_drag(delta_x: float, _elapsed := 0.016) -> void:
	deck.drag_by(Vector2(delta_x, 0))


func debug_end_drag() -> void:
	deck.end()
