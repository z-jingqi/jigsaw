class_name AppServices
extends RefCounted

var content: ContentRepository
var progress: ProgressRepository
var session: SessionRepository
var settings: SettingsRepository
var motion_preferences: MotionPreferences
var localization: Variant
var audio: Variant
var haptics: Variant
var textures: Variant


func _init(
	p_content: ContentRepository,
	p_progress: ProgressRepository,
	p_session: SessionRepository,
	p_settings: SettingsRepository,
	p_motion_preferences: MotionPreferences,
	p_localization: Variant = null,
	p_audio: Variant = null,
	p_haptics: Variant = null,
	p_textures: Variant = null
) -> void:
	content = p_content
	progress = p_progress
	session = p_session
	settings = p_settings
	motion_preferences = p_motion_preferences
	localization = p_localization
	audio = p_audio
	haptics = p_haptics
	textures = p_textures


func load() -> void:
	progress.load()
	session.load()
	settings.load()


func complete_mode(theme_id: String, level_id: String, mode: String) -> Dictionary:
	var progress_result := progress.mark_mode_completed(theme_id, level_id, mode)
	if not bool(progress_result.get("ok", false)):
		return progress_result
	var clear_result := session.clear_play_state(theme_id, level_id, mode)
	if not bool(clear_result.get("ok", false)):
		return clear_result
	return {"ok": true, "changed": bool(progress_result.get("changed", false))}


func initial_home_theme_id() -> String:
	var topics: Array[Dictionary] = content.topics()
	if topics.is_empty():
		return ""
	var requested := str(session.current().get("theme_id", ""))
	return requested if not content.topic_by_id(requested).is_empty() else str(topics[0].get("id", ""))


func initial_level_focus_id(theme_id: String) -> String:
	var current: Dictionary = session.current()
	if str(current.get("theme_id", "")) != theme_id:
		return ""
	var level_id := str(current.get("level_id", ""))
	return level_id if not content.level_by_id(theme_id, level_id).is_empty() else ""
