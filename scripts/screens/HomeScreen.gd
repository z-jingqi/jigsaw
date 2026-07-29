class_name HomeScreen
extends Control

signal selected_theme_changed(theme_id: String)
signal theme_activated(theme_id: String)
signal all_themes_requested
signal menu_requested
signal album_requested

const PagerControllerScript := preload("res://scripts/screens/HomePagerController.gd")
const ThemeInfoMotionScript := preload("res://scripts/screens/HomeThemeInfoMotion.gd")
const MotionTokenResource := preload("res://themes/motion_tokens.tres")
const ThemeTokenResource := preload("res://themes/jigcat_tokens.tres")

@onready var cover_slots: Control = $CoverSlots
@onready var previous_cover: TextureRect = $CoverSlots/Previous
@onready var current_cover: TextureRect = $CoverSlots/Current
@onready var next_cover: TextureRect = $CoverSlots/Next
@onready var gesture_catcher: Control = $GestureCatcher
@onready var logo: TextureRect = $SafeArea/SafeContent/Header/Logo
@onready var album_button: Button = $SafeArea/SafeContent/Header/AlbumButton
@onready var menu_button: Button = $SafeArea/SafeContent/Header/MenuButton
@onready var info_panel: Control = $SafeArea/SafeContent/InfoPanel
@onready var theme_name: Label = $SafeArea/SafeContent/InfoPanel/ThemeName
@onready var progress: ThemeProgress = $SafeArea/SafeContent/InfoPanel/ThemeProgress
@onready var incoming_info: Control = $SafeArea/SafeContent/InfoIncoming
@onready var incoming_name: Label = $SafeArea/SafeContent/InfoIncoming/ThemeName
@onready var incoming_progress: ThemeProgress = $SafeArea/SafeContent/InfoIncoming/ThemeProgress
@onready var page_label: Control = $SafeArea/SafeContent/PageLabel
@onready var current_page_label: Label = $SafeArea/SafeContent/PageLabel/PageRow/CurrentPage
@onready var total_page_label: Label = $SafeArea/SafeContent/PageLabel/PageRow/TotalPage
@onready var incoming_page_label: Control = $SafeArea/SafeContent/PageIncoming
@onready
var incoming_current_page_label: Label = $SafeArea/SafeContent/PageIncoming/PageRow/CurrentPage
@onready var incoming_total_page_label: Label = $SafeArea/SafeContent/PageIncoming/PageRow/TotalPage
@onready var all_themes_button: Button = $SafeArea/SafeContent/AllThemesButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _themes: Array = []
var _selected_index := 0
var _pager: Variant
var _info_motion: Variant
var _incoming_index := -1
var _first_entry_played := false
var _entry_interaction_ready := true
var _transitioning_to_levels := false


func _ready() -> void:
	_pager = PagerControllerScript.new(self, MotionTokenResource)
	_pager.drag_updated.connect(_on_pager_drag_updated)
	_pager.page_settled.connect(_on_pager_settled)
	_pager.activation_requested.connect(_on_pager_activation_requested)
	gesture_catcher.gui_input.connect(_on_gesture_input)
	album_button.pressed.connect(album_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)
	all_themes_button.pressed.connect(all_themes_requested.emit)
	album_button.button_down.connect(_on_fixed_action_started)
	menu_button.button_down.connect(_on_fixed_action_started)
	all_themes_button.button_down.connect(_on_fixed_action_started)
	resized.connect(_on_resized)
	_apply_cold_entry_final()
	_info_motion = ThemeInfoMotionScript.new(
		theme_name,
		progress,
		page_label,
		incoming_info,
		incoming_name,
		incoming_progress,
		incoming_page_label
	)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	if not _first_entry_played:
		play_cold_entry()


func navigation_exit(_context: Dictionary) -> void:
	if _pager != null:
		_pager.finish_to_current()
	_cancel_button_motion()
	progress.finish_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	if not is_active and _pager != null:
		_pager.finish_to_current()
	if not is_active:
		_cancel_button_motion()


