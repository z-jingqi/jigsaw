class_name HomeScreen
extends "res://scripts/screens/home/ThemeLibraryScreen.gd"

signal selected_theme_changed(theme_id: String)
signal theme_switch_started
signal theme_activated(theme_id: String)
signal menu_requested
signal all_themes_requested
signal album_requested

const MenuScene := preload("res://scenes/screens/home/HomeMenu.tscn")
var album_available: Callable
var _selected_index := 0
var _menu: Control
var _storage_notice: Label
var _storage_key := ""


func _ready() -> void:
	super._ready()
	_storage_notice = Label.new()
	_storage_notice.name = "StorageNotice"
	_storage_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storage_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_notice.hide()
	add_child(_storage_notice)
	$CloseButton.hide()
	$Title.hide()
	$MoreButton.accessibility_name = GameStrings.ui_text("more_actions")
	$MoreButton.pressed.connect(_open_menu)
	theme_selected.connect(_activate_theme)
	_menu = MenuScene.instantiate()
	_menu.can_interact = _can_open_menu
	add_child(_menu)
	_menu.action_requested.connect(_on_menu_action)
	_menu.closed.connect(_resume_after_menu)
	_layout()


func _page_size() -> int:
	return 1


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	var model: Variant = payload.view_model
	var adjusted := payload.duplicate()
	adjusted.scroll_position = model.selected_index
	super.navigation_enter(adjusted, context)
	_selected_index = _page


func set_view_model(model: Variant) -> void:
	_themes = model.themes
	_selected_index = clampi(model.selected_index, 0, maxi(0, _themes.size() - 1))
	_page = _selected_index
	_visual_page = float(_page)
	_build()
	_layout()


func select_theme(theme_id: String) -> void:
	for index in _themes.size():
		if str(_themes[index].theme_id) == theme_id:
			_request_page(index)
			return


func _request_page(index: int) -> void:
	if not _enabled or index < 0 or index >= _page_count():
		return
	var changed := _selected_index != index
	super._request_page(index)
	_selected_index = _page
	if changed:
		theme_switch_started.emit()
		selected_theme_changed.emit(str(_themes[_selected_index].theme_id))


func _activate_theme(theme_id: String) -> void:
	_selected_index = _page
	selected_theme_changed.emit(theme_id)
	theme_activated.emit(theme_id)


func _layout() -> void:
	super._layout()
	if not is_node_ready():
		return
	$CloseButton.hide()
	$Title.hide()
	Buttons.place_navigation($MoreButton, self, true)
	var unit := Clean.canvas_scale(size, get_window())
	var safe := Clean.safe_insets(size)
	$BrandLogo.position = Vector2(
		safe.x + 24.0 * unit, $MoreButton.position.y + ($MoreButton.size.y - 40.0 * unit) * 0.5
	)
	$BrandLogo.size = Vector2(120.0, 40.0) * unit
	if _storage_notice != null and _storage_notice.visible:
		var note_height := _extra_header_height($Pages.size.x, unit)
		_storage_notice.position = Vector2($Pages.position.x, $Pages.position.y - note_height)
		_storage_notice.size.x = $Pages.size.x
		_storage_notice.set_deferred("size", Vector2($Pages.size.x, note_height - 16.0 * unit))
	if _menu != null and _menu.visible:
		_menu.reposition($MoreButton.get_global_rect())


func set_storage_status(status: Dictionary) -> void:
	match str(status.get("state", "ready")):
		"blocked":
			_storage_key = "storage_unreadable"
		"backup_warning":
			_storage_key = "storage_backup_warning"
		"recovered":
			_storage_key = "storage_recovered"
		_:
			_storage_key = ""
	_layout()


