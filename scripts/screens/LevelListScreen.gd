class_name RuntimeLevelListScreen
extends Control

signal back_requested
signal level_selected(level_id: String)

const VirtualGridScript := preload("res://scripts/screens/levels/VirtualLevelGrid.gd")
const UnlockSequenceScript := preload("res://scripts/screens/levels/LevelUnlockSequence.gd")
const LevelCardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")

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


func _ready() -> void:
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
		_grid.clear()


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
	theme_title.text = str(view_model.theme_title)
	progress_count.text = (
		"%d / %d"
		% [view_model.theme_progress.completed_modes, view_model.theme_progress.total_modes]
	)
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
	if _view_model == null or _grid == null:
		return
	var available_width := maxf(1.0, scroll.size.x)
	var columns := grid_column_count_for_width(available_width)
	var regular := columns == 3
	var horizontal_gap := 22.0 if regular else 28.0
	var vertical_gap := 30.0
	var card_width := (available_width - horizontal_gap * float(columns - 1)) / float(columns)
	var card_size := Vector2(card_width, card_width * 4.0 / 3.0 + 72.0)
	var background_reveal_space := clampf(size.y * 0.07, 140.0, 220.0)
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
	var available_width := header.size.x
	back_button.position = Vector2(4.0, 12.0)
	back_button.size = Vector2(92.0, 92.0)
	progress.size = Vector2(232.0, 82.0)
	progress.position = Vector2(available_width - progress.size.x - 4.0, 18.0)
	var reserved_side := maxf(
		back_button.position.x + back_button.size.x, available_width - progress.position.x
	)
	var group_width := maxf(320.0, available_width - reserved_side * 2.0 - 20.0)
	var font := theme_title.get_theme_font("font")
	var font_size := 58
	var ornament_gap := 10.0
	var ornament_width := 104.0
	var measured_width := (
		font.get_string_size(theme_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	)
	while font_size > 36 and (group_width - measured_width) * 0.5 - ornament_gap < 52.0:
		font_size -= 2
		measured_width = (
			font.get_string_size(theme_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		)
	var multiline := measured_width + 2.0 * (52.0 + ornament_gap) > group_width
	var title_height := 104.0
	var title_top := 6.0
	if multiline:
		font_size = 30
		ornament_gap = 8.0
		ornament_width = 36.0
		measured_width = group_width - 2.0 * (ornament_width + ornament_gap)
		title_height = 112.0
		title_top = 0.0
		theme_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		theme_title.max_lines_visible = 2
	else:
		ornament_width = clampf((group_width - measured_width) * 0.5 - ornament_gap, 52.0, 104.0)
		theme_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		theme_title.max_lines_visible = 1
	theme_title.add_theme_font_size_override("font_size", font_size)
	var ornament_size := Vector2(ornament_width, ornament_width * 0.36)
	var actual_group_width := measured_width + (ornament_size.x + ornament_gap) * 2.0
	var group_left := (available_width - actual_group_width) * 0.5
	title_left_ornament.position = Vector2(
		group_left, title_top + (title_height - ornament_size.y) * 0.5
	)
	title_left_ornament.size = ornament_size
	theme_title.position = Vector2(group_left + ornament_size.x + ornament_gap, title_top)
	theme_title.size = Vector2(measured_width, title_height)
	title_right_ornament.position = Vector2(
		theme_title.position.x + theme_title.size.x + ornament_gap,
		title_top + (title_height - ornament_size.y) * 0.5
	)
	title_right_ornament.size = ornament_size


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
