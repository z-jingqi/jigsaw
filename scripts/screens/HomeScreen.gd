class_name HomeScreen
extends Control

signal selected_theme_changed(theme_id: String)
signal theme_activated(theme_id: String)
signal all_themes_requested
signal menu_requested

const PagerControllerScript := preload("res://scripts/screens/HomePagerController.gd")
const CoverMotionScript := preload("res://scripts/screens/HomeCoverMotion.gd")
const ThemeInfoMotionScript := preload("res://scripts/screens/HomeThemeInfoMotion.gd")
const MotionTokenResource := preload("res://themes/motion_tokens.tres")

## Theme titles range from "猫" to "The Classic of Mountains and Seas", so the
## title shrinks to fit its reserved width before it is allowed to wrap.
const TITLE_MAX_FONT_SIZE := 88
const TITLE_MIN_SINGLE_LINE_FONT_SIZE := 60
const TITLE_WRAP_MIN_FONT_SIZE := 36
const TITLE_CONTENT_MARGIN := 104.0

@onready var cover_slots: Control = $CoverSlots
@onready var previous_cover: TextureRect = $CoverSlots/Previous
@onready var current_cover: TextureRect = $CoverSlots/Current
@onready var next_cover: TextureRect = $CoverSlots/Next
@onready var logo: TextureRect = $SafeArea/SafeContent/Header/Logo
@onready var album_button: Button = $SafeArea/SafeContent/Header/AlbumButton
@onready var menu_button: Button = $SafeArea/SafeContent/Header/MenuButton
@onready var bottom_panel: Panel = $BottomPanel
@onready var info_panel: Control = $BottomPanel/InfoLive
@onready var theme_name: Label = $BottomPanel/InfoLive/ThemeName
@onready var page_label: Control = $BottomPanel/InfoLive/PageBadge
@onready var page_text: Label = $BottomPanel/InfoLive/PageBadge/PageText
@onready var caption: Label = $BottomPanel/InfoLive/Caption
@onready var progress_track: Control = $BottomPanel/InfoLive/ProgressTrack
@onready var progress_fill: Control = $BottomPanel/InfoLive/ProgressTrack/ProgressFill
@onready var incoming_info: Control = $BottomPanel/InfoIncoming
@onready var incoming_name: Label = $BottomPanel/InfoIncoming/ThemeName
@onready var incoming_page_label: Control = $BottomPanel/InfoIncoming/PageBadge
@onready var incoming_page_text: Label = $BottomPanel/InfoIncoming/PageBadge/PageText
@onready var incoming_caption: Label = $BottomPanel/InfoIncoming/Caption
@onready var incoming_progress_fill: Control = $BottomPanel/InfoIncoming/ProgressTrack/ProgressFill
@onready var start_button: Button = $BottomPanel/StartButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

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


func _ready() -> void:
	_pager = PagerControllerScript.new(self, MotionTokenResource)
	_pager.drag_updated.connect(_on_pager_drag_updated)
	_pager.page_settled.connect(_on_pager_settled)
	_pager.activation_requested.connect(_on_pager_activation_requested)
	_cover_motion = CoverMotionScript.new(previous_cover, current_cover, next_cover)
	album_button.pressed.connect(all_themes_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)
	start_button.pressed.connect(_on_pager_activation_requested)
	album_button.button_down.connect(_on_fixed_action_started)
	menu_button.button_down.connect(_on_fixed_action_started)
	start_button.button_down.connect(_on_fixed_action_started)
	resized.connect(_on_resized)
	_apply_cold_entry_final()
	_info_motion = ThemeInfoMotionScript.new(info_panel, incoming_info)


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
	_cover_motion.reset()
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
	album_button.set_reduced_motion(enabled)
	menu_button.set_reduced_motion(enabled)
	if enabled:
		if _pager != null:
			_pager.cancel_to_current()
		if animation_player.is_playing():
			_finish_cold_entry()
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
	if bool(get_meta("reduced_motion", false)):
		_apply_cold_entry_final()
		return
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.play(&"enter")
	_set_entry_interaction_ready(false)
	get_tree().create_timer(0.65).timeout.connect(
		func() -> void: _set_entry_interaction_ready(true), CONNECT_ONE_SHOT
	)


