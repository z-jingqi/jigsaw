class_name ReferenceImageModal
extends Control
## An on-demand, uncropped reference; the navigator owns modal transitions/input.

signal close_requested

@onready var artwork: TextureRect = $Artwork
@onready var title: Label = $Title
@onready var close_button: ActionButton = $Close


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	resized.connect(_apply_layout)
	_apply_layout()


func navigation_enter(payload: Dictionary, context: Dictionary) -> void:
	artwork.texture = payload.get("texture") as Texture2D
	title.text = str(payload.get("title", ""))
	close_button.set_reduced_motion(bool(context.get("reduced_motion", false)))
	_apply_layout()


func navigation_exit(_context: Dictionary) -> void:
	close_button.cancel_motion()


func request_dismiss() -> void:
	close_requested.emit()


func _apply_layout() -> void:
	if not is_node_ready():
		return
	var unit := minf(size.x / 1206.0, size.y / 2622.0)
	var margin := 64.0 * unit
	var header_height := 170.0 * unit
	var button_size := Vector2(480.0, 140.0) * unit
	title.position = Vector2(margin, margin)
	title.size = Vector2(size.x - margin * 2.0, header_height)
	title.add_theme_font_size_override("font_size", roundi(64.0 * unit))
	close_button.custom_minimum_size = button_size
	close_button.size = button_size
	close_button.position = Vector2((size.x - button_size.x) * 0.5, size.y - margin - button_size.y)
	close_button.add_theme_font_size_override("font_size", roundi(46.0 * unit))
	artwork.position = Vector2(margin, margin + header_height)
	artwork.size = Vector2(
		size.x - margin * 2.0, close_button.position.y - margin - artwork.position.y
	)
