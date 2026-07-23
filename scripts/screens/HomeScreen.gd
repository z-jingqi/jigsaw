class_name HomeScreen
extends Control

signal selected_theme_changed(theme_id: String)
signal theme_activated(theme_id: String)
signal all_themes_requested()
signal menu_requested()

const PagerControllerScript := preload("res://scripts/screens/HomePagerController.gd")
const MotionTokenResource := preload("res://themes/motion_tokens.tres")
const ThemeTokenResource := preload("res://themes/jigcat_tokens.tres")

@onready var cover_slots: Control = $CoverSlots
@onready var previous_cover: TextureRect = $CoverSlots/Previous
@onready var current_cover: TextureRect = $CoverSlots/Current
@onready var next_cover: TextureRect = $CoverSlots/Next
@onready var gesture_catcher: Control = $GestureCatcher
@onready var logo: Label = $SafeArea/SafeContent/Header/Logo
@onready var menu_button: Button = $SafeArea/SafeContent/Header/MenuButton
@onready var info_panel: Control = $SafeArea/SafeContent/InfoPanel
@onready var theme_name: Label = $SafeArea/SafeContent/InfoPanel/ThemeName
@onready var progress: ThemeProgress = $SafeArea/SafeContent/InfoPanel/ThemeProgress
@onready var incoming_info: Control = $SafeArea/SafeContent/InfoIncoming
@onready var incoming_name: Label = $SafeArea/SafeContent/InfoIncoming/ThemeName
@onready var incoming_progress: ThemeProgress = $SafeArea/SafeContent/InfoIncoming/ThemeProgress
@onready var page_label: Label = $SafeArea/SafeContent/PageLabel
@onready var all_themes_button: Button = $SafeArea/SafeContent/AllThemesButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _view_model: Variant
var _themes: Array = []
var _selected_index := 0
var _pager: Variant
var _first_entry_played := false
var _entry_interaction_ready := true
var _transitioning_to_levels := false


func _ready() -> void:
	_pager = PagerControllerScript.new(self, MotionTokenResource)
	_pager.drag_updated.connect(_on_pager_drag_updated)
	_pager.page_settled.connect(_on_pager_settled)
	_pager.activation_requested.connect(_on_pager_activation_requested)
	gesture_catcher.gui_input.connect(_on_gesture_input)
	menu_button.pressed.connect(menu_requested.emit)
	all_themes_button.pressed.connect(all_themes_requested.emit)
	resized.connect(_on_resized)
	animation_player.play(&"RESET")
	animation_player.advance(0.0)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	if payload.has("view_model"):
		set_view_model(payload["view_model"])
	if not _first_entry_played:
		play_cold_entry()


func navigation_exit(_context: Dictionary) -> void:
	if _pager != null:
		_pager.cancel_motion()


func navigation_set_active(is_active: bool) -> void:
	visible = is_active
	mouse_filter = Control.MOUSE_FILTER_STOP if is_active else Control.MOUSE_FILTER_IGNORE
	if not is_active and _pager != null:
		_pager.cancel_to_current()


func set_reduced_motion(enabled: bool) -> void:
	set_meta("reduced_motion", enabled)
	progress.reduced_motion = enabled


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	_themes = view_model.themes
	_selected_index = clampi(int(view_model.selected_index), 0, maxi(0, _themes.size() - 1))
	_apply_selected_theme(false)


func play_cold_entry() -> void:
	if _first_entry_played:
		return
	_first_entry_played = true
	if bool(get_meta("reduced_motion", false)):
		animation_player.play(&"enter")
		animation_player.seek(0.9, true)
		progress.play_cold_start()
		return
	animation_player.play(&"enter")
	_entry_interaction_ready = false
	get_tree().create_timer(0.65).timeout.connect(func() -> void: _entry_interaction_ready = true, CONNECT_ONE_SHOT)


func active_motion_count() -> int:
	var animation_active := 1 if animation_player.is_playing() else 0
	return animation_active + (_pager.active_motion_count() if _pager != null else 0) + progress.active_motion_count()


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"animation": str(animation_player.current_animation),
		"animation_playing": animation_player.is_playing(),
		"pager_motion": _pager.active_motion_count() if _pager != null else 0,
		"progress_motion": progress.active_motion_count(),
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