func active_motion_count() -> int:
	return (
		(1 if animation_player.is_playing() else 0)
		+ (_pager.active_motion_count() if _pager != null else 0)
		+ album_button.active_motion_count()
		+ menu_button.active_motion_count()
	)


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"animation": str(animation_player.current_animation),
		"animation_playing": animation_player.is_playing(),
		"pager_motion": _pager.active_motion_count() if _pager != null else 0,
		"gesture_progress": _pager.gesture_progress() if _pager != null else 0.0,
		"gesture_offset": _pager.gesture_offset() if _pager != null else 0.0,
		"entry_interaction_ready": _entry_interaction_ready,
		"reduced_motion": bool(get_meta("reduced_motion", false)),
		"progress_ratio": _progress_ratio,
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
		_set_page_number(page_text, 0, 0)
		_set_progress(progress_fill, 0.0, caption)
		return
	var selected: Variant = _themes[_selected_index]
	_set_information(theme_name, page_text, caption, progress_fill, selected, _selected_index)
	_progress_ratio = float(selected.progress.ratio)
	_incoming_index = -1
	_info_motion.reset()
	_set_cover(previous_cover, _theme_at(_selected_index - 1))
	_set_cover(current_cover, selected)
	_set_cover(next_cover, _theme_at(_selected_index + 1))
	_layout_cover_slots(0.0)
	_cover_motion.reset()
	_pager.configure(_themes.size(), _selected_index, maxf(1.0, size.x))


func _theme_at(index: int) -> Variant:
	if _themes.is_empty():
		return null
	return _themes[posmod(index, _themes.size())]


func _set_cover(slot: TextureRect, theme_model: Variant) -> void:
	slot.visible = theme_model != null
	if theme_model != null:
		slot.texture = theme_model.cover_texture


func _layout_cover_slots(offset: float, direction := 0, overlap_ratio := 0.0) -> void:
	var width := maxf(1.0, size.x)
	cover_slots.pivot_offset = size * 0.5
	for pair in [[previous_cover, -1.0], [current_cover, 0.0], [next_cover, 1.0]]:
		var slot: TextureRect = pair[0]
		slot.position = Vector2((float(pair[1]) * width) + offset, 0.0)
		if direction > 0 and slot == next_cover:
			slot.position.x -= width * overlap_ratio
		elif direction < 0 and slot == previous_cover:
			slot.position.x += width * overlap_ratio
		slot.size = size
		slot.pivot_offset = slot.size * 0.5


func _set_information(
	name_label: Label,
	page: Label,
	caption_label: Label,
	fill: Control,
	theme_model: Variant,
	index: int
) -> void:
	_fit_title(name_label, str(theme_model.title))
	_set_page_number(page, index + 1, _themes.size())
	_set_progress(fill, float(theme_model.progress.ratio), caption_label)


## The title never crosses the panel's mid-line, so it first shrinks to fit that
## width on one line; a name too long for even the smallest single-line size
## shrinks further and wraps onto a second line.
func _fit_title(label: Label, text: String) -> void:
	label.text = text
	# Derived from the panel rather than read off the label, so the result does
	# not depend on whether layout has run yet.
	var panel_width := bottom_panel.size.x
	if panel_width <= 1.0:
		panel_width = size.x
	var available := maxf(1.0, panel_width * 0.5 - TITLE_CONTENT_MARGIN)
	var box_height := label.size.y
	if box_height <= 1.0:
		box_height = 144.0
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


func _set_page_number(label: Label, current: int, total: int) -> void:
	var semantic_text := "%02d / %02d" % [current, total]
	label.text = semantic_text
	label.tooltip_text = semantic_text


