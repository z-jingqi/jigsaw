extends RefCounted
class_name PuzzleRules

const CONFIG_PATH := "res://config/puzzle_rules.json"

static var _data: Dictionary = {}


static func gameplay_layout() -> Dictionary:
	return _section("gameplay_layout")


static func tray_layout() -> Dictionary:
	var gameplay := gameplay_layout()
	var tray: Variant = gameplay.get("tray", {})
	if tray is Dictionary:
		return tray
	push_error("Invalid tray configuration in %s" % CONFIG_PATH)
	return {}


static func gameplay_scale(viewport_size: Vector2) -> float:
	var layout := gameplay_layout()
	var raw_design_size: Array = layout["design_size"]
	var design_size := Vector2(float(raw_design_size[0]), float(raw_design_size[1]))
	return maxf(
		float(layout["minimum_scale"]),
		minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y),
	)


static func _section(name: String) -> Dictionary:
	var data := _load_data()
	var section: Variant = data.get(name, {})
	if section is Dictionary:
		return section
	push_error("Invalid %s configuration in %s" % [name, CONFIG_PATH])
	return {}


static func _load_data() -> Dictionary:
	if not _data.is_empty():
		return _data
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to read puzzle configuration: %s" % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_error("Invalid puzzle configuration JSON: %s" % CONFIG_PATH)
		return {}
	_data = parsed
	return _data