func set_reduced_motion(enabled: bool) -> void:
	set_meta("reduced_motion", enabled)
	progress.reduced_motion = enabled
	incoming_progress.reduced_motion = enabled
	album_button.set_reduced_motion(enabled)
	menu_button.set_reduced_motion(enabled)
	all_themes_button.set_reduced_motion(enabled)
	if enabled:
		if _pager != null:
			_pager.cancel_to_current()
		if animation_player.is_playing() or progress.active_motion_count() > 0:
			_finish_cold_entry()
		incoming_progress.finish_motion()
		_cancel_button_motion()


func set_view_model(view_model: Variant) -> void:
	var previous_theme_id := (
		str(_themes[_selected_index].theme_id)
		if not _themes.is_empty() and _selected_index < _themes.size()
		else ""
	)
	_view_model = view_model
	_themes = view_model.themes
	_selected_index = clampi(int(view_model.selected_index), 0, maxi(0, _themes.size() - 1))
	var selected_theme_id := (
		str(_themes[_selected_index].theme_id) if not _themes.is_empty() else ""
	)
	_apply_selected_theme(previous_theme_id != "" and previous_theme_id == selected_theme_id)


func play_cold_entry() -> void:
	if _first_entry_played:
		return
	_first_entry_played = true
	if bool(get_meta("reduced_motion", false)):
		_apply_cold_entry_final()
		progress.finish_motion()
		return
	animation_player.play(&"RESET")
	animation_player.advance(0.0)
	animation_player.play(&"enter")
	progress.play_cold_start(0.42)
	_set_entry_interaction_ready(false)
	get_tree().create_timer(0.65).timeout.connect(
		func() -> void: _set_entry_interaction_ready(true), CONNECT_ONE_SHOT
	)


func active_motion_count() -> int:
	var animation_active := 1 if animation_player.is_playing() else 0
	return (
		animation_active
		+ (_pager.active_motion_count() if _pager != null else 0)
		+ progress.active_motion_count()
		+ album_button.active_motion_count()
		+ menu_button.active_motion_count()
		+ all_themes_button.active_motion_count()
	)


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"animation": str(animation_player.current_animation),
		"animation_playing": animation_player.is_playing(),
		"pager_motion": _pager.active_motion_count() if _pager != null else 0,
		"progress_motion": progress.active_motion_count(),
		"gesture_progress": _pager.gesture_progress() if _pager != null else 0.0,
		"gesture_offset": _pager.gesture_offset() if _pager != null else 0.0,
		"entry_interaction_ready": _entry_interaction_ready,
		"reduced_motion": bool(get_meta("reduced_motion", false)),
	}


func debug_drag(delta_x: float, elapsed := 0.016) -> void:
	if _pager == null:
		return
	_pager.drag_by(delta_x, elapsed)


func debug_begin_drag() -> void:
	if _pager != null:
		_pager.begin()


func debug_end_drag() -> void:
	if _pager != null:
		_pager.end()


func _apply_selected_theme(animate_progress: bool) -> void:
	if _themes.is_empty():
		theme_name.text = ""
		_set_page_number(0, 0)
		return
	var selected = _themes[_selected_index]
	_set_information(theme_name, progress, selected, animate_progress)
	_incoming_index = -1
	_info_motion.reset()
	theme = ThemeTokenResource.theme_for_variant(
		(
			ThemeTokenResource.TextVariant.ON_DARK
			if selected.home_ui_variant == &"on_dark"
			else ThemeTokenResource.TextVariant.ON_LIGHT
		)
	)
	_set_page_number(_selected_index + 1, _themes.size())
	_set_cover(previous_cover, _theme_at(_selected_index - 1))
	_set_cover(current_cover, selected)
	_set_cover(next_cover, _theme_at(_selected_index + 1))
	_layout_cover_slots(0.0)
	_pager.configure(_themes.size(), _selected_index, maxf(1.0, size.x))


func _theme_at(index: int) -> Variant:
	return _themes[index] if index >= 0 and index < _themes.size() else null


func _set_cover(slot: TextureRect, theme: Variant) -> void:
	slot.visible = theme != null
	if theme == null:
		return
	slot.texture = theme.cover_texture


func _layout_cover_slots(offset: float) -> void:
	var width := maxf(1.0, size.x)
	cover_slots.pivot_offset = size * 0.5
	for pair in [[previous_cover, -1.0], [current_cover, 0.0], [next_cover, 1.0]]:
		var slot: TextureRect = pair[0]
		slot.position = Vector2((float(pair[1]) * width) + offset, 0.0)
		slot.size = size
		slot.pivot_offset = slot.size * 0.5


