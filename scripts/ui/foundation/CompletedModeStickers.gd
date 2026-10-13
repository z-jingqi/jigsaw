class_name CompletedModeStickers
extends Control
## Keeps three completion glyphs in fixed vertical slots, including empty slots.

const TEXTURES := {
	&"polygon": preload("res://assets/ui/levels/mode-icons/polygon-complete.webp"),
	&"knob": preload("res://assets/ui/levels/mode-icons/knob-complete.webp"),
	&"swap": preload("res://assets/ui/levels/mode-icons/swap-complete.webp"),
}
const MODE_ORDER := [&"polygon", &"knob", &"swap"]
const STICKER_ANGLES := [-6.0, 4.0, -4.0]

var _icon_size := 44.0
var _separation := 6.0
var _stickers: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slots()


func configure(icon_size: float, separation: float) -> void:
	_icon_size = icon_size
	_separation = separation
	_ensure_slots()
	for index in _stickers.size():
		var sticker := _stickers[index]
		sticker.position = Vector2(0.0, float(index) * (_icon_size + _separation))
		sticker.size = Vector2.ONE * _icon_size
		sticker.pivot_offset = sticker.size * 0.5
		sticker.rotation_degrees = STICKER_ANGLES[index]


func set_modes(states: Array, enabled := true) -> void:
	_ensure_slots()
	var completed: Dictionary = {}
	for state in states:
		if StringName(_read(state, "status", &"")) == &"completed":
			completed[StringName(_read(state, "mode", &""))] = true
	for index in MODE_ORDER.size():
		_stickers[index].visible = enabled and completed.has(MODE_ORDER[index])
	visible = completed_count() > 0


func completed_count() -> int:
	var count := 0
	for sticker in _stickers:
		if sticker.visible:
			count += 1
	return count


func _ensure_slots() -> void:
	if not _stickers.is_empty():
		return
	for mode in MODE_ORDER:
		var sticker := TextureRect.new()
		sticker.name = "%sSticker" % String(mode).capitalize()
		sticker.texture = TEXTURES[mode]
		sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sticker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sticker.visible = false
		add_child(sticker)
		_stickers.append(sticker)


func _read(source: Variant, field: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(field, fallback)
	return source.get(field) if source != null else fallback
