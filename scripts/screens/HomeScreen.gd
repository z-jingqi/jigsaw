class_name HomeScreen
extends Control

signal selected_theme_changed(theme_id: String)
signal theme_activated(theme_id: String)
signal menu_requested

const PagerControllerScript := preload("res://scripts/screens/HomePagerController.gd")
const CoverMotionScript := preload("res://scripts/screens/HomeCoverMotion.gd")
const ThemeInfoMotionScript := preload("res://scripts/screens/HomeThemeInfoMotion.gd")
const MotionTokenResource := preload("res://themes/motion_tokens.tres")

const DESIGN_WIDTH := 1206.0
const DESIGN_HEIGHT := 2622.0
const CARD_ASPECT := 0.61
const CARD_WIDTH_RATIO := 0.708
const HEADER_CLEARANCE := 600.0
const BOTTOM_CLEARANCE := 620.0
const CARD_GAP := 104.0
const FRAME_INSET := 12.0
const TITLE_MAX_FONT_SIZE := 108
const TITLE_MIN_SINGLE_LINE_FONT_SIZE := 44
const TITLE_WRAP_MIN_FONT_SIZE := 36
const TITLE_GROUP_MARGIN := 24.0
const TITLE_ORNAMENT_GAP := 18.0
const TITLE_ORNAMENT_MIN_WIDTH := 64.0
const TITLE_ORNAMENT_MAX_WIDTH := 116.0
const TITLE_BOX_HEIGHT := 160.0

@onready var cover_slots: Control = $CoverSlots
@onready var far_previous_cover: TextureRect = $CoverSlots/FarPrevious
@onready var previous_cover: TextureRect = $CoverSlots/Previous
@onready var current_cover: TextureRect = $CoverSlots/Current
@onready var next_cover: TextureRect = $CoverSlots/Next
@onready var far_next_cover: TextureRect = $CoverSlots/FarNext
@onready var logo: TextureRect = $SafeArea/SafeContent/Header/Logo
@onready var menu_button: ActionButton = $SafeArea/SafeContent/Header/MenuButton
@onready var bottom_content: Control = $SafeArea/SafeContent/BottomContent
@onready var info_panel := $ThemeInfoLayer/InfoLive as Control
@onready var theme_name := info_panel.get_node("ThemeName") as Label
@onready var progress_group := info_panel.get_node("ProgressTag") as Control
@onready var progress_count := progress_group.get_node("ProgressCount") as Label
@onready var progress_fill := progress_group.get_node("ProgressTrack/ProgressFill") as Control
@onready var incoming_info := $ThemeInfoLayer/InfoIncoming as Control
@onready var incoming_name := incoming_info.get_node("ThemeName") as Label
@onready var incoming_progress_group := incoming_info.get_node("ProgressTag") as Control
@onready var incoming_progress_count := incoming_progress_group.get_node("ProgressCount") as Label
@onready var incoming_progress_fill := (
	incoming_progress_group.get_node("ProgressTrack/ProgressFill") as Control
)
@onready var start_button: ActionButton = $SafeArea/SafeContent/BottomContent/StartButton

var _view_model: Variant
var _themes: Array = []
var _selected_index := 0
var _pager: Variant
var _cover_motion: Variant
var _info_motion: Variant
var _incoming_index := -1
var _first_entry_played := false
var _entry_interaction_ready := true
var _transitioning_to_levels := false
var _pointer_gesture_active := false
var _progress_ratio := 0.0
var _incoming_progress_ratio := 0.0
var _card_size := Vector2.ZERO
var _card_stride := 1.0
var _card_top := 0.0


func _ready() -> void:
	_pager = PagerControllerScript.new(self, MotionTokenResource)
	_pager.drag_updated.connect(_on_pager_drag_updated)
	_pager.page_settled.connect(_on_pager_settled)
	_cover_motion = (
		CoverMotionScript
		. new(
			[
				far_previous_cover,
				previous_cover,
				current_cover,
				next_cover,
				far_next_cover,
			]
		)
	)
	_info_motion = ThemeInfoMotionScript.new(info_panel, incoming_info)
	menu_button.pressed.connect(menu_requested.emit)
	start_button.pressed.connect(_on_enter_pressed)
	resized.connect(_on_resized)
	_apply_cold_entry_final()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	if not _first_entry_played:
		play_cold_entry()


