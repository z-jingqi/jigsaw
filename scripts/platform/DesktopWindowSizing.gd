extends Node

## Keeps the portrait game inside the usable Windows desktop while preserving
## the project's design aspect ratio. Mobile platforms keep their native window.
const MAX_USABLE_AREA_RATIO := 0.80


func _ready() -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null or window.mode != Window.MODE_WINDOWED:
		return
	var usable_rect := DisplayServer.screen_get_usable_rect(window.current_screen)
	var design_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1206)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 2622))
	)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0 or design_size.y <= 0.0:
		return
	var available_size := Vector2(
		maxf(1.0, float(usable_rect.size.x) * MAX_USABLE_AREA_RATIO),
		maxf(1.0, float(usable_rect.size.y) * MAX_USABLE_AREA_RATIO)
	)
	var scale_factor := minf(
		1.0, minf(available_size.x / design_size.x, available_size.y / design_size.y)
	)
	var target_size := Vector2i(
		maxi(1, roundi(design_size.x * scale_factor)),
		maxi(1, roundi(design_size.y * scale_factor))
	)
	window.size = target_size
	window.position = usable_rect.position + Vector2i(
		(usable_rect.size.x - target_size.x) / 2,
		(usable_rect.size.y - target_size.y) / 2
	)
