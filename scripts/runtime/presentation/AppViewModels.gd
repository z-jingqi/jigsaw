class_name AppViewModels
extends RefCounted

class ThemeProgressViewModel:
	extends RefCounted
	var completed_modes: int
	var total_modes: int
	var ratio: float
	var paw_count: int
	var is_complete: bool
	var accessibility_text: String

	func _init(value: Dictionary) -> void:
		completed_modes = int(value["completed_modes"])
		total_modes = int(value["total_modes"])
		ratio = float(value["ratio"])
		paw_count = int(value["paw_count"])
		is_complete = bool(value["is_complete"])
		accessibility_text = "%d / %d" % [completed_modes, total_modes]


class ModeStatusViewModel:
	extends RefCounted
	var mode: StringName
	var label: String
	var status: StringName
	var action: StringName
	var enabled: bool

	func _init(p_mode: StringName, p_label: String, p_status: StringName, p_action: StringName, p_enabled: bool) -> void:
		mode = p_mode
		label = p_label
		status = p_status
		action = p_action
		enabled = p_enabled


class HomeThemeViewModel:
	extends RefCounted
	var theme_id: String
	var title: String
	var cover_texture: Texture2D
	var cover_focus: Vector2
	var home_ui_variant: StringName
	var progress: ThemeProgressViewModel

	func _init(data: Dictionary) -> void:
		theme_id = str(data["theme_id"])
		title = str(data["title"])
		cover_texture = data["cover_texture"]
		cover_focus = data.get("cover_focus", Vector2(0.5, 0.5))
		home_ui_variant = StringName(data.get("home_ui_variant", "default"))
		progress = data["progress"]


class HomeViewModel:
	extends RefCounted
	var revision: int
	var themes: Array[HomeThemeViewModel]
	var selected_theme_id: String
	var selected_index: int
	var page_number: int
	var total_themes: int
	var can_go_previous: bool
	var can_go_next: bool
	var show_home_guide: bool

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		themes.assign(data["themes"])
		selected_theme_id = str(data["selected_theme_id"])
		selected_index = int(data["selected_index"])
		page_number = selected_index + 1
		total_themes = themes.size()
		can_go_previous = selected_index > 0
		can_go_next = selected_index + 1 < total_themes
		show_home_guide = bool(data["show_home_guide"])


class ThemeCardViewModel:
	extends RefCounted
	var theme_id: String
	var title: String
	var cover_texture: Texture2D
	var cover_focus: Vector2
	var progress: ThemeProgressViewModel
	var is_current: bool
	var is_new: bool
	var is_complete: bool

	func _init(data: Dictionary) -> void:
		theme_id = str(data["theme_id"])
		title = str(data["title"])
		cover_texture = data["cover_texture"]
		cover_focus = data.get("cover_focus", Vector2(0.5, 0.5))
		progress = data["progress"]
		is_current = bool(data["is_current"])
		is_new = bool(data["is_new"])
		is_complete = progress.is_complete


class AllThemesViewModel:
	extends RefCounted
	var revision: int
	var cards: Array[ThemeCardViewModel]
	var current_theme_id: String
	var theme_count_text: String

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		cards.assign(data["cards"])
		current_theme_id = str(data["current_theme_id"])
		theme_count_text = "%d" % cards.size()


class LevelCardViewModel:
	extends RefCounted
	var level_id: String
	var title: String
	var thumbnail: Texture2D
	var locked: bool
	var recommended: bool
	var newly_unlocked: bool
	var modes: Array[ModeStatusViewModel]

	func _init(data: Dictionary) -> void:
		level_id = str(data["level_id"])
		title = str(data["title"])
		thumbnail = data["thumbnail"]
		locked = bool(data["locked"])
		recommended = bool(data["recommended"])
		newly_unlocked = bool(data.get("newly_unlocked", false))
		modes.assign(data["modes"])


class LevelListViewModel:
	extends RefCounted
	var revision: int
	var theme_id: String
	var theme_title: String
	var theme_progress: ThemeProgressViewModel
	var focus_level_id: String
	var levels: Array[LevelCardViewModel]

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		theme_id = str(data["theme_id"])
		theme_title = str(data["theme_title"])
		theme_progress = data["theme_progress"]
		focus_level_id = str(data["focus_level_id"])
		levels.assign(data["levels"])


class ModeSelectViewModel:
	extends RefCounted
	var revision: int
	var theme_id: String
	var level_id: String
	var level_title: String
	var options: Array[ModeStatusViewModel]

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		theme_id = str(data["theme_id"])
		level_id = str(data["level_id"])
		level_title = str(data["level_title"])
		options.assign(data["options"])


class GameplayViewModel:
	extends RefCounted
	var revision: int
	var theme_id: String
	var level_id: String
	var level_title: String
	var mode: StringName
	var bottom_variant: StringName
	var hint_enabled: bool

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		theme_id = str(data["theme_id"])
		level_id = str(data["level_id"])
		level_title = str(data["level_title"])
		mode = StringName(data["mode"])
		bottom_variant = &"swap" if mode == &"swap" else &"tray"
		hint_enabled = bool(data["hint_enabled"])


class SettingsViewModel:
	extends RefCounted
	var revision: int
	var haptics_enabled: bool
	var music_enabled: bool
	var sound_effects_enabled: bool
	var pending: Dictionary
	var error_text: Dictionary

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		haptics_enabled = bool(data["haptics_enabled"])
		music_enabled = bool(data["music_enabled"])
		sound_effects_enabled = bool(data["sound_effects_enabled"])
		pending = data.get("pending", {}).duplicate(true)
		error_text = data.get("error_text", {}).duplicate(true)


class GuideViewModel:
	extends RefCounted
	var revision: int
	var step: StringName
	var description: String
	var can_skip: bool
	var reduced_motion: bool

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		step = StringName(data["step"])
		description = str(data["description"])
		can_skip = bool(data["can_skip"])
		reduced_motion = bool(data["reduced_motion"])


class CompletionViewModel:
	extends RefCounted
	var revision: int
	var theme_id: String
	var level_id: String
	var mode: StringName
	var completion_event_id: String
	var title: String
	var level_title: String
	var description: String
	var completed_texture: Texture2D
	var primary_action_text: String

	func _init(data: Dictionary) -> void:
		revision = int(data["revision"])
		theme_id = str(data["theme_id"])
		level_id = str(data["level_id"])
		mode = StringName(data["mode"])
		completion_event_id = str(data["completion_event_id"])
		title = str(data["title"])
		level_title = str(data["level_title"])
		description = str(data["description"])
		completed_texture = data["completed_texture"]
		primary_action_text = str(data["primary_action_text"])
