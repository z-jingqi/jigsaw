class_name RuntimeLevelListScreen
extends Control

signal back_requested
signal level_selected(level_id: String)
signal mode_selected(level_id: String, mode: StringName, start_policy: StringName)

const VirtualGridScript := preload("res://scripts/screens/levels/VirtualLevelGrid.gd")
const UnlockSequenceScript := preload("res://scripts/screens/levels/LevelUnlockSequence.gd")
const LevelCardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")
const NavigationControlMetricsScript := preload(
	"res://scripts/ui/foundation/NavigationControlMetrics.gd"
)

@onready var back_button: Button = $SafeArea/Content/Header/BackButton
@onready var header: Control = $SafeArea/Content/Header
@onready var theme_title: Label = $SafeArea/Content/Header/ThemeTitle
@onready var title_left_ornament: TextureRect = $SafeArea/Content/Header/TitleLeftOrnament
@onready var title_right_ornament: TextureRect = $SafeArea/Content/Header/TitleRightOrnament
@onready var progress: Control = $SafeArea/Content/Header/Progress
@onready var progress_count: Label = $SafeArea/Content/Header/Progress/Count
@onready var scroll: TouchScrollContainer = $SafeArea/Content/Scroll
@onready var grid_content: Control = $SafeArea/Content/Scroll/GridContent
@onready var focus_overlay: LevelFocusOverlay = $LevelFocusOverlay
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
	focus_overlay.mode_selected.connect(mode_selected.emit)
	focus_overlay.closed.connect(_on_focus_closed)
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
	focus_overlay.reset_immediately()
	_unlock_sequence.clear()
	if _grid != null:
		_grid.clear()
	animation_player.play(&"exit")


func _exit_tree() -> void:
	if is_instance_valid(focus_overlay):
		focus_overlay.reset_immediately()
	_unlock_sequence.clear()
	if _grid != null:
		_grid.clear()


func navigation_set_active(is_active: bool) -> void:
	scroll.set_touch_scroll_enabled(is_active and not focus_overlay.is_active())
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _grid != null:
		_grid.set_reduced_motion(enabled)
	if is_instance_valid(focus_overlay):
		focus_overlay.set_reduced_motion(enabled)


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	theme_title.text = str(view_model.theme_title)
	progress_count.text = (
		"%d / %d"
		% [view_model.theme_progress.completed_levels, view_model.theme_progress.total_levels]
	)
	_apply_header_layout()
	call_deferred("_apply_layout")


func refresh_view_model(view_model: Variant, preserve_focus := false) -> void:
	_view_model = view_model
	theme_title.text = str(view_model.theme_title)
	progress_count.text = (
		"%d / %d"
		% [view_model.theme_progress.completed_levels, view_model.theme_progress.total_levels]
	)
	_apply_header_layout()
	if preserve_focus and focus_overlay.is_active():
		var focused_model: Variant = _level_view_model(focus_overlay.focused_level_id())
		if focused_model != null:
			focus_overlay.refresh_view_model(focused_model)
		return
	focus_overlay.reset_immediately()
	_grid.refresh_items(view_model.levels)


func active_motion_count() -> int:
	return (
		(1 if animation_player.is_playing() else 0)
		+ _unlock_sequence.active_count()
		+ focus_overlay.active_motion_count()
	)


func debug_grid_column_count() -> int:
	return _grid.column_count() if _grid != null else 0


func debug_active_card_count() -> int:
	return _grid.active_card_count() if _grid != null else 0


func is_content_ready() -> bool:
	return (
		_view_model != null
		and _grid != null
		and (_view_model.levels.is_empty() or _grid.active_card_count() > 0)
		and _grid.is_content_ready()
	)


func open_level_focus(level_id: String) -> bool:
	if _grid == null or focus_overlay.is_active():
		return false
	var card := _grid.card_for_level_id(level_id) as LevelCard
	var card_view_model: Variant = _level_view_model(level_id)
	if card == null or card.is_locked() or card_view_model == null:
		return false
	_unlock_sequence.clear()
	return focus_overlay.open(card, card_view_model, _grid.visible_cards(), scroll)