func navigation_exit(_context: Dictionary) -> void:
	_pointer_gesture_active = false
	if _pager != null:
		_pager.finish_to_current()
	_layout_cover_slots(0, 0.0)
	_cancel_button_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	set_process_input(is_active)
	if not is_active and _pager != null:
		_pointer_gesture_active = false
		_pager.finish_to_current()
	if not is_active:
		_cancel_button_motion()


func set_reduced_motion(enabled: bool) -> void:
	set_meta("reduced_motion", enabled)
	menu_button.set_reduced_motion(enabled)
	start_button.set_reduced_motion(enabled)
	if enabled:
		if _pager != null:
			_pager.cancel_to_current()
		_cancel_button_motion()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	_themes = view_model.themes
	_selected_index = clampi(int(view_model.selected_index), 0, maxi(0, _themes.size() - 1))
	_apply_selected_theme()


func play_cold_entry() -> void:
	if _first_entry_played:
		return
	_first_entry_played = true
	_apply_cold_entry_final()


func active_motion_count() -> int:
	return (
		(_pager.active_motion_count() if _pager != null else 0)
		+ menu_button.active_motion_count()
		+ start_button.active_motion_count()
	)


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"animation": "",
		"animation_playing": false,
		"pager_motion": _pager.active_motion_count() if _pager != null else 0,
		"gesture_progress": _pager.gesture_progress() if _pager != null else 0.0,
		"gesture_offset": _pager.gesture_offset() if _pager != null else 0.0,
		"entry_interaction_ready": _entry_interaction_ready,
		"reduced_motion": bool(get_meta("reduced_motion", false)),
		"progress_ratio": _progress_ratio,
		"cover_pool_size": _cover_motion.pool_size() if _cover_motion != null else 0,
		"visible_cover_count": _cover_motion.visible_cover_count() if _cover_motion != null else 0,
	}


func debug_drag(delta_x: float, elapsed := 0.016) -> void:
	if _pager != null:
		_pager.drag_by(delta_x, elapsed)


func debug_begin_drag() -> void:
	if _pager != null:
		_pager.begin()


func debug_end_drag() -> void:
	if _pager != null:
		_pager.end()


func transition_source_rect() -> Rect2:
	return current_cover.get_global_rect()


func transition_source_texture() -> Texture2D:
	return current_cover.texture


func _apply_selected_theme() -> void:
	if _themes.is_empty():
		theme_name.text = ""
		_set_progress(progress_fill, progress_count, null)
		return
	_update_card_metrics()
	var selected: Variant = _themes[_selected_index]
	_set_information(theme_name, progress_count, progress_fill, selected)
	_progress_ratio = float(selected.progress.ratio)
	_incoming_index = -1
	_info_motion.reset()
	_reconcile_covers()
	_layout_cover_slots(0, 0.0)
	_pager.configure(_themes.size(), _selected_index, _card_stride)


func _theme_at(index: int) -> Variant:
	if _themes.is_empty():
		return null
	return _themes[posmod(index, _themes.size())]


func _set_cover(slot: TextureRect, theme_model: Variant) -> void:
	slot.visible = theme_model != null
	if theme_model != null:
		slot.texture = theme_model.cover_texture


func _reconcile_covers() -> void:
	var used_indices: Dictionary = {}
	for pair in [
		[current_cover, 0],
		[previous_cover, -1],
		[next_cover, 1],
		[far_previous_cover, -2],
		[far_next_cover, 2],
	]:
		var cover := pair[0] as TextureRect
		var offset := int(pair[1])
		var model_index := posmod(_selected_index + offset, _themes.size())
		if used_indices.has(model_index):
			_set_cover(cover, null)
			continue
		used_indices[model_index] = true
		_set_cover(cover, _themes[model_index])


func _layout_cover_slots(direction: int, progress: float) -> void:
	_update_card_metrics()
	var unit := _layout_unit()
	_cover_motion.apply_layout(
		direction,
		progress,
		_card_size,
		Vector2(size.x * 0.5, _card_top + _card_size.y * 0.5),
		CARD_GAP * unit,
		FRAME_INSET * unit,
		bool(get_meta("reduced_motion", false))
	)


func _update_card_metrics() -> void:
	var unit := _layout_unit()
	var max_width := minf(size.x * CARD_WIDTH_RATIO, 854.0 * unit)
	var header_clearance := HEADER_CLEARANCE * unit
	var bottom_clearance := BOTTOM_CLEARANCE * unit
	var available_height := maxf(260.0 * unit, size.y - header_clearance - bottom_clearance)
	var card_height := minf(max_width / CARD_ASPECT, available_height)
	var card_width := minf(max_width, card_height * CARD_ASPECT)
	_card_size = Vector2(card_width, card_height)
	_card_stride = card_width * 0.93 + CARD_GAP * unit
	_card_top = header_clearance + maxf(0.0, (available_height - card_height) * 0.32)
	_layout_theme_info(info_panel, unit)
	_layout_theme_info(incoming_info, unit)


