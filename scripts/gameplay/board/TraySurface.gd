extends RefCounted
## Rounded tray and its scroll indicator; piece layout and gestures stay separate.

const Style := preload("res://scripts/screens/gameplay/GameplayStyle.gd")
const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var _panel: Panel
var _track: Panel
var _thumb: Panel
var _clipper: Control
var _content: Node2D


func apply(parent: Node2D, area: Rect2, content_width: float, scroll: float) -> void:
	if not is_instance_valid(parent):
		return
	if not is_instance_valid(_panel) or _panel.is_queued_for_deletion():
		_panel = _make_panel(parent, "tray_background", Style.TRAY_SURFACE)
		_track = _make_panel(parent, "tray_scroll_track", Style.SCROLL_TRACK)
		_thumb = _make_panel(parent, "tray_scroll_thumb", Style.SCROLL_THUMB)
	var config := PuzzleRulesScript.tray_layout()
	var unit := area.size.x / float(config["reference_width"])
	var radius := roundi(float(config["corner_radius_units"]) * unit)
	content_host(parent, area)
	_panel.position = area.position
	_panel.size = area.size
	var surface := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	surface.set_corner_radius_all(radius)
	surface.corner_radius_bottom_left = 0
	surface.corner_radius_bottom_right = 0
	var maximum := maxf(0.0, content_width - area.size.x)
	_track.visible = maximum > 0.5
	_thumb.visible = _track.visible
	var track_width := area.size.x * 0.64
	_track.position = (
		area.position + Vector2((area.size.x - track_width) * 0.5, area.size.y - 9.0 * unit)
	)
	_track.size = Vector2(track_width, maxf(2.0, 2.5 * unit))
	var thumb_width := clampf(
		track_width * area.size.x / maxf(1.0, content_width), 18.0 * unit, track_width
	)
	_thumb.position = (
		_track.position
		+ Vector2((track_width - thumb_width) * clampf(scroll / maxf(1.0, maximum), 0.0, 1.0), 0)
	)
	_thumb.size = Vector2(thumb_width, _track.size.y)


func content_host(parent: Node2D, area: Rect2) -> Node2D:
	if not is_instance_valid(_clipper) or _clipper.is_queued_for_deletion():
		_clipper = Control.new()
		_clipper.name = "tray_clip"
		_clipper.clip_contents = true
		_clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(_clipper)
		_content = Node2D.new()
		_content.name = "Pieces"
		_clipper.add_child(_content)
	_clipper.position = area.position
	_clipper.size = area.size
	# Keep the existing screen-coordinate space for piece movement and input.
	_content.position = -area.position
	return _content


func _make_panel(parent: Node2D, node_name: String, color: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.z_index = -20 if node_name == "tray_background" else -10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(200)
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel
