class_name AlbumPresenter
extends RefCounted
## Metadata-only album models. Discovered pictures are available independently of completion.

var _content: ContentRepository
var _strings: GameStrings
var _progress: ProgressRepository


func _init(
	content: ContentRepository, strings: GameStrings, progress: ProgressRepository = null
) -> void:
	_content = content
	_strings = strings
	_progress = progress


func has_unlocked_artwork() -> bool:
	for topic in _content.topics():
		for level in topic.get("levels", []):
			if _unlocked(str(topic.id), str(level.id)):
				return true
	return false


func focus(theme_id := "", index := 0) -> Dictionary:
	var themes := overview().cards as Array[Dictionary]
	var resolved := theme_id
	if not themes.any(func(entry: Dictionary) -> bool: return entry.theme_id == resolved):
		resolved = str(themes[0].theme_id) if not themes.is_empty() else ""
	var entries: Array[Dictionary] = []
	if not resolved.is_empty():
		entries = artworks(resolved)
	var selected := clampi(index, 0, maxi(0, entries.size() - 1))
	var current: Dictionary = entries[selected] if not entries.is_empty() else {}
	var model := _model("focus", resolved, entries, str(current.get("theme_title", "")))
	(
		model
		. merge(
			{
				"themes": themes,
				"artworks": entries,
				"index": selected,
				"current": current,
				"level_id": str(current.get("level_id", "")),
				"theme_title": str(current.get("theme_title", "")),
				"title": str(current.get("title", "")),
				"previous_label": _strings.text("album_previous"),
				"next_label": _strings.text("album_next"),
			},
			true
		)
	)
	return model


func overview() -> Dictionary:
	var cards: Array[Dictionary] = []
	var total := 0
	for topic in _content.topics():
		var count := 0
		for level in topic.get("levels", []):
			if _unlocked(str(topic.id), str(level.id)):
				count += 1
		if count == 0:
			continue
		total += count
		(
			cards
			. append(
				{
					"level_id": JSON.stringify([str(topic.id)]),
					"theme_id": str(topic.id),
					"id": str(topic.id),
					"title": str(topic.name),
					"subtitle": _strings.text("album_count") % count,
					"thumbnail_path":
					str(
						topic.get(
							"theme_subject", topic.get("cover_thumbnail", topic.get("cover", ""))
						)
					),
					"total": count,
				}
			)
		)
	var model := _model("themes", "", cards, _strings.text("album_title"))
	model.total = total
	model.theme_count = cards.size()
	return model


func gallery(theme_id := "") -> Dictionary:
	return focus(theme_id)


func artworks(theme_id := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# There is intentionally no aggregate "all artworks" collection.
	if theme_id.is_empty():
		return result
	var topic := _content.topic_by_id(theme_id)
	for level in topic.get("levels", []):
		if not _unlocked(theme_id, str(level.id)):
			continue
		var config := _content.level_config(level)
		(
			result
			. append(
				{
					"theme_id": theme_id,
					"level_id": str(level.id),
					"artwork_id": str(level.id),
					"title": str(level.title),
					"theme_title": str(topic.name),
					"path": _content.level_image_path(config),
					"image_path": _content.level_image_path(config),
					"thumbnail_path": _content.level_thumbnail_path(level),
				}
			)
		)
	return result


func artwork(theme_id: String, level_id: String, index: int, total: int) -> Dictionary:
	for entry in artworks(theme_id):
		if str(entry.level_id) == level_id:
			var model := entry.duplicate()
			(
				model
				. merge(
					{
						"index": index,
						"total": total,
						"back_label": _strings.text("album_back"),
						"previous_label": _strings.text("album_previous"),
						"next_label": _strings.text("album_next"),
					}
				)
			)
			return model
	return {}


func _unlocked(theme_id: String, level_id: String) -> bool:
	return (
		_progress != null
		and (
			_progress.is_level_visited(theme_id, level_id)
			or not _progress.completed_modes_for_level(theme_id, level_id).is_empty()
		)
	)


func _model(kind: String, theme_id: String, cards: Array, title: String) -> Dictionary:
	return {
		"kind": kind,
		"theme_id": theme_id,
		"cards": cards,
		"title": title,
		"summary": _strings.text("album_count") % cards.size(),
		"back_label": _strings.text("back"),
		"choose_theme_label": _strings.text("album_choose_theme"),
		"close_label": _strings.text("close"),
		"total": cards.size(),
	}
