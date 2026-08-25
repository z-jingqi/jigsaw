class_name CatalogPresenter
extends RefCounted

const ThemeProgressPolicyScript := preload(
	"res://scripts/runtime/presentation/ThemeProgressPolicy.gd"
)
const ViewModelsScript := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var _content: Variant
var _progress: Variant
var _session: Variant
var _strings: Variant
var _revision := 0


func _init(content: Variant, progress: Variant, session: Variant, strings: Variant) -> void:
	_content = content
	_progress = progress
	_session = session
	_strings = strings
	_progress.changed.connect(_on_source_changed)


func home(selected_theme_id: String) -> AppViewModels.HomeViewModel:
	var themes: Array[Dictionary] = _content.topics()
	var resolved_id := _resolve_theme_id(themes, selected_theme_id)
	var models: Array[AppViewModels.HomeThemeViewModel] = []
	var selected_index := 0
	for index in themes.size():
		var topic: Dictionary = themes[index]
		var model := (
			ViewModelsScript
			. HomeThemeViewModel
			. new(
				{
					"theme_id": topic["id"],
					"title": topic["name"],
					"cover_texture": _content.topic_cover(topic),
					"cover_focus": Vector2(0.5, 0.5),
					"home_ui_variant": "on_dark",
					"progress": theme_progress(topic),
				}
			)
		)
		models.append(model)
		if model.theme_id == resolved_id:
			selected_index = index
	return (
		ViewModelsScript
		. HomeViewModel
		. new(
			{
				"revision": _revision,
				"themes": models,
				"selected_theme_id": resolved_id,
				"selected_index": selected_index,
				"show_home_guide": not _progress.tutorial_seen(&"home_swipe"),
			}
		)
	)


func level_list(
	theme_id: String, requested_focus_level_id: String = ""
) -> AppViewModels.LevelListViewModel:
	var topic: Dictionary = _content.topic_by_id(theme_id)
	var cards: Array[AppViewModels.LevelCardViewModel] = []
	var focus_id := ""
	var unlock_budget := 1
	for level in topic.get("levels", []):
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var modes: Array[AppViewModels.ModeStatusViewModel] = _mode_statuses(topic, level)
		var locked := unlock_budget <= 0
		if not locked:
			unlock_budget -= 1
			if _has_completed_mode(modes):
				unlock_budget += maxi(1, int(level.get("unlock_grant", 1)))
		var is_recommended: bool = requested_focus_level_id == str(level["id"])
		if focus_id.is_empty() and not locked and _has_unfinished_mode(modes):
			focus_id = str(level["id"])
		(
			cards
			. append(
				(
					ViewModelsScript
					. LevelCardViewModel
					. new(
						{
							"level_id": level["id"],
							"title": level["title"],
							"thumbnail": _content.level_thumbnail(level),
							"locked": locked,
							"recommended": is_recommended,
							"modes": modes,
						}
					)
				)
			)
		)
	if (
		not requested_focus_level_id.is_empty()
		and _content.level_by_id(theme_id, requested_focus_level_id).is_empty()
	):
		requested_focus_level_id = ""
	return (
		ViewModelsScript
		. LevelListViewModel
		. new(
			{
				"revision": _revision,
				"theme_id": topic.get("id", ""),
				"theme_title": topic.get("name", ""),
				"background_texture": _content.topic_background(topic),
				"theme_progress": theme_progress(topic),
				"focus_level_id":
				requested_focus_level_id if not requested_focus_level_id.is_empty() else focus_id,
				"levels": cards,
			}
		)
	)


func mode_select(theme_id: String, level_id: String) -> AppViewModels.ModeSelectViewModel:
	var topic: Dictionary = _content.topic_by_id(theme_id)
	var level: Dictionary = _content.level_by_id(theme_id, level_id)
	var level_media: Dictionary = _content.level_media(_content.level_config(level))
	return (
		ViewModelsScript
		. ModeSelectViewModel
		. new(
			{
				"revision": _revision,
				"theme_id": theme_id,
				"level_id": level_id,
				"level_title": level.get("title", ""),
				"background_texture": _content.topic_background(topic),
				"preview_texture": level_media.get("texture"),
				"options": _mode_statuses(topic, level),
			}
		)
	)


