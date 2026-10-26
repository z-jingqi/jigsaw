class_name AlbumPresenter
extends RefCounted
## Album browsing uses catalog metadata and never depends on play progress.

var _content: ContentRepository
var _strings: GameStrings


func _init(content: ContentRepository, strings: GameStrings) -> void:
	_content = content
	_strings = strings


func overview() -> Dictionary:
	var cards: Array[Dictionary] = []
	var total := 0
	for topic in _content.topics():
		var count: int = topic.get("levels", []).size()
		total += count
		(
			cards
			. append(
				{
					"level_id": JSON.stringify([str(topic.id)]),
					"theme_id": str(topic.id),
					"title": str(topic.name),
					"subtitle": _strings.text("album_count") % count,
					"thumbnail_path": str(topic.get("cover_thumbnail", topic.get("cover", ""))),
				}
			)
		)
	var model := _model("themes", "", cards, _strings.text("album_title"))
	model.summary = _strings.text("album_overview_count") % [cards.size(), total]
	model.total = total
	model.theme_count = cards.size()
	return model


func gallery(theme_id := "") -> Dictionary:
	var cards: Array[Dictionary] = []
	var title := _strings.text("album_all")
	for topic in _content.topics():
		if not theme_id.is_empty() and theme_id != str(topic.id):
			continue
		if not theme_id.is_empty():
			title = str(topic.name)
		for level in topic.get("levels", []):
			(
				cards
				. append(
					{
						"level_id": JSON.stringify([str(topic.id), str(level.id)]),
						"artwork_id": str(level.id),
						"theme_id": str(topic.id),
						"title": str(level.title),
						"subtitle": str(topic.name) if theme_id.is_empty() else "",
						"thumbnail_path": _content.level_thumbnail_path(level),
					}
				)
			)
	return _model("artworks", theme_id, cards, title)


func artworks(theme_id := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for topic in _content.topics():
		if not theme_id.is_empty() and theme_id != str(topic.id):
			continue
		for level in topic.get("levels", []):
			result.append({"theme_id": str(topic.id), "level_id": str(level.id)})
	return result


func artwork(theme_id: String, level_id: String, index: int, total: int) -> Dictionary:
	var topic := _content.topic_by_id(theme_id)
	var level := _content.level_by_id(theme_id, level_id)
	if topic.is_empty() or level.is_empty():
		return {}
	return {
		"theme_id": theme_id,
		"level_id": level_id,
		"title": str(level.title),
		"theme_title": str(topic.name),
		"texture": _content.level_preview_texture(_content.level_config(level)),
		"index": index,
		"total": total,
		"back_label": _strings.text("album_back"),
		"previous_label": _strings.text("album_previous"),
		"next_label": _strings.text("album_next"),
	}


func _model(kind: String, theme_id: String, cards: Array[Dictionary], title: String) -> Dictionary:
	return {
		"kind": kind,
		"theme_id": theme_id,
		"cards": cards,
		"title": title,
		"summary": _strings.text("album_count") % cards.size(),
		"back_label": _strings.text("back"),
		"all_label": _strings.text("album_all"),
		"empty_label": _strings.text("album_empty"),
		"total": cards.size(),
	}
