extends RefCounted
## Read-only preview data from the exact geometry used by the puzzle board.
const KnobGeometry := preload("res://scripts/gameplay/board/KnobSourceGeometry.gd")


static func build(content: ContentRepository, level: Dictionary) -> Dictionary:
	var config := content.level_config(level)
	var media := content.level_media(config)
	var source_size: Vector2 = media.source_size
	var result := {}
	for mode in ["polygon", "knob", "swap"]:
		var settings: Dictionary = config.get("modes", {}).get(mode, {})
		var pieces: Array = settings.get("pieces", [])
		if mode == "knob" and pieces.is_empty():
			pieces = KnobGeometry.generate(settings, source_size)
		var samples: Array = []
		var count := pieces.size()
		if mode == "swap":
			var columns := int(settings.get("cols", 0))
			var rows := int(settings.get("rows", 0))
			if columns <= 0 or rows <= 0:
				columns = 5
				rows = 7
			count = columns * rows
			for column in columns:
				var uv := PackedVector2Array(
					[
						Vector2(float(column) / columns, 0),
						Vector2(float(column + 1) / columns, 0),
						Vector2(float(column + 1) / columns, 1.0 / rows),
						Vector2(float(column) / columns, 1.0 / rows)
					]
				)
				samples.append({"polygon": uv, "uv": uv})
		else:
			var start := mini(pieces.size() - 1, 6) if mode == "knob" else 0
			for index in range(start, mini(start + 3, pieces.size())):
				var polygon := PackedVector2Array()
				var uv := PackedVector2Array()
				for point in pieces[index].get("points", []):
					var vertex := Vector2(float(point[0]), float(point[1]))
					polygon.append(vertex)
					uv.append(vertex / source_size)
				samples.append({"polygon": polygon, "uv": uv})
		result[mode] = {"count": count, "pieces": samples}
	return result
