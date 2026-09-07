extends RefCounted
## Two rows share a single ordered sequence and scroll anchor.

var previous_ids: Array[int] = []
var previous_slots: Dictionary = {}


func arrange(items: Array, area: Rect2, offset: float, base_scale: float) -> Dictionary:
	var unit := area.size.x / 402.0
	var gap := 6.0 * unit
	var padding := 5.0 * unit
	var row_height := (area.size.y - padding * 2.0 - gap) * 0.5
	var cells: Array[Dictionary] = []
	var ids: Array[int] = []
	var cursor := padding
	for column in range(ceili(items.size() / 2.0)):
		var pair: Array[Dictionary] = []
		var width := 44.0 * unit
		for row in 2:
			var index := column * 2 + row
			if index >= items.size():
				break
			var bounds: Rect2 = items[index].bounds
			var scale := minf(
				base_scale,
				minf(
					(row_height - gap) / maxf(1.0, bounds.size.y),
					row_height * 1.3 / maxf(1.0, bounds.size.x)
				)
			)
			var size := bounds.size * scale
			width = maxf(width, size.x)
			pair.append({"id": items[index].id, "scale": scale, "size": size, "row": row})
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
