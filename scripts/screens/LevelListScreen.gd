class_name RuntimeLevelListScreen
extends Control

signal back_requested
signal level_selected(level_id: String)

const DotPager := preload("res://scripts/ui/navigation/WindowedDotPager.gd")
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
@onready var scroll: Control = $SafeArea/Content/Scroll
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _grid: Variant
var _reduced_motion := false
var _unlock_sequence = UnlockSequenceScript.new()
var _played_unlocks: Dictionary = {}
var _empty_label: Label
var _pager: Control
var _initial_focus_applied := false


func _ready() -> void:
	Clean.icon_button(back_button)
	back_button.accessibility_name = GameStrings.ui_text("return_topics")
	_empty_label = Label.new()
	_empty_label.text = GameStrings.ui_text("no_levels")
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$SafeArea/Content.add_child(_empty_label)
	_grid = scroll
	_pager = DotPager.new()
	_pager.name = "PageDots"
	$SafeArea/Content.add_child(_pager)
	_pager.page_requested.connect(set_page)
	_grid.page_changed.connect(_on_page_changed)
	_grid.level_selected.connect(_on_level_selected)
	_grid.card_visible.connect(_on_card_visible)
	_grid.card_hidden.connect(_unlock_sequence.cancel)
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_apply_layout)
	scroll.resized.connect(_apply_layout)
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
		_grid.settle()
	animation_player.play(&"exit")


func _exit_tree() -> void:
	_unlock_sequence.clear()
	if _grid != null:
		_grid.dispose()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	scroll.set_interaction_enabled(is_active)
	_pager.set_interaction_enabled(is_active)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _grid != null:
		_grid.set_reduced_motion(enabled)
	if _pager != null:
		_pager.set_reduced_motion(enabled)


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
	return (
		(1 if animation_player.is_playing() else 0)
		+ _unlock_sequence.active_count()
		+ (_grid.active_motion_count() if _grid != null else 0)
	)


func debug_grid_column_count() -> int:
	return 2


func debug_active_card_count() -> int:
	return _grid.visible_cards().size() if _grid != null else 0


func debug_scroll_position() -> int:
	# Compatibility: this is now the page index, not a pixel scroll offset.
	return debug_page_index()


func debug_card_rect(level_id: String) -> Rect2:
	var card: Control = _grid.card_for_level_id(level_id) as Control if _grid != null else null
	return card.get_global_rect() if is_instance_valid(card) else Rect2()


func debug_box_rect(level_id: String) -> Rect2:
	var card: Control = _grid.card_for_level_id(level_id) as Control if _grid != null else null
	return card.prototype_box_rect() if is_instance_valid(card) else Rect2()


func set_box_transition_source(level_id: String, hidden: bool) -> void:
	if _grid != null:
		_grid.set_box_transition_source(level_id, hidden)


static func grid_column_count_for_width(_available_width: float) -> int:
	return 2


func play_enter() -> void:
	if _reduced_motion:
		animation_player.play(&"enter")
		animation_player.seek(animation_player.get_animation(&"enter").length, true)
		return
	animation_player.play(&"enter")


func _apply_layout() -> void:
	if not is_node_ready() or _grid == null:
		return
	_apply_header_layout()
	var content: Control = $SafeArea/Content
	var native := Clean.canvas_scale(get_viewport_rect().size, get_window())
	var top := 80.0 * native
	var footer := 62.0 * native
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.position = Vector2(0, top)
	scroll.size = Vector2(content.size.x, maxf(100 * native, content.size.y - top - footer))
	_pager.position = Vector2(0, content.size.y - 54 * native)
	_pager.size = Vector2(content.size.x, 44 * native)
	if _view_model == null:
		return
	_empty_label.visible = _view_model.levels.is_empty()
	_empty_label.position = scroll.position
	_empty_label.size = scroll.size
	Clean.label(_empty_label, roundi(18 * native), true)
	if not _initial_focus_applied:
		_initial_focus_applied = true
		_grid.configure(_view_model.levels, str(_view_model.focus_level_id))
	_on_page_changed(_grid.page_index())


func _apply_header_layout() -> void:
	if not is_node_ready() or header.size.x <= 0.0:
		return
	var native := Clean.canvas_scale(get_viewport_rect().size, get_window())
	Buttons.place_navigation(back_button, self)
	title_left_ornament.hide()
	title_right_ornament.hide()
	progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	progress.size = Vector2(64, 32) * native
	progress.position = Vector2(
		header.size.x - progress.size.x, back_button.position.y + 6 * native
	)
	progress.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	Clean.label(progress_count, roundi(13 * native), true)
	theme_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	theme_title.max_lines_visible = 1
	theme_title.position = Vector2(48 * native, back_button.position.y)
	theme_title.size = Vector2(maxf(0, header.size.x - 120 * native), 44 * native)
	Clean.label(theme_title, roundi(23 * native))


func set_page(index: int) -> void:
	_grid.request_page(index)


func debug_page_index() -> int:
	return _grid.page_index() if _grid != null else 0


func debug_page_count() -> int:
	return _grid.page_count() if _grid != null else 0


func debug_pagination_snapshot() -> Dictionary:
	var result: Dictionary = _grid.debug_snapshot()
	result["page_index"] = debug_page_index()
	result["page_count"] = debug_page_count()
	result["level_ids"] = []
	for card in _grid.visible_cards():
		result.level_ids.append(str(card.level_id))
	result["animating"] = _grid.active_motion_count() > 0
	result["active_card_count"] = _grid.visible_cards().size()
	return result


func _on_page_changed(index: int) -> void:
	if _pager != null:
		_pager.configure(_grid.page_count(), index)


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
