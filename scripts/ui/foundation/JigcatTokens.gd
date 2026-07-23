class_name JigcatTokens
extends Resource

enum TextVariant { ON_LIGHT, ON_DARK }

@export_group("Theme Variants")
@export var on_light_theme: Theme
@export var on_dark_theme: Theme

@export_group("Palette")
@export var ink_dark := Color("10475B")
@export var coral := Color("F28A70")
@export var coral_pressed := Color("E9745E")
@export var mint := Color("A8DCC6")
@export var warm_mist := Color("FFF8ED")
@export var disabled_surface := Color("E8DDCC")
@export var disabled_ink := Color("A6917D")
@export var focus_ring := Color("10475B")

@export_group("Layout")
@export var compact_breakpoint := 600.0
@export var regular_max_width := 704.0
@export var regular_margin := 32.0
@export var minimum_touch_size := 44.0
@export var card_radius := 20.0
@export var modal_radius := 28.0


func theme_for_variant(variant: TextVariant) -> Theme:
	return on_dark_theme if variant == TextVariant.ON_DARK else on_light_theme