func _layout_unit() -> float:
	return maxf(0.45, minf(size.x / DESIGN_WIDTH, size.y / DESIGN_HEIGHT))


func _layout_theme_info(panel: Control, unit: float) -> void:
	var center_x := (size.x - _card_size.x) * 0.5
	_prepare_title_label(panel, unit)

	var progress_tag := panel.get_node("ProgressTag") as Control
	progress_tag.size = Vector2(320.0, 132.0) * unit
	progress_tag.position = Vector2(
		center_x + _card_size.x - progress_tag.size.x - 16.0 * unit,
		_card_top + _card_size.y - progress_tag.size.y - 8.0 * unit
	)


func _prepare_title_label(panel: Control, unit: float) -> void:
	var name_label := panel.get_node("ThemeName") as Label
	var group_width := maxf(1.0, _card_size.x - TITLE_GROUP_MARGIN * 2.0 * unit)
	var reserved_width := (TITLE_ORNAMENT_MIN_WIDTH + TITLE_ORNAMENT_GAP) * 2.0 * unit
	var label_width := maxf(1.0, group_width - reserved_width)
	var title_top := _card_top - 190.0 * unit
	name_label.position = Vector2((size.x - label_width) * 0.5, title_top)
	name_label.size = Vector2(label_width, TITLE_BOX_HEIGHT * unit)


func _layout_title_decorations(panel: Control, unit: float) -> void:
	var name_label := panel.get_node("ThemeName") as Label
	var left := panel.get_node("TitleOrnamentLeft") as TextureRect
	var right := panel.get_node("TitleOrnamentRight") as TextureRect
	var group_limit := maxf(1.0, _card_size.x - TITLE_GROUP_MARGIN * 2.0 * unit)
	var gap := TITLE_ORNAMENT_GAP * unit
	var label_width := name_label.size.x

	if name_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font := name_label.get_theme_font("font")
		var font_size := name_label.get_theme_font_size("font_size")
		var measured := (
			font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		label_width = minf(label_width, ceilf(measured + 8.0 * unit))

	var ornament_room := maxf(0.0, (group_limit - label_width - gap * 2.0) * 0.5)
	var ornament_width := minf(TITLE_ORNAMENT_MAX_WIDTH * unit, ornament_room)
	var total_width := label_width + (ornament_width + gap) * 2.0
	var group_left := (size.x - total_width) * 0.5
	var center_y := name_label.position.y + name_label.size.y * 0.5
	var texture_size := left.texture.get_size() if left.texture != null else Vector2(256.0, 145.0)
	var ornament_height := minf(
		72.0 * unit, ornament_width * texture_size.y / maxf(1.0, texture_size.x)
	)

	left.position = Vector2(group_left, center_y - ornament_height * 0.5)
	left.size = Vector2(ornament_width, ornament_height)
	name_label.position.x = group_left + ornament_width + gap
	name_label.size.x = label_width
	right.position = Vector2(
		name_label.position.x + label_width + gap, center_y - ornament_height * 0.5
	)
	right.size = Vector2(ornament_width, ornament_height)


func _set_information(
	name_label: Label, count_label: Label, fill: Control, theme_model: Variant
) -> void:
	var panel := name_label.get_parent() as Control
	var unit := _layout_unit()
	_prepare_title_label(panel, unit)
	_fit_title(name_label, str(theme_model.title))
	_layout_title_decorations(panel, unit)
	_set_progress(fill, count_label, theme_model.progress)


func _fit_title(label: Label, text: String) -> void:
	label.text = text
	var available := label.size.x
	if available <= 1.0:
		available = maxf(1.0, size.x * 0.55)
	var box_height := label.size.y
	if box_height <= 1.0:
		box_height = 206.0
	var font := label.get_theme_font("font")

	var single := TITLE_MAX_FONT_SIZE
	while single >= TITLE_MIN_SINGLE_LINE_FONT_SIZE:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, single).x <= available:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.max_lines_visible = 1
			label.add_theme_font_size_override("font_size", single)
			label.tooltip_text = ""
			return
		single -= 2

	var wrapped := TITLE_MIN_SINGLE_LINE_FONT_SIZE
	while wrapped > TITLE_WRAP_MIN_FONT_SIZE:
		var block := font.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, available, wrapped
		)
		if block.x <= available and block.y <= box_height:
			break
		wrapped -= 2
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_font_size_override("font_size", wrapped)
	label.tooltip_text = text


