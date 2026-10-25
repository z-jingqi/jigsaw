class_name AlbumDetailScreen
extends Control

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Buttons := preload("res://scripts/ui/foundation/ButtonMetrics.gd")

signal back_requested
signal browse_requested(direction: int)

var _model: Dictionary = {}
var _reduced_motion := false


func _ready() -> void:
	$BackButton.pressed.connect(back_requested.emit)
	$Previous.pressed.connect(browse_requested.emit.bind(-1))
	$Next.pressed.connect(browse_requested.emit.bind(1))
	resized.connect(_layout)
	$Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$ThemeName.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	_reduced_motion = bool(context.get("reduced_motion", false))
	render(payload.get("view_model", {}))


func render(model: Dictionary, animate := false) -> void:
	_model = model
	$Title.text = str(model.title)
	$ThemeName.text = str(model.theme_title)
	$BackButton.accessibility_name = str(model.back_label)
	$Previous.accessibility_name = str(model.previous_label)
	$Next.accessibility_name = str(model.next_label)
	$Previous.disabled = int(model.index) == 0
	$Next.disabled = int(model.index) + 1 >= int(model.total)
	$Position.text = "%02d / %02d" % [int(model.index) + 1, int(model.total)]
	$ImageMotion.show_image($Artwork, model.texture, animate and not _reduced_motion)
	_layout()


func navigation_set_active(enabled: bool) -> void:
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled:
		$ImageMotion.finish()


func navigation_prepare_transition() -> void:
	$ImageMotion.finish()


func navigation_exit(_context: Dictionary) -> void:
	$ImageMotion.finish()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		$ImageMotion.finish()


func active_motion_count() -> int:
	return $ImageMotion.active_motion_count()


func debug_state_snapshot() -> Dictionary:
	return {
		"theme_id": _model.get("theme_id", ""),
		"level_id": _model.get("level_id", ""),
		"index": _model.get("index", 0),
		"total": _model.get("total", 0),
		"image_ready": $Artwork.texture != null,
		"active_motion_count": active_motion_count(),
	}


func _layout() -> void:
	if not is_node_ready() or _model.is_empty():
		return
	var u := minf(size.x / 390.0, size.y / 700.0) if size.x < size.y else size.y / 390.0
	var safe := Clean.safe_insets(size)
	Buttons.place_navigation($BackButton, self)
	$Title.position = Vector2(24 * u, 78 * u + safe.y)
	$Title.size = Vector2(size.x - 48 * u, 46 * u)
	Clean.label($Title, roundi(25 * u), false)
	$ThemeName.position = Vector2(24 * u, 127 * u + safe.y)
	$ThemeName.size = Vector2(size.x - 48 * u, 26 * u)
	Clean.label($ThemeName, roundi(15 * u), true)
	var area := Rect2(Vector2(24 * u, 173 * u + safe.y), size - Vector2(48 * u, 280 * u + safe.y + safe.w))
	var texture := _model.get("texture") as Texture2D
	if texture != null and area.size.x > 0 and area.size.y > 0:
		var dimensions := texture.get_size()
		var fit := minf(area.size.x / dimensions.x, area.size.y / dimensions.y)
		$Artwork.size = dimensions * fit
		$Artwork.position = area.get_center() - $Artwork.size * 0.5
	var bottom := size.y - 74 * u - safe.w
	$Previous.position = Vector2(size.x * 0.5 - 107 * u, bottom)
	$Next.position = Vector2(size.x * 0.5 + 61 * u, bottom)
	$Previous.size = Vector2.ONE * 46 * u
	$Next.size = Vector2.ONE * 46 * u
	$Position.position = Vector2(size.x * 0.5 - 55 * u, bottom)
	$Position.size = Vector2(110, 46) * u
	Clean.label($Position, roundi(16 * u), true)
