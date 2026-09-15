extends RefCounted
## Two rows share a single ordered sequence and scroll anchor.

const PuzzleRulesScript := preload("res://scripts/config/PuzzleRules.gd")

var previous_ids: Array[int] = []
var previous_slots: Dictionary = {}
var config: Dictionary = PuzzleRulesScript.tray_layout()


func metrics(area: Rect2) -> Dictionary:
	var unit := area.size.x / float(config["reference_width"])
	var padding := float(config["padding_units"]) * unit
	var row_gap := float(config["row_gap_units"]) * unit
	var row_count := maxi(1, int(config["rows"]))
	var content_height := maxf(1.0, area.size.y - padding * 2.0)
	var row_height := maxf(
		1.0, (content_height - row_gap * float(row_count - 1)) / float(row_count)
	)
	return {
		"unit": unit,
		"padding": padding,
		"row_gap": row_gap,
		"row_count": row_count,
		"row_height": row_height,
		"content_rect":
		Rect2(
			area.position + Vector2.ONE * padding,
			Vector2(maxf(1.0, area.size.x - padding * 2.0), content_height),
		),
	}


func arrange(items: Array, area: Rect2, offset: float, base_scale: float) -> Dictionary:
	var layout := metrics(area)
	var unit: float = layout["unit"]
	var gap: float = layout["row_gap"]
	var padding: float = layout["padding"]
	var row_count: int = layout["row_count"]
	var row_height: float = layout["row_height"]
	var cells: Array[Dictionary] = []
	var ids: Array[int] = []
	var cursor := padding
	for column in range(ceili(items.size() / float(row_count))):
		var pair: Array[Dictionary] = []
		var width := float(config["minimum_cell_width_units"]) * unit
		for row in row_count:
			var index := column * row_count + row
			if index >= items.size():
				break
			var bounds: Rect2 = items[index].bounds
			var size := bounds.size * base_scale
			width = maxf(width, size.x)
			pair.append({"id": items[index].id, "size": size, "row": row})
		for cell in pair:
			cell.slot = Rect2(
				Vector2(cursor, padding + cell.row * (row_height + gap)), Vector2(width, row_height)
			)
			cells.append(cell)
			ids.append(cell.id)
		cursor += width + gap
	var content_width := maxf(0.0, cursor - gap + padding) if not cells.is_empty() else 0.0
	if ids != previous_ids:
		for cell in cells:
			if not previous_slots.has(cell.id):
				continue
			var old: Rect2 = previous_slots[cell.id]
			if old.intersects(area):
				offset = area.position.x + cell.slot.position.x - old.position.x
				break
	offset = clampf(offset, 0.0, maxf(0.0, content_width - area.size.x))
	previous_slots.clear()
	for cell in cells:
		cell.slot.position += area.position - Vector2(offset, 0)
		cell.top_left = cell.slot.get_center() - cell.size * 0.5
		previous_slots[cell.id] = cell.slot
	previous_ids = ids
	return {"cells": cells, "offset": offset, "width": content_width}