func _apply_selected_theme(animate_information: bool) -> void:
	if _themes.is_empty():
		theme_name.text = ""
		page_label.text = "0 / 0"
		return
	var selected = _themes[_selected_index]
	_set_information(info_panel, theme_name, progress, selected)
	incoming_info.visible = false
	theme = ThemeTokenResource.theme_for_variant(ThemeTokenResource.TextVariant.ON_DARK if selected.home_ui_variant == &"on_dark" else ThemeTokenResource.TextVariant.ON_LIGHT)
	page_label.text = "%02d / %02d" % [_selected_index + 1, _themes.size()]
	_set_cover(previous_cover, _theme_at(_selected_index - 1))
	_set_cover(current_cover, selected)
	_set_cover(next_cover, _theme_at(_selected_index + 1))
	_layout_cover_slots(0.0)
	_pager.configure(_themes.size(), _selected_index, maxf(1.0, size.x))
	if animate_information:
		_animate_information_in()


func _theme_at(index: int) -> Variant:
	return _themes[index] if index >= 0 and index < _themes.size() else null


func _set_cover(slot: TextureRect, theme: Variant) -> void:
	slot.visible = theme != null
	if theme == null:
		return
	slot.texture = theme.cover_texture


func _layout_cover_slots(offset: float) -> void:
	var width := maxf(1.0, size.x)
	for pair in [[previous_cover, -1.0], [current_cover, 0.0], [next_cover, 1.0]]:
		var slot: TextureRect = pair[0]
		slot.position = Vector2((float(pair[1]) * width) + offset, 0.0)
		slot.size = size


func _on_pager_drag_updated(direction: int, pager_progress: float, offset: float) -> void:
	_layout_cover_slots(offset)
	var outgoing_visibility := 1.0 - smoothstep(0.05, 0.55, pager_progress)
	var incoming_visibility := smoothstep(0.35, 1.0, pager_progress)
	var incoming_index := _selected_index + direction
	if incoming_index >= 0 and incoming_index < _themes.size():
		_set_information(incoming_info, incoming_name, incoming_progress, _themes[incoming_index])
		incoming_info.visible = true
	else:
		incoming_info.visible = false
	info_panel.modulate.a = outgoing_visibility
	page_label.modulate.a = outgoing_visibility
	incoming_info.modulate.a = incoming_visibility
	info_panel.position.x = -float(direction) * size.x * pager_progress
	incoming_info.position.x = float(direction) * size.x * (1.0 - pager_progress)
	page_label.position.x = -float(direction) * size.x * pager_progress * 0.55


func _on_pager_settled(next_index: int, committed: bool) -> void:
	if committed:
		_selected_index = next_index
		_apply_selected_theme(true)
		selected_theme_changed.emit(str(_themes[_selected_index].theme_id))
	else:
		_layout_cover_slots(0.0)
		info_panel.modulate.a = 1.0
		page_label.modulate.a = 1.0
		info_panel.position.x = 0.0
		incoming_info.visible = false
		page_label.position.x = 0.0


func _on_pager_activation_requested() -> void:
	if _transitioning_to_levels or _themes.is_empty():
		return
	_transitioning_to_levels = true
	if not bool(get_meta("reduced_motion", false)):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(current_cover, "scale", Vector2(1.03, 1.03), MotionTokenResource.home_to_levels_duration)
		tween.tween_property(current_cover, "modulate:a", 0.82, MotionTokenResource.press_duration)
		await tween.finished
	theme_activated.emit(str(_themes[_selected_index].theme_id))
	_transitioning_to_levels = false


func _animate_information_in() -> void:
	if bool(get_meta("reduced_motion", false)):
		info_panel.modulate.a = 1.0
		page_label.modulate.a = 1.0
		return
	info_panel.modulate.a = 0.0
	page_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(info_panel, "modulate:a", 1.0, MotionTokenResource.content_duration)
	tween.tween_property(page_label, "modulate:a", 1.0, MotionTokenResource.content_duration).set_delay(0.04)


func _set_information(panel: Control, name_label: Label, theme_progress: ThemeProgress, theme_model: Variant) -> void:
	panel.position.x = 0.0
	name_label.text = str(theme_model.title)
	theme_progress.set_view_model(theme_model.progress)


func _on_gesture_input(event: InputEvent) -> void:
	if _transitioning_to_levels or _pager == null:
		return
	if not _entry_interaction_ready:
		animation_player.seek(0.9, true)
		_entry_interaction_ready = true
		return
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
	_apply_selected_theme(false)
