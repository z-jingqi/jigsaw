extends Control
signal close_requested
signal theme_selected(theme_id: String)

const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")
const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
var _themes: Array = []
const Pager := preload("res://scripts/ui/navigation/WindowedDotPager.gd")
@export var close_as_sheet := true
var _source_rect := Rect2()
var _source_texture: Texture2D
var _page := 0
var _visual_page := 0.0
const Gesture := preload("res://scripts/ui/navigation/PagingGesture.gd")
var _gesture := Gesture.new()
const Arena := preload("res://scripts/ui/navigation/GestureArena.gd")
var _pager: Control
var _motion: Tween
var _reduced_motion := false
var _enabled := true
var _pointer := -2
var _dragging := false


func _ready() -> void:
	$Title.text = GameStrings.ui_text("all_themes")
	$EmptyState.text = GameStrings.ui_text("no_topics")
	$CloseButton.accessibility_name = GameStrings.ui_text("close_themes")
	$CloseButton.pressed.connect(close_requested.emit)
	_pager = Pager.new()
	_pager.name = "Pager"
	add_child(_pager)
	_pager.page_requested.connect(_request_page)
	resized.connect(_on_resized)


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_themes = payload.view_model.themes
	# The retained navigation field now stores a zero-based page, not pixels.
	_page = clampi(int(payload.get("scroll_position", 0)), 0, maxi(0, _page_count() - 1))
	_visual_page = float(_page)
	set_reduced_motion(bool(context.get("reduced_motion", false)))
	_build()
	_layout()


func navigation_set_active(enabled: bool) -> void:
	_enabled = enabled
	set_process_input(enabled)
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_pager.set_interaction_enabled(enabled)
	if not enabled:
		_freeze()
	elif is_node_ready():
		_animate_to_target()


func navigation_prepare_transition() -> void:
	_freeze()


func navigation_exit(_context: Dictionary) -> void:
	_freeze()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _pager != null:
		_pager.set_reduced_motion(enabled)
	if enabled:
		_freeze()
		_apply_visual_page(float(_page))


func scroll_position() -> int:
	return _page


func active_motion_count() -> int:
	return (
		int(_motion != null and _motion.is_valid() and _motion.is_running())
		+ (_pager.active_motion_count() if _pager != null else 0)
	)


func _page_size() -> int:
	return 4


func transition_source_rect() -> Rect2:
	return _source_rect


func transition_source_texture() -> Texture2D:
	return _source_texture


func _page_count() -> int:
	return ceili(float(_themes.size()) / _page_size())


func _build() -> void:
	for child in $Pages.get_children():
		$Pages.remove_child(child)
		child.queue_free()
	$EmptyState.visible = _themes.is_empty()
	for index in _page_count():
		var layer := Control.new()
		layer.name = "Page%d" % index
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Pages.add_child(layer)
	for index in _themes.size():
		var model: Variant = _themes[index]
		var tile := Button.new()
		tile.name = str(model.theme_id)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.focus_mode = Control.FOCUS_ALL
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tile.disabled = not model.playable
		tile.accessibility_name = (
			"%s · %s"
			% [
				model.title,
				(
					GameStrings.ui_text("enter_topic")
					if model.playable
					else GameStrings.ui_text("coming_soon")
				)
			]
		)
		Clean.button(tile)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Clean.INK
		focus.set_border_width_all(1)
		focus.set_corner_radius_all(8)
		tile.add_theme_stylebox_override("focus", focus)
		var cover := TextureRect.new()
		cover.name = "Cover"
		cover.texture = model.cover_texture
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not model.playable:
			cover.modulate = Color(1, 1, 1, 0.68)
		tile.add_child(cover)
		var label := Label.new()
		label.name = "Title"
		label.text = model.title
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
		var status := Label.new()
		status.name = "Status"
		status.text = GameStrings.ui_text("coming_soon") if not model.playable else ""
		status.visible = not model.playable
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(status)
		tile.pressed.connect(
			func() -> void:
				if _enabled and not _dragging:
					_source_rect = cover.get_global_rect()
					_source_texture = cover.texture
					_freeze()
					_page = index / _page_size()
					theme_selected.emit(str(model.theme_id))
		)
		$Pages.get_child(index / _page_size()).add_child(tile)


