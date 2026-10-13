extends RefCounted
## Small catalog metadata keeps mode badges independent of full piece geometry.


static func from_config(repository: Variant, config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var has_image := not str(repository.level_image_path(config)).is_empty()
	var polygon: Dictionary = repository.mode_config(config, "polygon")
	var pieces: Variant = polygon.get("pieces", [])
	if typeof(pieces) == TYPE_ARRAY and not pieces.is_empty():
		result.append("polygon")
	if has_image and not repository.mode_config(config, "knob").is_empty():
		result.append("knob")
	if has_image:
		result.append("swap")
	return result