func _set_progress(fill: Control, ratio: float, caption_label: Label) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	fill.anchor_right = clamped
	fill.offset_right = 0.0
	if caption_label != null:
		caption_label.text = "已完成 %d%%" % roundi(clamped * 100.0)


func _on_pager_drag_updated(direction: int, pager_progress: float, offset: float) -> void:
	_layout_cover_slots(offset, direction, _cover_motion.overlap_ratio(pager_progress))
	_cover_motion.apply(direction, pager_progress, bool(get_meta("reduced_motion", false)))
	if direction == 0:
		_incoming_index = -1
		_info_motion.reset()
		return
	var incoming_index := posmod(_selected_index + direction, _themes.size())
	if incoming_index != _incoming_index:
		_set_information.call(
			incoming_name,
			incoming_page_text,
			incoming_caption,
			incoming_progress_fill,
			_themes[incoming_index],
			incoming_index
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
		_layout_cover_slots(0.0)
		_cover_motion.reset()
		_incoming_index = -1
		_info_motion.reset()


func _on_pager_activation_requested() -> void:
	if _transitioning_to_levels or _themes.is_empty():
		return
	_transitioning_to_levels = true
	if not bool(get_meta("reduced_motion", false)):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(
			current_cover, "scale", Vector2(1.01, 1.01), MotionTokenResource.press_duration
		)
		tween.tween_property(current_cover, "modulate:a", 0.92, MotionTokenResource.press_duration)
		await tween.finished
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
			if _is_fixed_action_at(mouse.position):
				return
			_begin_pointer_gesture()
		elif _pointer_gesture_active:
			_end_pointer_gesture()
	elif event is InputEventMouseMotion and _pointer_gesture_active:
		_pager.drag_by((event as InputEventMouseMotion).relative.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_fixed_action_at(touch.position):
				return
			_begin_pointer_gesture()
		elif _pointer_gesture_active:
			_end_pointer_gesture()
	elif event is InputEventScreenDrag and _pointer_gesture_active:
		_pager.drag_by((event as InputEventScreenDrag).relative.x)


func _begin_pointer_gesture() -> void:
	if not _entry_interaction_ready or animation_player.is_playing():
		_finish_cold_entry()
	_pointer_gesture_active = true
	_pager.begin()


func _end_pointer_gesture() -> void:
	_pointer_gesture_active = false
	_pager.end()


## The bottom panel owns its own presses, so a drag started there must not also
## page the carousel.
func _is_fixed_action_at(viewport_position: Vector2) -> bool:
	for action in [album_button, menu_button, start_button, bottom_panel]:
		if action.visible and action.get_global_rect().has_point(viewport_position):
			return true
	return false


func _on_resized() -> void:
	if _view_model == null:
		return
	if _pager != null:
		_pager.cancel_to_current()
	if _info_motion != null:
		_info_motion.reset()
	_apply_selected_theme()


func _apply_cold_entry_final() -> void:
	animation_player.play(&"enter")
	animation_player.seek(MotionTokenResource.home_cold_duration, true)
	animation_player.pause()
	_set_entry_interaction_ready(true)


func _finish_cold_entry() -> void:
	_apply_cold_entry_final()


func _cancel_button_motion() -> void:
	album_button.cancel_motion()
	menu_button.cancel_motion()
	current_cover.scale = Vector2.ONE
	current_cover.modulate.a = 1.0


func _on_fixed_action_started() -> void:
	if animation_player.is_playing():
		_finish_cold_entry()


func _set_entry_interaction_ready(is_ready: bool) -> void:
	_entry_interaction_ready = is_ready
	var filter := Control.MOUSE_FILTER_STOP if is_ready else Control.MOUSE_FILTER_IGNORE
	album_button.mouse_filter = filter
	menu_button.mouse_filter = filter
	start_button.mouse_filter = filter
