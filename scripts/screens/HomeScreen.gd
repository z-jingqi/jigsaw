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
	$FixedContent.enter_requested.connect(_enter_selected)
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
	if not is_node_ready() or _pager == null:
		return
	$CloseButton.hide()
	$Title.hide()
	Buttons.place_navigation($MoreButton, self, true)
	var u := Metrics.unit(size)
	var safe := Clean.safe_insets(size)
	$BrandLogo.position = Vector2(safe.x + Metrics.EDGE * u, $MoreButton.position.y)
	$BrandLogo.size = Metrics.LOGO * u
	var header_bottom: float = $MoreButton.position.y + $MoreButton.size.y
	var note_height := _extra_header_height(size.x - 2 * Metrics.EDGE * u, u)
	if _storage_notice != null and _storage_notice.visible:
		_storage_notice.position = Vector2($BrandLogo.position.x, header_bottom)
		_storage_notice.size = Vector2(size.x - 2 * Metrics.EDGE * u, note_height)
	var image_rect: Rect2 = $FixedContent.arrange(size, safe, header_bottom + note_height)
	$Pages.position = image_rect.position
	$Pages.size = image_rect.size
	_pager.position = Vector2(image_rect.position.x, image_rect.end.y + Metrics.SMALL_GAP * u)
	_pager.size = Vector2(image_rect.size.x, Metrics.TOUCH * u)
	for layer in $Pages.get_children():
		layer.size = image_rect.size
		for tile in layer.get_children():
			_layout_tile(tile, image_rect.size, u, u)
	_apply_visual_page(_visual_page)
	if _menu != null and _menu.visible:
		_menu.reposition($MoreButton.get_global_rect())


func _apply_visual_page(value: float) -> void:
	super._apply_visual_page(value)
	if is_node_ready():
		$FixedContent.present(
			_themes, value, _page, _enabled and (_menu == null or not _menu.visible)
		)


func _enter_selected() -> void:
	if not _enabled or _themes.is_empty() or _pointer != -2:
		return
	if not is_equal_approx(_visual_page, float(_page)) or not _themes[_page].playable:
		return
	var cover := $Pages.get_child(_page).get_child(0).get_node("Cover") as TextureRect
	_source_rect = cover.get_global_rect()
	_source_texture = cover.texture
	_freeze()
	_activate_theme(str(_themes[_page].theme_id))


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
	var font_size := roundi(Metrics.CAPTION * canvas)
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


func _layout_tile(tile: Button, cell: Vector2, _u: float, _canvas: float) -> void:
	tile.custom_minimum_size = Vector2.ZERO
	tile.size = cell
	# The image is a paging surface. Only the fixed action enters the theme.
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_NONE
	tile.get_node("Title").hide()
	tile.get_node("Status").hide()
	var cover := tile.get_node("Cover") as TextureRect
	var image_size := cell
	if cover.texture != null:
		var texture_size := cover.texture.get_size()
		image_size = texture_size * minf(cell.x / texture_size.x, cell.y / texture_size.y)
	cover.position = (cell - image_size) * 0.5
	cover.size = image_size


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
	_apply_visual_page(_visual_page)


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
