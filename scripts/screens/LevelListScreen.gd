class_name RuntimeLevelListScreen
extends Control

signal back_requested
signal level_selected(level_id: String)

const VirtualGridScript := preload("res://scripts/screens/levels/VirtualLevelGrid.gd")
const UnlockSequenceScript := preload("res://scripts/screens/levels/LevelUnlockSequence.gd")
const LevelCardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")

@onready var back_button: Button = $SafeArea/Content/Header/BackButton
@onready var header: Control = $SafeArea/Content/Header
@onready var theme_title: Label = $SafeArea/Content/Header/ThemeTitle
@onready var title_left_ornament: TextureRect = $SafeArea/Content/Header/TitleLeftOrnament
@onready var title_right_ornament: TextureRect = $SafeArea/Content/Header/TitleRightOrnament
@onready var progress: Control = $SafeArea/Content/Header/Progress
@onready var progress_count: Label = $SafeArea/Content/Header/Progress/Count
@onready var scroll: NaturalScrollContainer = $SafeArea/Content/Scroll
@onready var grid_content: Control = $SafeArea/Content/Scroll/GridContent
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _grid: Variant
var _reduced_motion := false
var _unlock_sequence = UnlockSequenceScript.new()
var _played_unlocks: Dictionary = {}
var _empty_label: Label


func _ready() -> void:
	_empty_label = Label.new()
	_empty_label.text = GameStrings.ui_text("levels_empty")
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$SafeArea/Content.add_child(_empty_label)
	_grid = VirtualGridScript.new(scroll, grid_content, LevelCardScene)
	_grid.level_selected.connect(_on_level_selected)
	_grid.card_visible.connect(_on_card_visible)
	_grid.card_hidden.connect(_unlock_sequence.cancel)
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_apply_layout)
	header.resized.connect(_apply_header_layout)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	play_enter()


func navigation_exit(_context: Dictionary) -> void:
	scroll.set_interaction_enabled(false)
	_unlock_sequence.clear()
	if _grid != null:
		_grid.clear()
	animation_player.play(&"exit")


func _exit_tree() -> void:
	_unlock_sequence.clear()
	if _grid != null:
		_grid.dispose()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	scroll.set_interaction_enabled(is_active)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _grid != null:
		for card in _grid.visible_cards():
			card.set_reduced_motion(enabled)


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	theme_title.text = str(view_model.theme_title)
	progress_count.text = (
		"%d / %d"
		% [view_model.theme_progress.completed_modes, view_model.theme_progress.total_modes]
	)
	_apply_header_layout()
	call_deferred("_apply_layout")


func refresh_view_model(view_model: Variant) -> void:
	_view_model = view_model
	var next_title := str(view_model.theme_title)
	var title_changed := theme_title.text != next_title
	if title_changed:
		theme_title.text = next_title
	progress_count.text = (
		"%d / %d"
		% [view_model.theme_progress.completed_modes, view_model.theme_progress.total_modes]
	)
	if title_changed:
		_apply_header_layout()
	_grid.refresh_items(view_model.levels)


func active_motion_count() -> int:
	return (1 if animation_player.is_playing() else 0) + _unlock_sequence.active_count()


func debug_grid_column_count() -> int:
	return _grid.column_count() if _grid != null else 0


func debug_active_card_count() -> int:
	return _grid.active_card_count() if _grid != null else 0


func debug_scroll_position() -> int:
	return scroll.scroll_vertical


func debug_card_rect(level_id: String) -> Rect2:
	var card: Control = _grid.card_for_level_id(level_id) as Control if _grid != null else null
	return card.get_global_rect() if is_instance_valid(card) else Rect2()


static func grid_column_count_for_width(available_width: float) -> int:
	return 3 if available_width >= 1440.0 else 2


func play_enter() -> void:
	if _reduced_motion:
		animation_player.play(&"enter")
		animation_player.seek(animation_player.get_animation(&"enter").length, true)
		return
	animation_player.play(&"enter")


func _apply_layout() -> void:
	_apply_header_layout()
	if _view_model == null or _grid == null:
		return
	_empty_label.visible = _view_model.levels.is_empty()
	_empty_label.position = scroll.position
	_empty_label.size = scroll.size
	Clean.label(_empty_label, roundi(18 * size.x / 390.0), true)
	var available_width := maxf(1.0, scroll.size.x)
	var columns := grid_column_count_for_width(available_width)
	var regular := columns == 3
	var horizontal_gap := 36.0 if regular else 40.0
	var vertical_gap := 44.0
	var card_width := (available_width - horizontal_gap * float(columns - 1)) / float(columns)
	var card_size := Vector2(card_width, card_width * 1.55)
	var background_reveal_space := clampf(size.y * 0.03, 48.0, 100.0)
	_grid.configure(
		_view_model.levels,
		columns,
		Vector2(horizontal_gap, vertical_gap),
		card_size,
		background_reveal_space
	)
	if not str(_view_model.focus_level_id).is_empty():
		_grid.scroll_to_item(str(_view_model.focus_level_id))


func _apply_header_layout() -> void:
	if not is_node_ready() or header.size.x <= 0.0:
		return
	var u := minf(size.x / 390.0, size.y / 700.0)
	var available_width := header.size.x
	Buttons.place_navigation(back_button, self)
	title_left_ornament.visible = false
	title_right_ornament.visible = false
	progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	progress.size = Vector2(100.0, 34.0) * u
	progress.position = Vector2(available_width - progress.size.x, back_button.position.y)
	progress.add_theme_stylebox_override("panel", Clean.panel(Clean.SAGE, roundi(17 * u)))
	Clean.label(progress_count, roundi(14 * u), true)
	theme_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	theme_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	theme_title.max_lines_visible = 2
	theme_title.position = Vector2(0, 64 * u)
	theme_title.size = Vector2(available_width, 80 * u)
	Clean.label(theme_title, roundi(30 * u))
	scroll.offset_top = 168 * u


func _on_card_visible(card: Control, view_model: Variant) -> void:
	card.set_reduced_motion(_reduced_motion)
	if not bool(view_model.newly_unlocked):
		return
	var level_id := str(view_model.level_id)
	if _played_unlocks.has(level_id):
		return
	_played_unlocks[level_id] = true
	_unlock_sequence.play(card, _reduced_motion)


func _on_level_selected(level_id: String) -> void:
	level_selected.emit(level_id)


func _on_back_pressed() -> void:
	back_requested.emit()