func _extra_header_height(width: float, canvas: float) -> float:
	if _storage_notice == null:
		return 0.0
	_storage_notice.visible = not _storage_key.is_empty()
	if not _storage_notice.visible:
		return 0.0
	_storage_notice.text = GameStrings.ui_text(_storage_key)
	_storage_notice.accessibility_name = _storage_notice.text
	var font_size := roundi(16.0 * canvas)
	Clean.label(_storage_notice, font_size)
	return (
		(
			Clean
			. FONT
			. get_multiline_string_size(
				_storage_notice.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size
			)
			. y
		)
		+ 16.0 * canvas
	)


func _layout_tile(tile: Button, cell: Vector2, u: float, canvas: float) -> void:
	super._layout_tile(tile, cell, u, canvas)
	var cover := tile.get_node("Cover") as TextureRect
	var title := tile.get_node("Title") as Label
	var status := tile.get_node("Status") as Label
	var gap := 32.0 * u
	var title_height := maxf(32.0 * u, 28.0 * canvas)
	var status_height := status.size.y if status.visible else 0.0
	var available := Vector2(
		minf(cell.x, size.x * 0.78), maxf(1.0, cell.y - gap - title_height - status_height)
	)
	var image_size := available
	if cover.texture != null:
		var texture_size := cover.texture.get_size()
		image_size = texture_size * minf(available.x / texture_size.x, available.y / texture_size.y)
	var group_height := image_size.y + gap + title_height + status_height
	var top := maxf(0.0, (cell.y - group_height) * 0.5)
	cover.position = Vector2((cell.x - image_size.x) * 0.5, top)
	cover.size = image_size
	title.position = Vector2(0, top + image_size.y + gap)
	title.size = Vector2(cell.x, title_height)
	Clean.label(title, roundi(maxf(22.0 * u, 18.0 * canvas)))
	TitleLayout.fit(title, title.size, roundi(maxf(22.0 * u, 18.0 * canvas)))
	status.position = Vector2(0, title.position.y + title_height)
	status.size.x = cell.x


func _can_open_menu() -> bool:
	return (
		_enabled and _pointer == -2 and Arena._current(get_viewport().get_instance_id()).is_empty()
	)


func _open_menu() -> void:
	if not _can_open_menu():
		return
	refresh_album_availability()
	_pause_motion()
	_pager.set_interaction_enabled(false)
	_menu.open_menu($MoreButton.get_global_rect())


func refresh_album_availability() -> void:
	if _menu == null:
		return
	_menu.set_album_available(album_available.is_valid() and bool(album_available.call()))
	if _menu.visible:
		_menu.reposition($MoreButton.get_global_rect())


func dismiss_menu() -> bool:
	return _menu != null and _menu.dismiss()


func _resume_after_menu() -> void:
	if _enabled:
		_pager.set_interaction_enabled(true)
		_animate_to_target()


func _on_menu_action(action: StringName) -> void:
	match action:
		&"themes":
			all_themes_requested.emit()
		&"album":
			album_requested.emit()
		&"settings":
			menu_requested.emit()


func _input(event: InputEvent) -> void:
	if _menu != null and (_menu.visible or _menu.is_consuming_pointer()):
		return
	super._input(event)


func navigation_exit(context: Dictionary) -> void:
	if _menu != null:
		_menu.dismiss(false)
	super.navigation_exit(context)


func debug_state_snapshot() -> Dictionary:
	return {
		"selected_index": _selected_index,
		"theme_id": str(_themes[_selected_index].theme_id) if not _themes.is_empty() else "",
		"active_motion_count": active_motion_count(),
		"page": _page,
		"visual_page": _visual_page,
		"menu_open": _menu != null and _menu.visible,
		"playable": not _themes.is_empty() and _themes[_selected_index].playable,
		"reduced_motion": _reduced_motion,
	}


func debug_begin_drag() -> void:
	_begin_drag($Pages.get_global_rect().get_center(), -1)


func debug_drag(delta_x: float, _elapsed := 0.016) -> void:
	_drag_to($Pages.get_global_rect().get_center() + Vector2(delta_x, 0))


func debug_end_drag() -> void:
	_end_drag($Pages.get_global_rect().get_center())
