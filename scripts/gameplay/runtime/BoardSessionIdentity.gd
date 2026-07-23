class_name BoardSessionIdentity
extends RefCounted

static func piece_ids(level_config: Dictionary, mode: String) -> Array[String]:
	var mode_key := "knob" if mode == "classic" else mode
	var modes: Dictionary = level_config.get("modes", {})
	var config: Dictionary = modes.get(mode_key, {}) if typeof(modes) == TYPE_DICTIONARY else {}
	var ids: Array[String] = []
	if mode_key == "swap":
		var count := maxi(1, int(config.get("cols", 5))) * maxi(1, int(config.get("rows", 7)))
		for index in count:
			ids.append("swap_tile_%02d" % index)
	elif mode_key == "knob" and not config.has("pieces"):
		for row in maxi(1, int(config.get("rows", 8))):
			for column in maxi(1, int(config.get("cols", 6))):
				ids.append("knob_%d_%d" % [row, column])
	else:
		for piece in config.get("pieces", []):
			if typeof(piece) == TYPE_DICTIONARY:
				ids.append(str(piece.get("id", "")))
	ids = ids.filter(func(id: String) -> bool: return not id.is_empty())
	ids.sort()
	return ids


static func fingerprint(ids: Array[String]) -> String:
	return "|".join(ids)
