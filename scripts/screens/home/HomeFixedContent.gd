extends Control
## Stationary title and action; opacity is a pure function of image-page progress.
signal enter_requested

const Clean := preload("res://scripts/ui/foundation/CleanTheme.gd")
const Metrics := preload("res://scripts/ui/foundation/UiMetrics.gd")
const TitleLayout := preload("res://scripts/screens/home/ThemeTitleLayout.gd")
var _font_size := 26


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Clean.button($EnterButton, true)
	$EnterButton.pressed.connect(enter_requested.emit)


func arrange(surface: Vector2, safe: Vector4, header_bottom: float) -> Rect2:
	var u := Metrics.unit(surface)
	var left := safe.x + Metrics.EDGE * u
	var width := surface.x - left - safe.z - Metrics.EDGE * u
	$ThemeName.position = Vector2(left, header_bottom + Metrics.GAP * u)
	$ThemeName.size = Vector2(width, Metrics.TITLE * 2.6 * u)
	_font_size = roundi(Metrics.TITLE * u)
	Clean.label($ThemeName, _font_size)
	var bottom := surface.y - safe.w - Metrics.EDGE * u
	$EnterButton.position = Vector2(left, bottom - Metrics.PRIMARY_HEIGHT * u)
	$EnterButton.size = Vector2(width, Metrics.PRIMARY_HEIGHT * u)
	$EnterButton.add_theme_font_size_override("font_size", roundi(Metrics.BODY * u))
	$PageCount.size = Vector2(width, 24 * u)
	$PageCount.position = Vector2(left, $EnterButton.position.y - 32 * u)
	Clean.label($PageCount, roundi(Metrics.CAPTION * u), true)
	var top: float = $ThemeName.position.y + $ThemeName.size.y + Metrics.GAP * u
	return Rect2(
		left, top, width, maxf(1, $PageCount.position.y - (Metrics.TOUCH + Metrics.GAP) * u - top)
	)


func present(themes: Array, visual_page: float, selected: int, enabled: bool) -> void:
	var count := themes.size()
	visible = count > 0
	if count == 0:
		$EnterButton.disabled = true
		return
	var progress := clampf(visual_page, 0, count - 1)
	var index := clampi(roundi(progress), 0, count - 1)
	$ThemeName.text = str(themes[index].title)
	TitleLayout.fit($ThemeName, $ThemeName.size, _font_size, 2)
	# Fade to zero at the midpoint, then reveal the next title in the same slot.
	$ThemeName.modulate.a = smoothstep(0.0, 1.0, absf(1.0 - 2.0 * (progress - floorf(progress))))
	$PageCount.text = "%d / %d" % [selected + 1, count]
	$PageCount.accessibility_name = GameStrings.ui_text("pager_page") % [selected + 1, count]
	var playable: bool = themes[selected].playable
	$EnterButton.text = GameStrings.ui_text("enter_short" if playable else "coming_soon")
	$EnterButton.accessibility_name = "%s · %s" % [$EnterButton.text, themes[selected].title]
	$EnterButton.disabled = (
		not enabled or not playable or not is_equal_approx(progress, float(selected))
	)
