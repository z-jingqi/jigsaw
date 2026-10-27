class_name AlbumCoordinator
extends RefCounted
## Owns unlocked album selection; positions are UI state, never progress writes.

const AlbumScene := preload("res://scenes/screens/album/AlbumScreen.tscn")
const DetailScene := preload("res://scenes/screens/album/AlbumDetailScreen.tscn")
const ImageCache := preload("res://scripts/screens/album/AlbumImageCache.gd")

var _navigator: AppNavigator
var _presenter: AlbumPresenter
var _theme_id := ""
var _positions: Dictionary = {}
var _images: Node
var _play: Callable


func _init(navigator: AppNavigator, presenter: AlbumPresenter, play: Callable) -> void:
	_navigator = navigator
	_presenter = presenter
	_play = play
	_images = ImageCache.new()
	_navigator.add_child(_images)
	_navigator.bind_route_scene(&"album", AlbumScene)
	_navigator.bind_route_scene(&"album_artwork", DetailScene)
	_navigator.route_changed.connect(_route_changed)


func open() -> Dictionary:
	var model := _focus()
	var result := _navigator.push(&"album", {"view_model": model})
	if bool(result.get("ok", false)):
		var screen := _navigator.current_screen_view() as AlbumScreen
		screen.set_image_loader(_images)
		if not screen.has_meta("album_coordinator_bound"):
			screen.set_meta("album_coordinator_bound", true)
			screen.back_requested.connect(_navigator.pop)
			screen.theme_selected.connect(_select_theme)
			screen.index_selected.connect(_select_index)
			screen.artwork_selected.connect(open_artwork)
			screen.play_requested.connect(_play)
	return result


func _focus() -> Dictionary:
	var model := _presenter.focus(_theme_id, int(_positions.get(_theme_id, 0)))
	_theme_id = str(model.get("theme_id", ""))
	_positions[_theme_id] = int(model.get("index", 0))
	return model


func _select_theme(theme_id: String) -> void:
	_theme_id = theme_id
	var screen := _navigator.current_screen_view() as AlbumScreen
	if screen != null:
		screen.render(_focus())


func _select_index(index: int) -> void:
	_positions[_theme_id] = index
	# Screen owns its current visual pose. Do not render/reset its in-flight drag.
	if _navigator.current_route() == &"album_artwork":
		_prepare_album_return()


func open_artwork(theme_id: String, level_id: String) -> Dictionary:
	var entries := _presenter.artworks(theme_id)
	for index in entries.size():
		if str(entries[index].level_id) != level_id:
			continue
		_theme_id = theme_id
		_positions[theme_id] = index
		var model := _focus()
		var detail := _navigator.current_screen_view() as AlbumDetailScreen
		if detail != null:
			detail.render(model, true)
			return {"ok": true}
		var result := (
			_navigator
			. push(
				&"album_artwork",
				{
					"theme_id": theme_id,
					"level_id": level_id,
					"view_model": model,
				}
			)
		)
		if bool(result.get("ok", false)):
			detail = _navigator.current_screen_view() as AlbumDetailScreen
			detail.set_image_loader(_images)
			if not detail.has_meta("album_coordinator_bound"):
				detail.set_meta("album_coordinator_bound", true)
				detail.back_requested.connect(_close_artwork)
				detail.back_preview_requested.connect(_prepare_album_return)
				detail.index_selected.connect(_select_index)
		return result
	return {"ok": false, "error": "not_unlocked"}


func _route_changed(route: StringName, _payload: Dictionary) -> void:
	if route == &"album":
		var screen := _navigator.current_screen_view() as AlbumScreen
		if screen != null and screen.has_meta("album_coordinator_bound"):
			screen.render(_focus())


func _prepare_album_return() -> void:
	var previous := _navigator.previous_screen_view() as AlbumScreen
	if previous != null:
		previous.prepare_return(int(_positions.get(_theme_id, 0)))


func _close_artwork() -> void:
	_prepare_album_return()
	_navigator.pop()