func _on_pager_drag_updated(direction: int, pager_progress: float, offset: float) -> void:
	_layout_cover_slots(offset)
	if direction == 0:
		_incoming_index = -1
		_info_motion.reset()
		return
	var incoming_index := _selected_index + direction
	if incoming_index >= 0 and incoming_index < _themes.size():
		if incoming_index != _incoming_index:
			_set_information(incoming_name, incoming_progress, _themes[incoming_index], false)
			_set_incoming_page_number(incoming_index + 1, _themes.size())
			_incoming_index = incoming_index
	else:
		_incoming_index = -1
	_info_motion.apply(
		direction if _incoming_index >= 0 else 0,
		pager_progress,
		bool(get_meta("reduced_motion", false))
	)


func _on_pager_settled(next_index: int, committed: bool) -> void:
	if committed:
		_selected_index = next_index
		_apply_selected_theme(false)
		selected_theme_changed.emit(str(_themes[_selected_index].theme_id))
	else:
		_layout_cover_slots(0.0)
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


func transition_source_rect() -> Rect2:
	return current_cover.get_global_rect()


func transition_source_texture() -> Texture2D:
	return current_cover.texture


func _set_information(
	name_label: Label, theme_progress: ThemeProgress, theme_model: Variant, animate_progress: bool
) -> void:
	name_label.text = str(theme_model.title)
	theme_progress.set_view_model(theme_model.progress)
	if not animate_progress:
		theme_progress.finish_motion()


func _set_page_number(current: int, total: int) -> void:
	current_page_label.text = "%02d" % current
	total_page_label.text = " / %02d" % total
	var semantic_text := "%02d / %02d" % [current, total]
	page_label.tooltip_text = semantic_text
	page_label.set_meta("accessibility_name", semantic_text)


func _set_incoming_page_number(current: int, total: int) -> void:
	incoming_current_page_label.text = "%02d" % current
	incoming_total_page_label.text = " / %02d" % total
	var semantic_text := "%02d / %02d" % [current, total]
	incoming_page_label.tooltip_text = semantic_text
	incoming_page_label.set_meta("accessibility_name", semantic_text)


func _on_gesture_input(event: InputEvent) -> void:
	if _transitioning_to_levels or _pager == null:
		return
	if not _entry_interaction_ready:
		_finish_cold_entry()
		return
	if animation_player.is_playing() or progress.active_motion_count() > 0:
		_finish_cold_entry()
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_pager.begin()
			else:
				_pager.end()
	elif event is InputEventMouseMotion:
		_pager.drag_by((event as InputEventMouseMotion).relative.x)
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_pager.begin()
		else:
			_pager.end()
	elif event is InputEventScreenDrag:
		_pager.drag_by((event as InputEventScreenDrag).relative.x)


func _on_resized() -> void:
	if _view_model == null:
		return
	if _pager != null:
		_pager.cancel_to_current()
	if _info_motion != null:
		_info_motion.reset()
	_apply_selected_theme(false)
	if _info_motion != null:
		_info_motion.capture_layout()


func _apply_cold_entry_final() -> void:
	animation_player.play(&"enter")
	animation_player.seek(MotionTokenResource.home_cold_duration, true)
	animation_player.pause()
	_set_entry_interaction_ready(true)


func _finish_cold_entry() -> void:
	_apply_cold_entry_final()
	progress.finish_motion()


func _cancel_button_motion() -> void:
	album_button.cancel_motion()
	menu_button.cancel_motion()
	all_themes_button.cancel_motion()
	current_cover.scale = Vector2.ONE
	current_cover.modulate.a = 1.0


func _on_fixed_action_started() -> void:
	if animation_player.is_playing() or progress.active_motion_count() > 0:
		_finish_cold_entry()


func _set_entry_interaction_ready(is_ready: bool) -> void:
	_entry_interaction_ready = is_ready
	var filter := Control.MOUSE_FILTER_STOP if is_ready else Control.MOUSE_FILTER_IGNORE
	album_button.mouse_filter = filter
	menu_button.mouse_filter = filter
	all_themes_button.mouse_filter = filter