func _set_progress(fill: Control, count_label: Label, progress: Variant) -> void:
	if progress == null:
		fill.visible = false
		count_label.text = "完成 0 / 0"
		count_label.accessibility_name = "已完成 0 / 总数 0"
		return
	var clamped := clampf(float(progress.ratio), 0.0, 1.0)
	fill.visible = clamped > 0.0
	fill.anchor_right = clamped
	fill.offset_right = -2.0
	count_label.text = "完成 %d / %d" % [progress.completed_modes, progress.total_modes]
	count_label.accessibility_name = (
		"已完成 %d / 总数 %d" % [progress.completed_modes, progress.total_modes]
	)


func _on_pager_drag_updated(direction: int, pager_progress: float, _offset: float) -> void:
	_layout_cover_slots(direction, pager_progress)
	if direction == 0:
		_incoming_index = -1
		_info_motion.reset()
		return
	var incoming_index := posmod(_selected_index + direction, _themes.size())
	if incoming_index != _incoming_index:
		_set_information(
			incoming_name, incoming_progress_count, incoming_progress_fill, _themes[incoming_index]
		)
		_incoming_progress_ratio = float(_themes[incoming_index].progress.ratio)
		_incoming_index = incoming_index
	_info_motion.apply(
		direction if _incoming_index >= 0 else 0,
		pager_progress,
		bool(get_meta("reduced_motion", false))
	)


func _on_pager_settled(next_index: int, committed: bool) -> void:
	if committed:
		_selected_index = next_index
		_apply_selected_theme()
		selected_theme_changed.emit(str(_themes[_selected_index].theme_id))
	else:
		_layout_cover_slots(0, 0.0)
		_incoming_index = -1
		_info_motion.reset()


func _on_enter_pressed() -> void:
	if _transitioning_to_levels or _themes.is_empty():
		return
	_transitioning_to_levels = true
	theme_activated.emit(str(_themes[_selected_index].theme_id))
	_transitioning_to_levels = false


func _input(event: InputEvent) -> void:
	if _transitioning_to_levels or _pager == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			if _is_fixed_action_at(mouse.position) or not _is_cover_interaction_at(mouse.position):
				return
			_begin_pointer_gesture()
		elif _pointer_gesture_active:
			_end_pointer_gesture()
	elif event is InputEventMouseMotion and _pointer_gesture_active:
		_pager.drag_by((event as InputEventMouseMotion).relative.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_fixed_action_at(touch.position) or not _is_cover_interaction_at(touch.position):
				return
			_begin_pointer_gesture()
		elif _pointer_gesture_active:
			_end_pointer_gesture()
	elif event is InputEventScreenDrag and _pointer_gesture_active:
		_pager.drag_by((event as InputEventScreenDrag).relative.x)


func _begin_pointer_gesture() -> void:
	_pointer_gesture_active = true
	_pager.begin()


func _end_pointer_gesture() -> void:
	_pointer_gesture_active = false
	_pager.end()


func _is_fixed_action_at(viewport_position: Vector2) -> bool:
	for action in [menu_button, start_button, bottom_content]:
		if action.visible and action.get_global_rect().has_point(viewport_position):
			return true
	return false


func _is_cover_interaction_at(viewport_position: Vector2) -> bool:
	return current_cover.visible and current_cover.get_global_rect().has_point(viewport_position)


func _on_resized() -> void:
	if _view_model == null:
		return
	if _pager != null:
		_pager.cancel_to_current()
	if _info_motion != null:
		_info_motion.reset()
	_apply_selected_theme()


func _apply_cold_entry_final() -> void:
	_set_entry_interaction_ready(true)


func _cancel_button_motion() -> void:
	menu_button.cancel_motion()
	start_button.cancel_motion()
	if _cover_motion != null:
		_layout_cover_slots(0, 0.0)


func _set_entry_interaction_ready(is_ready: bool) -> void:
	_entry_interaction_ready = is_ready
	var filter := Control.MOUSE_FILTER_STOP if is_ready else Control.MOUSE_FILTER_IGNORE
	menu_button.mouse_filter = filter
	start_button.mouse_filter = filter