func gameplay(
	theme_id: String, level_id: String, mode: StringName
) -> AppViewModels.GameplayViewModel:
	var level: Dictionary = _content.level_by_id(theme_id, level_id)
	return (
		ViewModelsScript
		. GameplayViewModel
		. new(
			{
				"revision": _revision,
				"theme_id": theme_id,
				"level_id": level_id,
				"level_title": level.get("title", ""),
				"mode": mode,
				"hint_enabled": true,
			}
		)
	)


func theme_progress(topic: Dictionary) -> AppViewModels.ThemeProgressViewModel:
	var completed := 0
	var total := 0
	for level in topic.get("levels", []):
		if typeof(level) != TYPE_DICTIONARY:
			continue
		for mode in _content.available_modes(level):
			total += 1
			if _progress.is_mode_completed(str(topic["id"]), str(level["id"]), mode):
				completed += 1
	return ViewModelsScript.ThemeProgressViewModel.new(
		ThemeProgressPolicyScript.build(completed, total)
	)


func _mode_statuses(
	topic: Dictionary, level: Dictionary
) -> Array[AppViewModels.ModeStatusViewModel]:
	var result: Array[AppViewModels.ModeStatusViewModel] = []
	for mode in ["polygon", "knob", "swap"]:
		var available: bool = _content.available_modes(level).has(mode)
		var completed: bool = (
			available
			and _progress.is_mode_completed(
				str(topic.get("id", "")), str(level.get("id", "")), mode
			)
		)
		var in_progress: bool = (
			available and not completed and not _session_state(topic, level, mode).is_empty()
		)
		var status: StringName = (
			&"completed"
			if completed
			else (
				&"in_progress" if in_progress else (&"not_started" if available else &"unavailable")
			)
		)
		var action: StringName = (
			&"replay" if completed else (&"resume" if in_progress else &"start")
		)
		result.append(
			ViewModelsScript.ModeStatusViewModel.new(
				StringName(mode),
				_mode_label(mode),
				status,
				action,
				available,
				_mode_short_label(mode),
				_mode_action_label(action)
			)
		)
	return result


func _session_state(topic: Dictionary, level: Dictionary, mode: String) -> Dictionary:
	return _session.play_state(
		str(topic.get("id", "")),
		str(level.get("id", "")),
		mode,
		_content.stable_piece_ids(level, mode)
	)


func _has_unfinished_mode(modes: Array[AppViewModels.ModeStatusViewModel]) -> bool:
	for mode in modes:
		if mode.enabled and mode.status != &"completed":
			return true
	return false


func _has_completed_mode(modes: Array[AppViewModels.ModeStatusViewModel]) -> bool:
	for mode in modes:
		if mode.enabled and mode.status == &"completed":
			return true
	return false


func _mode_label(mode: String) -> String:
	return _strings.text("mode_%s" % mode) if _strings != null else mode.capitalize()


func _mode_short_label(mode: String) -> String:
	return _strings.text("mode_short_%s" % mode) if _strings != null else mode.capitalize()


func _mode_action_label(action: StringName) -> String:
	if _strings == null:
		return String(action).capitalize()
	match action:
		&"resume":
			return _strings.text("continue")
		&"replay":
			return _strings.text("replay")
		_:
			return _strings.text("start_game")


func _resolve_theme_id(themes: Array[Dictionary], requested_id: String) -> String:
	for topic in themes:
		if str(topic.get("id", "")) == requested_id:
			return requested_id
	return str(themes[0].get("id", "")) if not themes.is_empty() else ""


func _on_source_changed(_snapshot: Dictionary, _source_revision: int) -> void:
	_revision += 1