func close_level_focus() -> void:
	focus_overlay.request_close()


func debug_focus_snapshot() -> Dictionary:
	return focus_overlay.debug_snapshot()


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
	if focus_overlay.is_active():
		return
	var available_width := maxf(1.0, scroll.size.x)
	var columns := grid_column_count_for_width(available_width)
	var regular := columns == 3
	var horizontal_gap := 30.0 if regular else 48.0
	var vertical_gap := 40.0
	var card_width := (available_width - horizontal_gap * float(columns - 1)) / float(columns)
	var card_size := Vector2(card_width, maxf(420.0, card_width * 1.34))
	var background_reveal_space := clampf(size.y * 0.09, 180.0, 280.0)
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
	back_button.position = Vector2(8.0, 16.0)
	back_button.size = Vector2.ONE * NavigationControlMetricsScript.BACK_BUTTON_SIZE
	back_button.custom_minimum_size = back_button.size
	progress.size = Vector2(266.0, 110.0)
	progress.position = Vector2(available_width - progress.size.x + 28.0, 20.0)
	var reserved_side := maxf(back_button.position.x + back_button.size.x, progress.size.x + 4.0)
	var group_width := maxf(360.0, available_width - reserved_side * 2.0 - 20.0)
	var font := theme_title.get_theme_font("font")
	var font_size := 68
	var ornament_gap := 12.0
	var ornament_width := 116.0
	var measured_width := (
		font.get_string_size(theme_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	)
	while font_size > 42 and (group_width - measured_width) * 0.5 - ornament_gap < 60.0:
		font_size -= 2
		measured_width = (
			font.get_string_size(theme_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		)
	var multiline := measured_width + 2.0 * (60.0 + ornament_gap) > group_width
	var title_height := 120.0
	var title_top := 12.0
	if multiline:
		font_size = 32
		ornament_gap = 8.0
		ornament_width = 40.0
		measured_width = group_width - 2.0 * (ornament_width + ornament_gap)
		title_height = 140.0
		title_top = 0.0
		theme_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		theme_title.max_lines_visible = 2
	else:
		ornament_width = clampf((group_width - measured_width) * 0.5 - ornament_gap, 60.0, 116.0)
		theme_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		theme_title.max_lines_visible = 1
	theme_title.add_theme_font_size_override("font_size", font_size)
	var ornament_size := Vector2(ornament_width, 70.0)
	var actual_group_width := measured_width + (ornament_size.x + ornament_gap) * 2.0
	var group_left := (available_width - actual_group_width) * 0.5
	title_left_ornament.position = Vector2(group_left, 38.0)
	title_left_ornament.size = ornament_size
	theme_title.position = Vector2(group_left + ornament_size.x + ornament_gap, title_top)
	theme_title.size = Vector2(measured_width, title_height)
	title_right_ornament.position = Vector2(
		theme_title.position.x + theme_title.size.x + ornament_gap, 38.0
	)
	title_right_ornament.size = ornament_size


func _on_card_visible(card: Control, view_model: Variant) -> void:
	if not bool(view_model.newly_unlocked):
		return
	var level_id := str(view_model.level_id)
	if _played_unlocks.has(level_id):
		return
	_played_unlocks[level_id] = true
	_unlock_sequence.play(card, _reduced_motion)


func _on_level_selected(level_id: String) -> void:
	level_selected.emit(level_id)
	open_level_focus(level_id)


func _on_back_pressed() -> void:
	if focus_overlay.is_active():
		focus_overlay.request_close()
		return
	back_requested.emit()


func _on_focus_closed() -> void:
	if _view_model != null and _grid != null:
		_grid.refresh_items(_view_model.levels)


func _unhandled_input(event: InputEvent) -> void:
	if not focus_overlay.is_active() or not event.is_action_pressed(&"ui_cancel"):
		return
	focus_overlay.request_close()
	get_viewport().set_input_as_handled()


func _level_view_model(level_id: String) -> Variant:
	if _view_model == null:
		return null
	for level in _view_model.levels:
		if str(level.level_id) == level_id:
			return level
	return null
