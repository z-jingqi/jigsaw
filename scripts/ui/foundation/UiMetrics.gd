extends RefCounted
## Shared logical units. Never size UI text or controls in raw device pixels.

const REFERENCE := Vector2(390, 844)
const EDGE := 24.0
const BACK_EDGE := 24.0
const GAP := 16.0
const SMALL_GAP := 8.0
const TOP := 12.0
const TOUCH := 48.0
const PRIMARY_HEIGHT := 52.0
const TITLE := 26.0
const BODY := 18.0
const CAPTION := 14.0
const LOGO := Vector2(144, 48)
const MENU_WIDTH := 224.0


static func unit(viewport: Vector2) -> float:
	return minf(viewport.x / REFERENCE.x, viewport.y / REFERENCE.y)