func _layout() -> void:
	if _pager == null:
		return
	var u := Metrics.unit(get_viewport_rect().size)
	var canvas := Clean.canvas_scale(size, get_window())
	var safe := Clean.safe_insets(size)
	Buttons.place_navigation($CloseButton, self)
	var usable_width := size.x - safe.x - safe.z
	var width := minf(usable_width - 48.0 * u, 540.0 * u)
	var left := safe.x + (usable_width - width) * 0.5
	var top := safe.y + maxf(93.0 * u, Buttons.header_center_y(size) + 48.0 * u)
	$Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$Title.position = Vector2(left + $CloseButton.size.x, $CloseButton.position.y)
	$Title.size = Vector2(width - $CloseButton.size.x, $CloseButton.size.y)
	Clean.label($Title, roundi(Metrics.TITLE * u))
	var pages_top := top + _extra_header_height(width, canvas)
	var pager_height := Metrics.TOUCH * u
	_pager.position = Vector2(left, size.y - safe.w - pager_height - 16.0 * u)
	_pager.size = Vector2(width, pager_height)
	_pager.configure(_page_count(), _page)
	_pager.visible = _page_count() > 1
	$Pages.position = Vector2(left, pages_top)
	$Pages.size = Vector2(width, maxf(1, _pager.position.y - pages_top - 16.0 * u))
	$EmptyState.position = Vector2(left, pages_top + 80.0 * u)
	$EmptyState.size = Vector2(width, 100.0 * u)
	Clean.label($EmptyState, roundi(Metrics.BODY * u), true)
	var gap := 16.0 * u
	var row_gap := 16.0 * u
	var columns := 1 if _page_size() == 1 else 2
	var rows := ceili(float(_page_size()) / columns)
	var cell := Vector2(
		(width - gap * (columns - 1)) / columns, ($Pages.size.y - row_gap * (rows - 1)) / rows
	)
	for page_index in $Pages.get_child_count():
		var layer := $Pages.get_child(page_index) as Control
		layer.size = $Pages.size
		for index in layer.get_child_count():
			var tile := layer.get_child(index) as Button
			_layout_tile(tile, cell, u, canvas)
			tile.position = Vector2(
				(index % columns) * (cell.x + gap), (index / columns) * (cell.y + row_gap)
			)
	_apply_visual_page(_visual_page)


func _extra_header_height(_width: float, _canvas: float) -> float:
	return 0.0


func _layout_tile(tile: Button, cell: Vector2, u: float, _canvas: float) -> void:
	var title_height := Metrics.BODY * 5.0 * u
	var status_height := 24.0 * u
	var caption_height := (
		title_height + (status_height if tile.get_node("Status").visible else 0.0) + 32.0 * u
	)
	var image_height := maxf(1, minf((cell.x - 20.0 * u) * 1.3, cell.y - caption_height))
	var image_width := cell.x - 20.0 * u
	tile.custom_minimum_size = Vector2.ZERO
	tile.size = cell
	var cover := tile.get_node("Cover") as TextureRect
	if cover.texture != null:
		var ratio := cover.texture.get_size().x / cover.texture.get_size().y
		image_width = minf(image_width, image_height * ratio)
		image_height = image_width / ratio
	cover.position = Vector2((cell.x - image_width) * 0.5, 8.0 * u)
	cover.size = Vector2(image_width, image_height)
	if cover.material != null:
		cover.material.set_shader_parameter("aspect", image_width / image_height)
	var title := tile.get_node("Title") as Label
	title.position = Vector2(16.0 * u, image_height + 16.0 * u)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 3
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size = Vector2(cell.x - 32.0 * u, title_height)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Clean.label(title, roundi(Metrics.BODY * u))
	TitleLayout.fit(title, title.size, roundi(Metrics.BODY * u), 3)
	var status := tile.get_node("Status") as Label
	status.position = Vector2(16.0 * u, title.position.y + title_height)
	status.size = Vector2(cell.x - 32.0 * u, status_height)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Clean.label(status, roundi(Metrics.CAPTION * u), true)


func _request_page(index: int) -> void:
	if not _enabled or index < 0 or index >= _page_count():
		return
	if _pointer != -2:
		_dragging = true
	_reset_drag()
	_page = index
	_pager.configure(_page_count(), _page)
	_animate_to_target()


func _animate_to_target() -> void:
	_pause_motion()
	if _reduced_motion or is_equal_approx(_visual_page, float(_page)):
		_apply_visual_page(float(_page))
		return
	var distance := absf(_visual_page - float(_page))
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(
		_apply_visual_page, _visual_page, float(_page), clampf(distance * 0.24, 0.08, 0.36)
	)
	_motion.finished.connect(func() -> void: _motion = null)


