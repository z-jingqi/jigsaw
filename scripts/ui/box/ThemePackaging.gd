extends RefCounted
## Theme identity only: never derives symbols or colors from an individual level.

const TITLE_STYLE_VERSION := 2
const TITLE_DEFAULT_SIZE := 80
const TITLE_MIN_SIZE := 72
const TITLE_PIXEL_SIZE := 0.003
const TITLE_MAX_WIDTH := 1.80

const ICONS := {
	&"polygon":
	[
		preload("res://assets/ui/mode-status/polygon-incomplete.svg"),
		preload("res://assets/ui/mode-status/polygon-complete.svg")
	],
	&"knob":
	[
		preload("res://assets/ui/mode-status/knob-incomplete.svg"),
		preload("res://assets/ui/mode-status/knob-complete.svg")
	],
	&"swap":
	[
		preload("res://assets/ui/mode-status/swap-incomplete.svg"),
		preload("res://assets/ui/mode-status/swap-complete.svg")
	],
}


static func palette(theme_id: String) -> Dictionary:
	var profiles := {
		"topic_01": [Color("526f59"), Color("b29a5e"), &"mural"],
		"topic_02": [Color("304865"), Color("bda16b"), &"meander"],
		"topic_03": [Color("e5bd93"), Color("637b64"), &"paw"],
		"topic_04": [Color("b89977"), Color("f0ddba"), &"paw"],
		"theme_flowers": [Color("a58b9f"), Color("e8d3b0"), &"leaf"],
		"theme_ocean": [Color("5c8a99"), Color("d6caa5"), &"wave"],
		"theme_birds": [Color("8a9a7b"), Color("ecddbd"), &"leaf"],
		"theme_forest": [Color("5d7664"), Color("c5b78e"), &"leaf"],
	}
	var values: Array = profiles.get(theme_id, [Color("787d74"), Color("d4c5a7"), &"wave"])
	return {"ink": values[0], "accent": values[1], "motif": values[2]}


static func status_texture(mode: StringName, modes: Array) -> Texture2D:
	var complete := false
	for entry in modes:
		if entry == null:
			continue
		if StringName(entry.get("mode")) == mode:
			complete = StringName(entry.get("status")) == &"completed"
			break
	return ICONS[mode][int(complete)]


static func title_width(packaging: Dictionary) -> float:
	return clampf(float(packaging.get("title_width", TITLE_MAX_WIDTH)), 0.60, TITLE_MAX_WIDTH)


static func title_signature(packaging: Dictionary) -> Array:
	return [
		TITLE_STYLE_VERSION,
		packaging.get("theme_id", ""),
		packaging.get("title", ""),
		title_width(packaging),
		TITLE_DEFAULT_SIZE,
		TITLE_MIN_SIZE
	]
