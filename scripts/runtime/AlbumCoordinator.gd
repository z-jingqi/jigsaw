class_name AlbumCoordinator
extends RefCounted
## Owns album routes and preserves the grid state while browsing full artworks.

const AlbumScene := preload("res://scenes/screens/album/AlbumScreen.tscn")
const DetailScene := preload("res://scenes/screens/album/AlbumDetailScreen.tscn")
const ThumbnailLoader := preload("res://scripts/screens/album/AlbumThumbnailLoader.gd")

var _navigator: AppNavigator
var _presenter: AlbumPresenter
var _theme_id := ""
var _show_themes := true
var _thumbnails: AlbumThumbnailLoader
var _scroll_positions: Dictionary = {}
var _artworks: Array[Dictionary] = []
var _artwork_index := 0


func _init(navigator: AppNavigator, presenter: AlbumPresenter) -> void:
	_navigator = navigator
	_presenter = presenter
	_thumbnails = ThumbnailLoader.new()
	_navigator.add_child(_thumbnails)
	_navigator.bind_route_scene(&"album", AlbumScene)
	_navigator.bind_route_scene(&"album_artwork", DetailScene)


func open() -> Dictionary:
	var payload := {
		"view_model": _presenter.overview() if _show_themes else _presenter.gallery(_theme_id),
		"scroll_position": int(_scroll_positions.get(_view_key(), 0)),
	}
	var result := (
		_navigator.push_from_modal(&"album", payload)
		if _navigator.current_route() == &"home_guide"
		else _navigator.push(&"album", payload)
	)
	if bool(result.get("ok", false)):
		var screen := _navigator.current_screen_view() as AlbumScreen
		if screen.has_meta("album_coordinator_bound"):
			return result
		screen.set_meta("album_coordinator_bound", true)
		screen.set_thumbnail_loader(_thumbnails)
		screen.back_requested.connect(_back.bind(screen))
		screen.theme_selected.connect(_select_theme.bind(screen))
		screen.all_requested.connect(_select_theme.bind("", screen))
		screen.artwork_selected.connect(open_artwork)
	return result


func open_artwork(theme_id: String, level_id: String) -> Dictionary:
	_artworks = _presenter.artworks(theme_id if _show_themes else _theme_id)
	for index in _artworks.size():
		if _artworks[index].theme_id == theme_id and _artworks[index].level_id == level_id:
			_artwork_index = index
			return _enter_artwork()
	return {"ok": false, "error": "not_found"}


func _enter_artwork() -> Dictionary:
	var entry := _artworks[_artwork_index]
	var model := _presenter.artwork(
		str(entry.theme_id), str(entry.level_id), _artwork_index, _artworks.size()
	)
	if model.is_empty():
		return {"ok": false, "error": "not_found"}
	var detail := _navigator.current_screen_view() as AlbumDetailScreen
	if detail != null:
		detail.render(model, true)
		return {"ok": true}
	var result := (
		_navigator
		. push(
			&"album_artwork",
			{
				"theme_id": str(entry.theme_id),
				"level_id": str(entry.level_id),
				"view_model": model,
			}
		)
	)
	if bool(result.get("ok", false)):
		detail = _navigator.current_screen_view() as AlbumDetailScreen
		detail.back_requested.connect(_navigator.pop)
		detail.browse_requested.connect(_browse)
	return result


func _browse(direction: int) -> void:
	var next_index := clampi(_artwork_index + direction, 0, _artworks.size() - 1)
	if next_index == _artwork_index:
		return
	_artwork_index = next_index
	_enter_artwork()


func _select_theme(theme_id: String, screen: AlbumScreen) -> void:
	_scroll_positions[_view_key()] = screen.scroll_position()
	_show_themes = false
	_theme_id = theme_id
	screen.render(_presenter.gallery(theme_id), int(_scroll_positions.get(_view_key(), 0)))


func _back(screen: AlbumScreen) -> void:
	_scroll_positions[_view_key()] = screen.scroll_position()
	if _show_themes:
		_navigator.pop()
	else:
		_show_themes = true
		_theme_id = ""
		screen.render(_presenter.overview(), int(_scroll_positions.get(_view_key(), 0)))


func _view_key() -> String:
	return "themes" if _show_themes else "artworks:" + _theme_id
