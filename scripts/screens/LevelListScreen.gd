class_name RuntimeLevelListScreen
extends Control

signal back_requested()
signal level_selected(level_id: String)

const VirtualGridScript := preload("res://scripts/screens/levels/VirtualLevelGrid.gd")
const UnlockSequenceScript := preload("res://scripts/screens/levels/LevelUnlockSequence.gd")
const LevelCardScene := preload("res://scenes/ui/foundation/LevelCard.tscn")

@onready var back_button: Button = $SafeArea/Content/Header/BackButton
@onready var theme_title: Label = $SafeArea/Content/Header/ThemeTitle
@onready var theme_progress: ThemeProgress = $SafeArea/Content/Header/ThemeProgress
@onready var scroll: ScrollContainer = $SafeArea/Content/Scroll
@onready var grid_content: Control = $SafeArea/Content/Scroll/GridContent
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _grid: Variant
var _reduced_motion := false
var _unlock_sequence = UnlockSequenceScript.new()
var _played_unlocks: Dictionary = {}


func _ready() -> void:
	_grid = VirtualGridScript.new(scroll, grid_content, LevelCardScene)
	_grid.level_selected.connect(level_selected.emit)
	_grid.card_visible.connect(_on_card_visible)
	_grid.card_hidden.connect(_unlock_sequence.cancel)
	back_button.pressed.connect(back_requested.emit)
	resized.connect(_apply_layout)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	play_enter()


func navigation_exit(_context: Dictionary) -> void:
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


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	theme_progress.reduced_motion = enabled


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	theme_title.text = str(view_model.theme_title)
	theme_progress.set_view_model(view_model.theme_progress)
	call_deferred("_apply_layout")


func refresh_view_model(view_model: Variant) -> void:
	_view_model = view_model
	theme_progress.set_view_model(view_model.theme_progress)
	_grid.refresh_items(view_model.levels)


func active_motion_count() -> int:
	return (1 if animation_player.is_playing() else 0) + theme_progress.active_motion_count() + _unlock_sequence.active_count()


func debug_grid_column_count() -> int:
	return _grid.column_count() if _grid != null else 0


func debug_active_card_count() -> int:
	return _grid.active_card_count() if _grid != null else 0


static func grid_column_count_for_width(available_width: float) -> int:
	return 3 if available_width >= 600.0 else 2


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
	var horizontal_gap := 16.0 if regular else 12.0
	var vertical_gap := 24.0
	var card_width := (available_width - horizontal_gap * float(columns - 1)) / float(columns)
	var card_size := Vector2(card_width, maxf(180.0, card_width * 1.20))
	_grid.configure(_view_model.levels, columns, Vector2(horizontal_gap, vertical_gap), card_size)
	if not str(_view_model.focus_level_id).is_empty():
		_grid.scroll_to_item(str(_view_model.focus_level_id))


func _on_card_visible(card: Control, view_model: Variant) -> void:
	if not bool(view_model.newly_unlocked):
		return
	var level_id := str(view_model.level_id)
	if _played_unlocks.has(level_id):
		return
	_played_unlocks[level_id] = true
	_unlock_sequence.play(card, _reduced_motion)