func _apply_visual_page(value: float) -> void:
	_visual_page = value
	for index in $Pages.get_child_count():
		var layer := $Pages.get_child(index) as Control
		layer.position = Vector2((float(index) - value) * $Pages.size.x, 0)
		# Only rendered layers are hit-testable; no full-animation input lock.
		layer.visible = absf(float(index) - value) < 1.0


func _pause_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _reset_drag() -> void:
	Arena.release(self)
	if _dragging:
		for layer in $Pages.get_children():
			for tile in layer.get_children():
				(tile as Button).set_pressed_no_signal(false)
	_pointer = -2
	_dragging = false


func _freeze() -> void:
	if _pointer != -2:
		_page = _gesture.origin_page
		_dragging = true
		if _pager.has_method("gesture_finished"):
			_pager.gesture_finished(false, _page)
	_pause_motion()
	_reset_drag()


func _on_resized() -> void:
	var resume := active_motion_count() > 0 or _pointer != -2
	_freeze()
	_layout()
	if resume:
		_animate_to_target()


func _input(event: InputEvent) -> void:
	if (
		close_as_sheet
		and _enabled
		and is_visible_in_tree()
		and event is InputEventKey
		and event.keycode == KEY_BACK
		and event.pressed
		and not event.echo
		and Arena._current(get_viewport().get_instance_id()).is_empty()
	):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if Arena.block_secondary(get_viewport(), event):
		get_viewport().set_input_as_handled()
		return
	if not _enabled or not is_visible_in_tree() or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position, -1)
		elif _pointer == -1:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _pointer == -1:
		_drag_to(event.position)
	elif event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			_cancel_drag()
		elif event.pressed:
			_begin_drag(event.position, event.index)
		elif event.index == _pointer:
			_end_drag(event.position)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_drag_to(event.position)


func _begin_drag(point: Vector2, pointer: int) -> void:
	if _pointer != -2:
		_cancel_drag()
		return
	if not $Pages.get_global_rect().has_point(point):
		return
	var native := Clean.canvas_scale(size, get_window())
	if Arena.is_edge_candidate(self, point, native) or not Arena.reserve(self, pointer):
		return
	_pause_motion()
	_gesture.begin(
		point, _visual_page, $Pages.size.x, Clean.canvas_scale(size, get_window()), _page_count()
	)
	_page = _gesture.origin_page
	_pager.configure(_page_count(), _page)
	_pointer = pointer


func _drag_to(point: Vector2) -> void:
	if not Arena.owns(self, _pointer):
		return
	var value: float = _gesture.move(point)
	if _gesture.axis != 0:
		_dragging = true
		for layer in $Pages.get_children():
			for tile in layer.get_children():
				(tile as Button).set_pressed_no_signal(false)
	if _gesture.axis == 1:
		_apply_visual_page(value)
		if _pager.has_method("gesture_progress"):
			_pager.gesture_progress(value)
		get_viewport().set_input_as_handled()


func _end_drag(point: Vector2) -> void:
	var was_dragging := _gesture.axis != 0
	var target: int = _gesture.release_target(point)
	if was_dragging:
		get_viewport().set_input_as_handled()
	_reset_drag()
	if was_dragging:
		if _pager.has_method("gesture_finished"):
			_pager.gesture_finished(target != _gesture.origin_page, target)
		_request_page(target)
	else:
		# GUI tap gets first chance to pick the currently visible moving card.
		call_deferred("_resume_after_tap")


func _resume_after_tap() -> void:
	if _enabled and is_visible_in_tree() and _motion == null:
		_animate_to_target()


func _cancel_drag() -> void:
	if _pointer == -2:
		return
	var target: int = _gesture.origin_page
	_dragging = true
	if _pager.has_method("gesture_finished"):
		_pager.gesture_finished(false, target)
	_reset_drag()
	_request_page(target)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if (
		what == NOTIFICATION_WM_GO_BACK_REQUEST
		and close_as_sheet
		and _enabled
		and is_visible_in_tree()
		and Arena._current(get_viewport().get_instance_id()).is_empty()
	):
		close_requested.emit()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_freeze()
	elif (
		what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]
		and _enabled
		and is_visible_in_tree()
	):
		_animate_to_target()
