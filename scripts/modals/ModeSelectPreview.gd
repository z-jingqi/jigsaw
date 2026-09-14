extends RefCounted
## Explicit debug-only, one-use presentation override. Never writes game data.

const TRIGGER := "user://mode_state_preview.once"


static func consume(model: Variant) -> Variant:
	if not OS.is_debug_build() or not FileAccess.file_exists(TRIGGER):
		return null
	if str(model.get("level_id")) != "greek_01":
		return null
	DirAccess.remove_absolute(TRIGGER)
	var options: Array = []
	for i in model.options.size():
		var original: Variant = model.options[i]
		(
			options
			. append(
				{
					"mode": original.mode,
					"short_label": original.short_label,
					"enabled": true,
					"status": [&"not_started", &"in_progress", &"completed"][i],
					"action": &"start",
					"action_label": "临时预览",
				}
			)
		)
	return {
		"preview_texture": model.preview_texture,
		"level_title": model.level_title,
		"options": options
	}
