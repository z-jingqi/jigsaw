extends Node2D

const TITLE_IMAGE_PATH := "res://assets/ui/title.png"
const LEVEL_NAME_BANNER_PATH := "res://assets/ui/level_name_banner.png"
const OLIVE_BRANCH_PATH := "res://assets/ui/olive_branch.png"
const MODE_TITLE_SIDE_DECORATION_PATH := "res://assets/ui/mode_title_side_decoration.png"
const ICON_ALBUM_PATH := "res://assets/icons/album.svg"
const ICON_LEFT_ARROW_PATH := "res://assets/icons/left-arrow.svg"
const ICON_LIGHTBULB_PATH := "res://assets/icons/lightbulb.svg"
const ICON_PAUSE_PATH := "res://assets/icons/pause.svg"
const ICON_SETTING_PATH := "res://assets/icons/setting.svg"
const ICON_CAT_PAW_PATH := "res://assets/icons/status/cat_paw.png"
const ICON_MODE_KNOB_DONE_PATH := "res://assets/icons/status/mode_knob_done.png"
const ICON_MODE_KNOB_TODO_PATH := "res://assets/icons/status/mode_knob_todo.png"
const ICON_MODE_POLYGON_DONE_PATH := "res://assets/icons/status/mode_polygon_done.png"
const ICON_MODE_POLYGON_TODO_PATH := "res://assets/icons/status/mode_polygon_todo.png"
const ICON_MODE_SWAP_DONE_PATH := "res://assets/icons/status/mode_swap_done.png"
const ICON_MODE_SWAP_TODO_PATH := "res://assets/icons/status/mode_swap_todo.png"
const THEME_LIST_BG_PATH := "res://assets/ui/theme-list/theme-list-background.png"
const THEME_LOGO_PATH := "res://assets/ui/theme-list/jigcat-logo.png"
const THEME_SQUARE_BUTTON_PATH := "res://assets/ui/theme-list/square-button-base.png"
const THEME_CIRCLE_BUTTON_PATH := "res://assets/ui/theme-list/circle-arrow-button-base.png"
const THEME_SETTINGS_ICON_PATH := "res://assets/ui/theme-list/settings-icon.png"
const THEME_ARROW_ICON_PATH := "res://assets/ui/theme-list/arrow-right-icon.png"
const BoardLayoutScript := preload("res://scripts/BoardLayout.gd")
const ConfettiEffectScript := preload("res://scripts/ConfettiEffect.gd")
const DevTestPanelScript := preload("res://scripts/DevTestPanel.gd")
const LevelRepositoryScript := preload("res://scripts/LevelRepository.gd")
const ProgressStoreScript := preload("res://scripts/ProgressStore.gd")
const PuzzleBoardScript := preload("res://scripts/PuzzleBoard.gd")
const PLAY_MODES := ["polygon", "knob", "swap"]
const LEVEL_THUMBNAIL_SIZE := Vector2i(164, 164)
const UI_ICON_BUTTON_SIZE := 64.0
const UI_ICON_INSET := 8.0
const GAME_HINT_BUTTON_SCALE := 2.0
const HOME_ICON_BUTTON_SIZE := 72.0
const HOME_ICON_INSET := 8.0
const GAME_FOOTER_MARGIN := 18.0
const HUD_BLOCKER_PADDING := 18.0
const TOPICS_SCROLL_FRICTION := 7.0
const TOPICS_TAP_THRESHOLD := 14.0
const TOPICS_INERTIA_MIN_SPEED := 40.0
const UNLOCK_BURN_SHADER_CODE := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 seed_points[4];
uniform float aspect = 0.75;
uniform float field_max = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = vec2(UV.x * aspect, UV.y);
	float d = 1e9;
	for (int i = 0; i < 4; i++) {
		vec2 s = vec2(seed_points[i].x * aspect, seed_points[i].y);
		d = min(d, distance(p, s));
	}
	float n = texture(noise_tex, UV * 1.2).r;
	float fine = texture(noise_tex, UV * 4.0).r;
	float field = d / 1.55 + (n - 0.5) * 0.07;
	float front = mix(-0.04, field_max, progress);
	float edge = 0.05 + 0.02 * n;
	if (field < front) {
		discard;
	}
	float glow = 1.0 - smoothstep(front, front + edge, field);
	float char_band = 1.0 - smoothstep(front + edge * 0.5, front + edge * 2.2, field);
	vec3 color = mix(tex.rgb, tex.rgb * 0.22, char_band * 0.9);
	float flicker = 0.8 + 0.2 * sin(TIME * 7.0 + fine * 12.0);
	vec3 ember = mix(vec3(0.95, 0.25, 0.03), vec3(1.0, 0.85, 0.30), glow * flicker);
	color = mix(color, ember, glow);
	COLOR = vec4(color, tex.a);
}
"""
const HUD_DEBUG_MEASUREMENTS := false
const BUTTON_BOUNDS_DEBUG := false
const BUTTON_BOUNDS_DEBUG_COLOR := Color(0.16, 0.56, 1.0, 0.20)
const HUD_TEXT_BUTTON_FONT_SIZE := 22
const UI_TEXT := {
	"en": {
		"back": "Back",
		"album": "Album",
		"settings": "Settings",
		"hint": "Hint",
		"no_topics": "No topics yet",
		"no_levels": "No levels yet",
		"series_progress": "Progress",
		"mode_empty": "This level has no playable modes yet.",
		"start_game": "Start",
		"mode_polygon": "Polygon",
		"mode_knob": "Jigsaw",
		"mode_swap": "Swap",
		"done": "Completed",
		"todo": "Not completed",
		"replay": "Play again",
		"status_swap": "Drag one tile onto another to swap positions.",
		"status_drag_rotate": "Drag pieces. Double tap a piece to rotate. Drag the tablecloth and pinch to zoom.",
		"status_drag": "Drag pieces. Drag the tablecloth and pinch to zoom.",
		"status_missing_mode": "This level JSON is missing data for the current mode.",
		"pause": "Paused",
		"resume": "Resume",
		"continue": "Continue",
		"in_progress": "In progress",
		"undo": "Undo",
		"restart": "Restart",
		"return_levels": "Level list",
		"return_topics": "Topics",
		"confirm_restart": "Restart this level?",
		"confirm": "Confirm",
		"settings_title": "Settings",
		"music": "Music",
		"sfx": "Sound effects",
		"haptics": "Haptics",
		"reduce_motion": "Reduce motion",
		"piece_edges": "Piece edge contrast",
		"edge_auto": "Automatic",
		"edge_dark": "Dark",
		"edge_light": "Light",
		"random_rotation": "Random piece rotation (polygon / jigsaw)",
		"random_rotation_next": "Random rotation changes apply after restarting or entering another level.",
		"close": "Close",
		"tutorial_title": "How to play",
		"tutorial_swap": "Drag one tile onto another to swap their positions.\n\nDrag the empty tablecloth to move the board. Pinch to zoom.\n\nRestore every tile to the correct order to finish.",
		"tutorial_rotate": "Drag a piece from the tray and place it next to a locked neighboring piece.\n\nDouble tap a piece to rotate 90 degrees.\n\nDrag the empty tablecloth to move the board. Pinch to zoom.",
		"tutorial_drag": "Drag a piece from the tray and place it next to a locked neighboring piece.\n\nDrag the empty tablecloth to move the board. Pinch to zoom.",
		"got_it": "Got it",
		"complete": "Completed!",
		"completed_mode": "Completed: %s",
		"next": "Next",
		"switch_mode": "Other mode",
		"album_hint": "Album only stores completed puzzles. Finish more levels to unlock more.",
		"completed_modes": "Completed modes: %s",
		"swap_hint": "Drag any tile onto another tile to swap them.",
		"hint_none": "No nearby pieces can be hinted right now.",
		"hint_pair": "The highlighted pieces fit together.",
		"swapped": "Two tiles swapped.",
		"undone": "Last swap undone.",
		"pan_hint": "Drag the tablecloth to move the view. Pinch to zoom."
	},
	"zh": {
		"back": "返回",
		"album": "相册",
		"settings": "设置",
		"hint": "提示",
		"no_topics": "暂无主题",
		"no_levels": "暂无关卡",
		"series_progress": "进度",
		"mode_empty": "这个关卡还没有可玩的模式。",
		"start_game": "开始游戏",
		"mode_polygon": "多边形模式",
		"mode_knob": "经典拼图模式",
		"mode_swap": "方格交换",
		"done": "已完成",
		"todo": "未完成",
		"replay": "再玩一次",
		"status_swap": "拖动图片块到另一块上交换位置。",
		"status_drag_rotate": "拖动碎片。双击碎片旋转，空白处拖动桌布，双指缩放。",
		"status_drag": "拖动碎片。空白处拖动桌布，双指缩放。",
		"status_missing_mode": "关卡 JSON 缺少当前模式配置。",
		"pause": "已暂停",
		"resume": "继续游戏",
		"continue": "继续",
		"in_progress": "进行中",
		"undo": "撤销",
		"restart": "重新开始",
		"return_levels": "返回关卡列表",
		"return_topics": "返回主题选择",
		"confirm_restart": "确认重新开始？",
		"confirm": "确认",
		"settings_title": "设置",
		"music": "音乐",
		"sfx": "音效",
		"haptics": "震动反馈",
		"reduce_motion": "减少动态效果",
		"piece_edges": "碎片边线对比度",
		"edge_auto": "自动",
		"edge_dark": "深色",
		"edge_light": "浅色",
		"random_rotation": "碎片随机旋转（多边形 / 凹凸）",
		"random_rotation_next": "随机旋转设置将在重新开始或进入下一关后生效。",
		"close": "关闭",
		"tutorial_title": "怎么玩",
		"tutorial_swap": "拖动一块图片到另一块上，可以交换它们的位置。\n\n空白处拖动可以移动桌布，双指可以缩放。\n\n所有方格回到正确顺序后就会通关。",
		"tutorial_rotate": "从托盘拖出碎片，把它拼到已固定的相邻碎片旁。\n\n双击碎片可以旋转 90 度。\n\n空白处拖动可以移动桌布，双指可以缩放。",
		"tutorial_drag": "从托盘拖出碎片，把它拼到已固定的相邻碎片旁。\n\n空白处拖动可以移动桌布，双指可以缩放。",
		"got_it": "知道了",
		"complete": "恭喜完成！",
		"completed_mode": "已完成：%s",
		"next": "下一关",
		"switch_mode": "换个模式",
		"album_hint": "相册只收录已完成的拼图，继续完成关卡可解锁更多收藏。",
		"completed_modes": "已完成模式：%s",
		"swap_hint": "拖动任意一块图片到另一块上，即可交换它们的位置。",
		"hint_none": "暂时没有可提示的相邻碎片。",
		"hint_pair": "高亮的两块可以拼在一起。",
		"swapped": "已交换两块图片。",
		"undone": "已撤销上一次交换。",
		"pan_hint": "拖动桌布可移动视角，双指可缩放。"
	},
	"ja": {
		"back": "戻る",
		"album": "アルバム",
		"settings": "設定",
		"hint": "ヒント",
		"no_topics": "テーマはまだありません",
		"no_levels": "レベルはまだありません",
		"series_progress": "進行度",
		"mode_empty": "このレベルにはまだ遊べるモードがありません。",
		"start_game": "スタート",
		"mode_polygon": "ポリゴン",
		"mode_knob": "ジグソー",
		"mode_swap": "入れ替え",
		"done": "完成済み",
		"todo": "未完成",
		"replay": "もう一度",
		"status_swap": "画像タイルを別のタイルにドラッグして入れ替えます。",
		"status_drag_rotate": "ピースをドラッグ。ダブルタップで回転。背景をドラッグし、ピンチでズーム。",
		"status_drag": "ピースをドラッグ。背景をドラッグし、ピンチでズーム。",
		"status_missing_mode": "このレベル JSON には現在のモード設定がありません。",
		"pause": "一時停止",
		"resume": "続ける",
		"continue": "続きから",
		"in_progress": "進行中",
		"undo": "元に戻す",
		"restart": "最初から",
		"return_levels": "レベル一覧",
		"return_topics": "テーマへ",
		"confirm_restart": "このレベルをやり直しますか？",
		"confirm": "確認",
		"settings_title": "設定",
		"music": "音楽",
		"sfx": "効果音",
		"haptics": "振動",
		"reduce_motion": "視差効果を減らす",
		"piece_edges": "ピース境界線",
		"edge_auto": "自動",
		"edge_dark": "濃い色",
		"edge_light": "明るい色",
		"random_rotation": "ピースをランダム回転（ポリゴン / ジグソー）",
		"random_rotation_next": "ランダム回転の変更は再開または次のレベルから反映されます。",
		"close": "閉じる",
		"tutorial_title": "遊び方",
		"tutorial_swap": "タイルを別のタイルにドラッグして位置を入れ替えます。\n\n空いている背景をドラッグして移動し、ピンチでズームできます。\n\nすべて正しい順番に戻すと完成です。",
		"tutorial_rotate": "トレイからピースをドラッグし、固定済みの隣接ピースの横に置きます。\n\nダブルタップで 90 度回転します。\n\n空いている背景をドラッグして移動し、ピンチでズームできます。",
		"tutorial_drag": "トレイからピースをドラッグし、固定済みの隣接ピースの横に置きます。\n\n空いている背景をドラッグして移動し、ピンチでズームできます。",
		"got_it": "OK",
		"complete": "完成！",
		"completed_mode": "完成：%s",
		"next": "次へ",
		"switch_mode": "別モード",
		"album_hint": "アルバムには完成したパズルだけが保存されます。さらに完成させると増えます。",
		"completed_modes": "完成モード：%s",
		"swap_hint": "任意のタイルを別のタイルへドラッグして入れ替えます。",
		"hint_none": "今はヒントにできる隣接ピースがありません。",
		"hint_pair": "ハイライトされた 2 つはつながります。",
		"swapped": "2 枚のタイルを交換しました。",
		"undone": "直前の交換を元に戻しました。",
		"pan_hint": "背景をドラッグして移動し、ピンチでズームできます。"
	}
}

var cream := Color("#F6EBD4")
var paper := Color("#FFF6E6")
var soft_beige := Color("#F8E7C7")
var orange := Color("#D9933F")
var deep_orange := Color("#C77C2E")
var brown := Color("#5A3A22")
var soft_brown := Color("#8A6847")
var green := Color("#6f9d67")
var muted := Color("#b7aa97")

var texture: Texture2D
var repository = LevelRepositoryScript.new()
var title_texture: Texture2D
var level_name_banner_texture: Texture2D
var olive_branch_texture: Texture2D
var mode_title_side_decoration_texture: Texture2D
var icon_album: Texture2D
var icon_left_arrow: Texture2D
var icon_lightbulb: Texture2D
var icon_pause: Texture2D
var icon_setting: Texture2D
var icon_cat_paw: Texture2D
var icon_mode_knob_done: Texture2D
var icon_mode_knob_todo: Texture2D
var icon_mode_polygon_done: Texture2D
var icon_mode_polygon_todo: Texture2D
var icon_mode_swap_done: Texture2D
var icon_mode_swap_todo: Texture2D
var source_image: Image
var source_size := Vector2.ZERO
var source_scale := 1.0
var board_origin := Vector2.ZERO
var active_level_config := {}
var puzzle_board: PuzzleBoard
var ui_layer: CanvasLayer
var dev_layer: CanvasLayer
var dev_panel: Control
var screen_root: Control
var modal_root: Control

var topics: Array[Dictionary] = []
var progress_store = ProgressStoreScript.new()
var current_topic: Dictionary = {}
var current_level: Dictionary = {}
var current_mode := "knob"
var current_screen := "home"
var modal_open := false
var complete_confetti_layer: Control
var topics_content: Control
var topics_content_height := 0.0
var topics_scroll_offset := 0.0
var topics_scroll_velocity := 0.0
var topics_inertia_active := false
var topics_drag_active := false
var topics_drag_total := Vector2.ZERO
var topics_drag_last_msec := 0
var topics_island_items: Array[Dictionary] = []

var status_label: Label
var zoom_label: Label
var swap_undo_button: Button
var hud_blocker_controls: Array[Control] = []
var rounded_topic_cover_cache: Dictionary = {}
var rounded_level_thumbnail_cache: Dictionary = {}
var unlock_burn_shader: Shader = null
var unlock_burn_noise: Texture2D = null
var unlock_effect_style := "fire" # unlock reveal effect: "fire" or "shatter"
var rounded_complete_image_cache: Dictionary = {}
var active_locale := "en"
var newly_unlocked_topic_id := ""
var newly_unlocked_level_id := ""


func _ready() -> void:
	_lock_portrait_orientation()
	title_texture = repository.cached_texture(TITLE_IMAGE_PATH)
	level_name_banner_texture = repository.cached_texture(LEVEL_NAME_BANNER_PATH)
	olive_branch_texture = repository.cached_texture(OLIVE_BRANCH_PATH)
	mode_title_side_decoration_texture = repository.cached_texture(MODE_TITLE_SIDE_DECORATION_PATH)
	icon_album = load(ICON_ALBUM_PATH)
	icon_left_arrow = load(ICON_LEFT_ARROW_PATH)
	icon_lightbulb = load(ICON_LIGHTBULB_PATH)
	icon_pause = load(ICON_PAUSE_PATH)
	icon_setting = load(ICON_SETTING_PATH)
	icon_cat_paw = repository.cached_texture(ICON_CAT_PAW_PATH)
	icon_mode_knob_done = repository.cached_texture(ICON_MODE_KNOB_DONE_PATH)
	icon_mode_knob_todo = repository.cached_texture(ICON_MODE_KNOB_TODO_PATH)
	icon_mode_polygon_done = repository.cached_texture(ICON_MODE_POLYGON_DONE_PATH)
	icon_mode_polygon_todo = repository.cached_texture(ICON_MODE_POLYGON_TODO_PATH)
	icon_mode_swap_done = repository.cached_texture(ICON_MODE_SWAP_DONE_PATH)
	icon_mode_swap_todo = repository.cached_texture(ICON_MODE_SWAP_TODO_PATH)
	progress_store.load_from_disk()
	active_locale = _detect_locale()
	repository.set_locale(active_locale)
	puzzle_board = PuzzleBoardScript.new()
	puzzle_board.set_texts(_puzzle_board_texts())
	puzzle_board.status_changed.connect(_set_game_status)
	puzzle_board.zoom_changed.connect(_set_zoom_label)
	puzzle_board.completed.connect(_on_puzzle_completed)
	puzzle_board.state_changed.connect(_on_puzzle_state_changed)
	puzzle_board.undo_available_changed.connect(_set_swap_undo_available)
	puzzle_board.set_feedback_preferences(progress_store.haptics_enabled(), progress_store.reduced_motion_enabled(), progress_store.edge_contrast_mode())
	add_child(puzzle_board)
	get_viewport().size_changed.connect(_queue_game_drag_blocker_refresh)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_setup_dev_tools()
	_build_catalog()
	_apply_level_media({})
	set_process(false)
	_show_topics()


func _lock_portrait_orientation() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var is_dev_key := key_event.keycode == KEY_D or key_event.physical_keycode == KEY_D
		if key_event.pressed and not key_event.echo and is_dev_key and dev_panel != null:
			dev_panel.toggle()
			get_viewport().set_input_as_handled()
			return
	if dev_panel != null and dev_panel.visible:
		return
	if current_screen != "game":
		return
	if puzzle_board.handle_input(event, modal_open):
		get_viewport().set_input_as_handled()


func _setup_dev_tools() -> void:
	if not OS.is_debug_build():
		return
	dev_layer = CanvasLayer.new()
	dev_layer.layer = 128
	add_child(dev_layer)
	dev_panel = DevTestPanelScript.new()
	dev_layer.add_child(dev_panel)
	dev_panel.setup(self)


func debug_level_options() -> Array:
	var result: Array = []
	for topic in topics:
		for level in topic.get("levels", []):
			if typeof(level) != TYPE_DICTIONARY:
				continue
			var modes := _available_modes_for_level(level)
			if modes.is_empty():
				continue
			result.append({
				"label": "%s / %s" % [str(topic.get("name", "")), _level_display_title(level)],
				"topic_id": str(topic.get("id", "")),
				"level_id": str(level.get("id", "")),
				"modes": modes,
			})
	return result


func debug_enter_level(option_index: int, play_mode: String) -> void:
	var options := debug_level_options()
	if option_index < 0 or option_index >= options.size():
		return
	var option: Dictionary = options[option_index]
	var topic := _debug_topic_by_id(str(option.get("topic_id", "")))
	var level := _debug_level_by_id(topic, str(option.get("level_id", "")))
	if topic.is_empty() or level.is_empty():
		return
	_close_modal()
	_show_game(topic, level, play_mode)


func debug_restart_current_level() -> void:
	if current_topic.is_empty() or current_level.is_empty() or current_mode.is_empty():
		return
	_close_modal()
	progress_store.clear_play_state(current_topic, current_level, current_mode)
	_show_game(current_topic, current_level, current_mode, true)


func debug_apply_viewport_preset(size: Vector2i) -> void:
	if size.x > 0 and size.y > 0:
		get_window().size = size
	call_deferred("_debug_refresh_current_screen")


func debug_runtime_metrics() -> Dictionary:
	var metrics := {
		"screen": current_screen,
		"topic": str(current_topic.get("name", "")),
		"level": _level_display_title(current_level) if not current_level.is_empty() else "",
		"mode": current_mode,
	}
	if puzzle_board != null and puzzle_board.has_method("debug_runtime_metrics"):
		metrics.merge(puzzle_board.debug_runtime_metrics(), true)
	return metrics


func debug_trigger_hint() -> void:
	if current_screen == "game" and puzzle_board != null:
		puzzle_board.show_hint()


func debug_clear_hint() -> void:
	if puzzle_board != null and puzzle_board.has_method("debug_clear_hint"):
		puzzle_board.debug_clear_hint()


func debug_reset_tray() -> void:
	if puzzle_board != null and puzzle_board.has_method("debug_reset_tray"):
		puzzle_board.debug_reset_tray()


func debug_scroll_tray_left() -> void:
	if puzzle_board != null and puzzle_board.has_method("debug_scroll_tray_left"):
		puzzle_board.debug_scroll_tray_left()


func debug_scroll_tray_right() -> void:
	if puzzle_board != null and puzzle_board.has_method("debug_scroll_tray_right"):
		puzzle_board.debug_scroll_tray_right()


func debug_toggle_bounds_overlay() -> void:
	if puzzle_board != null and puzzle_board.has_method("debug_toggle_bounds_overlay"):
		puzzle_board.debug_toggle_bounds_overlay()


func debug_preview_complete() -> void:
	if current_topic.is_empty() or current_level.is_empty():
		var options := debug_level_options()
		if options.is_empty():
			return
		debug_enter_level(0, str(options[0].get("modes", ["polygon"])[0]))
	_show_complete_modal()


func debug_clear_current_progress() -> void:
	if current_level.is_empty():
		return
	progress_store.clear_level_progress(current_topic, current_level)
	_debug_refresh_current_screen()


func debug_clear_all_progress() -> void:
	progress_store.clear_all_progress()
	_debug_refresh_current_screen()


func debug_dump_state() -> void:
	var state := debug_runtime_metrics()
	if puzzle_board != null and puzzle_board.has_method("state_snapshot"):
		state["snapshot"] = puzzle_board.state_snapshot()
	print(JSON.stringify(state, "\t"))


func debug_run_current_interaction_smoke() -> Dictionary:
	if current_screen != "game" or puzzle_board == null:
		return {"ok": false, "reason": "no_active_game"}
	return await puzzle_board.debug_run_interaction_smoke()


func _debug_refresh_current_screen() -> void:
	if current_screen == "game" and not current_topic.is_empty() and not current_level.is_empty() and not current_mode.is_empty():
		_show_game(current_topic, current_level, current_mode)
	elif current_screen == "levels" and not current_topic.is_empty():
		_show_levels(current_topic, str(current_level.get("id", "")))
	else:
		_show_topics()


func _debug_topic_by_id(topic_id: String) -> Dictionary:
	for topic in topics:
		if str(topic.get("id", "")) == topic_id:
			return topic
	return {}


func _debug_level_by_id(topic: Dictionary, level_id: String) -> Dictionary:
	for level in topic.get("levels", []):
		if str(level.get("id", "")) == level_id:
			return level
	return {}


func _build_catalog() -> void:
	topics = repository.build_catalog()


func _detect_locale() -> String:
	var locale := OS.get_locale().replace("_", "-").to_lower()
	if locale.begins_with("zh"):
		return "zh"
	if locale.begins_with("ja"):
		return "ja"
	return "en"


func _t(key: String) -> String:
	var table: Dictionary = UI_TEXT.get(active_locale, UI_TEXT["en"])
	return str(table.get(key, UI_TEXT["en"].get(key, key)))


func _puzzle_board_texts() -> Dictionary:
	return {
		"swap_hint": _t("swap_hint"),
		"hint_none": _t("hint_none"),
		"hint_pair": _t("hint_pair"),
		"swapped": _t("swapped"),
		"undone": _t("undone"),
		"status_swap": _t("status_swap"),
		"pan_hint": _t("pan_hint"),
	}


func _clear_ui() -> void:
	_stop_complete_confetti()
	_stop_topics_inertia()
	topics_drag_active = false
	topics_island_items.clear()
	topics_content = null
	for child in ui_layer.get_children():
		child.queue_free()
	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.z_index = 0
	ui_layer.add_child(screen_root)
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.z_index = 100
	ui_layer.add_child(modal_root)
	modal_open = false


func _clear_board() -> void:
	if puzzle_board != null:
		puzzle_board.clear()


func _persist_current_puzzle_state() -> void:
	if puzzle_board == null or current_topic.is_empty() or current_level.is_empty() or current_mode.is_empty():
		return
	if not puzzle_board.should_persist_state():
		return
	progress_store.save_play_state(current_topic, current_level, current_mode, puzzle_board.state_snapshot())


func _ui_motion_reduced() -> bool:
	return progress_store.reduced_motion_enabled()


func _animate_screen_in(control: Control) -> void:
	if _ui_motion_reduced():
		control.modulate.a = 1.0
		control.position.y = 0.0
		return
	control.modulate.a = 0.0
	control.position.y = 18.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)
	tween.tween_property(control, "position:y", 0.0, 0.24)


func _fade_control_in(control: Control) -> void:
	if _ui_motion_reduced():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)


func _animate_modal_panel(panel: Control) -> void:
	if _ui_motion_reduced():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18)


func _wire_button_animation(button: BaseButton) -> void:
	_highlight_button_bounds(button)
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.button_down.connect(func() -> void:
		_tween_control_scale(button, Vector2(0.95, 0.95), 0.08)
	)
	button.button_up.connect(func() -> void:
		_tween_control_scale(button, Vector2.ONE, 0.12)
	)
	button.mouse_exited.connect(func() -> void:
		_tween_control_scale(button, Vector2.ONE, 0.12)
	)


func _tween_control_scale(control: Control, target: Vector2, duration: float) -> void:
	if not is_instance_valid(control):
		return
	if _ui_motion_reduced():
		control.scale = target
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "scale", target, duration)


func _highlight_button_bounds(button: BaseButton) -> void:
	if not BUTTON_BOUNDS_DEBUG or button == null or not is_instance_valid(button):
		return
	if button.has_node("button_bounds_debug"):
		return
	var overlay := ColorRect.new()
	overlay.name = "button_bounds_debug"
	overlay.color = BUTTON_BOUNDS_DEBUG_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 4096
	button.add_child(overlay)
	overlay.move_to_front()


func _rounded_topic_cover_texture(topic: Dictionary, target_size: Vector2i, radius: int) -> Texture2D:
	var cache_key := "%s@%dx%d@%d" % [str(topic.get("id", "")), target_size.x, target_size.y, radius]
	if rounded_topic_cover_cache.has(cache_key):
		return rounded_topic_cover_cache[cache_key]
	var source_texture := repository.topic_cover_texture(topic)
	if source_texture == null or target_size.x <= 0 or target_size.y <= 0:
		return source_texture
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var scale_factor := maxf(
		float(target_size.x) / float(image.get_width()),
		float(target_size.y) / float(image.get_height())
	)
	image.resize(
		maxi(target_size.x, int(ceil(float(image.get_width()) * scale_factor))),
		maxi(target_size.y, int(ceil(float(image.get_height()) * scale_factor))),
		Image.INTERPOLATE_LANCZOS
	)
	var offset := Vector2i(
		maxi(0, (image.get_width() - target_size.x) / 2),
		maxi(0, (image.get_height() - target_size.y) / 2)
	)
	image = image.get_region(Rect2i(offset, target_size))
	image.convert(Image.FORMAT_RGBA8)
	_apply_rounded_image_alpha(image, mini(radius, mini(target_size.x, target_size.y) / 2))
	var result := ImageTexture.create_from_image(image)
	rounded_topic_cover_cache[cache_key] = result
	return result


func _rounded_level_thumbnail_texture(image_path: String, target_size: Vector2i, radius: int) -> Texture2D:
	var cache_key := "%s@%dx%d@%d" % [image_path, target_size.x, target_size.y, radius]
	if rounded_level_thumbnail_cache.has(cache_key):
		return rounded_level_thumbnail_cache[cache_key]
	var source_texture := repository.texture_from_file(image_path)
	if source_texture == null or target_size.x <= 0 or target_size.y <= 0:
		return source_texture
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var scale_factor := maxf(
		float(target_size.x) / float(image.get_width()),
		float(target_size.y) / float(image.get_height())
	)
	image.resize(
		maxi(target_size.x, int(ceil(float(image.get_width()) * scale_factor))),
		maxi(target_size.y, int(ceil(float(image.get_height()) * scale_factor))),
		Image.INTERPOLATE_LANCZOS
	)
	var offset := Vector2i(
		maxi(0, (image.get_width() - target_size.x) / 2),
		maxi(0, (image.get_height() - target_size.y) / 2)
	)
	image = image.get_region(Rect2i(offset, target_size))
	image.convert(Image.FORMAT_RGBA8)
	_apply_rounded_image_alpha(image, mini(radius, mini(target_size.x, target_size.y) / 2))
	var result := ImageTexture.create_from_image(image)
	rounded_level_thumbnail_cache[cache_key] = result
	return result


func _rounded_complete_image_texture(image_path: String, target_size: Vector2i, radius: int) -> Texture2D:
	var cache_key := "%s@%dx%d@%d" % [image_path, target_size.x, target_size.y, radius]
	if rounded_complete_image_cache.has(cache_key):
		return rounded_complete_image_cache[cache_key]
	var source_texture := repository.cached_texture(image_path)
	if source_texture == null or target_size.x <= 0 or target_size.y <= 0:
		return source_texture
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var scale_factor := minf(
		float(target_size.x) / float(image.get_width()),
		float(target_size.y) / float(image.get_height())
	)
	var width := maxi(1, int(round(float(image.get_width()) * scale_factor)))
	var height := maxi(1, int(round(float(image.get_height()) * scale_factor)))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("#FFF6E6"))
	var offset := Vector2i((target_size.x - width) / 2, (target_size.y - height) / 2)
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, Vector2i(width, height)), offset)
	_apply_rounded_image_alpha(canvas, mini(radius, mini(target_size.x, target_size.y) / 2))
	var result := ImageTexture.create_from_image(canvas)
	rounded_complete_image_cache[cache_key] = result
	return result


func _apply_rounded_image_alpha(image: Image, radius: int) -> void:
	if radius <= 0:
		return
	var width := image.get_width()
	var height := image.get_height()
	var corner_center := Vector2(radius, radius)
	for y in height:
		for x in width:
			var edge_x := minf(float(x) + 0.5, float(width - x) - 0.5)
			var edge_y := minf(float(y) + 0.5, float(height - y) - 0.5)
			if edge_x >= radius or edge_y >= radius:
				continue
			var coverage := clampf(float(radius) + 0.5 - Vector2(edge_x, edge_y).distance_to(corner_center), 0.0, 1.0)
			if coverage >= 1.0:
				continue
			var color := image.get_pixel(x, y)
			color.a *= coverage
			image.set_pixel(x, y, color)


func _pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _hint_pulse_node(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	for i in 2:
		tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.24)
		tween.tween_property(node, "scale", Vector2.ONE, 0.34)


func _base_screen(bg_color: Color = Color("#F6EBD4")) -> VBoxContainer:
	_clear_ui()
	_clear_board()
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(bg)
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := _screen_margin()
	wrap.offset_left = margin
	wrap.offset_top = 28
	wrap.offset_right = -margin
	wrap.offset_bottom = -28
	wrap.add_theme_constant_override("separation", 18)
	screen_root.add_child(wrap)
	_animate_screen_in(wrap)
	return wrap


func _screen_margin() -> float:
	var width := get_viewport_rect().size.x
	if width < 430.0:
		return 16.0
	if width < 700.0:
		return 24.0
	return 36.0


func _header(parent: VBoxContainer, title: String, back: Callable = Callable()) -> void:
	var row := Control.new()
	row.custom_minimum_size.y = 84
	parent.add_child(row)
	if back.is_valid():
		var back_button := _icon_button(icon_left_arrow, back, _t("back"), UI_ICON_BUTTON_SIZE, UI_ICON_INSET, false, true, brown, deep_orange)
		back_button.position = Vector2(0, 12)
		row.add_child(back_button)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -220
	label.offset_top = 12
	label.offset_right = 220
	label.offset_bottom = 72
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", brown)
	row.add_child(label)


func _button(text: String, action: Callable, primary := true, min_size := Vector2(120, 42)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", Color.WHITE if primary else brown)
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else deep_orange)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = orange if primary else soft_beige
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.shadow_color = Color(0.42, 0.24, 0.07, 0.16) if primary else Color(0.42, 0.24, 0.07, 0.08)
	normal.shadow_size = 5 if primary else 3
	normal.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = deep_orange if primary else paper
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = deep_orange if primary else soft_beige
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _icon_button(
	icon: Texture2D,
	action: Callable,
	tooltip: String,
	button_size := UI_ICON_BUTTON_SIZE,
	icon_inset := UI_ICON_INSET,
	subtle_shadow := false,
	transparent := false,
	normal_icon_color := soft_brown,
	hover_icon_color := deep_orange,
) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = tooltip
	var icon_size := Vector2(button_size, button_size)
	button.custom_minimum_size = icon_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if transparent:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	elif _show_hud_debug_measurements():
		_apply_debug_control_background(button, Color(0.18, 0.52, 0.95, 0.24))
	else:
		var normal := _round_icon_style(Color(1.0, 0.96, 0.88, 0.92), button_size, subtle_shadow)
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = Color("#FFF2D8")
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = Color("#F8E7C7")
		button.add_theme_stylebox_override("pressed", pressed)
		for state in ["disabled", "focus"]:
			button.add_theme_stylebox_override(state, normal.duplicate())
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(button_size - icon_inset * 2.0, button_size - icon_inset * 2.0)
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = icon_inset
	icon_rect.offset_top = icon_inset
	icon_rect.offset_right = -icon_inset
	icon_rect.offset_bottom = -icon_inset
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.modulate = normal_icon_color
	button.add_child(icon_rect)
	button.mouse_entered.connect(func() -> void:
		icon_rect.modulate = hover_icon_color
	)
	button.mouse_exited.connect(func() -> void:
		icon_rect.modulate = normal_icon_color
	)
	button.button_down.connect(func() -> void:
		icon_rect.modulate = hover_icon_color
	)
	button.button_up.connect(func() -> void:
		icon_rect.modulate = normal_icon_color
	)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _round_icon_style(bg_color: Color, button_size := UI_ICON_BUTTON_SIZE, subtle_shadow := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.72, 0.50, 0.27, 0.20)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = int(button_size * 0.5)
	style.corner_radius_top_right = int(button_size * 0.5)
	style.corner_radius_bottom_left = int(button_size * 0.5)
	style.corner_radius_bottom_right = int(button_size * 0.5)
	style.shadow_color = Color(0.42, 0.24, 0.07, 0.06 if subtle_shadow else 0.14)
	style.shadow_size = 2 if subtle_shadow else 5
	style.shadow_offset = Vector2(0, 1 if subtle_shadow else 2)
	return style


func _rounded_panel_style(bg_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _tool_text_button(text: String, action: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(_hud_text_button_width(text), _hud_text_button_height())
	button.add_theme_font_size_override("font_size", HUD_TEXT_BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", soft_brown)
	button.add_theme_color_override("font_hover_color", deep_orange)
	button.add_theme_color_override("font_pressed_color", deep_orange)
	if _show_hud_debug_measurements():
		_apply_debug_control_background(button, Color(0.95, 0.56, 0.18, 0.24))
	else:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override(state, empty)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _show_hud_debug_measurements() -> bool:
	return HUD_DEBUG_MEASUREMENTS and current_screen == "game"


func _apply_debug_control_background(control: Control, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color(0.22, 0.13, 0.04, 0.9)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	control.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "disabled", "focus"]:
		control.add_theme_stylebox_override(state, normal.duplicate())


func _image_rect(min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = min_size
	return rect


func _texture_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = min_size
	return rect


func _home_image_button(
	text: String,
	action: Callable,
	bg_texture: Texture2D = null,
	label_color := Color.WHITE,
	min_size := Vector2(420, 94),
) -> Button:
	return _button(text, action, label_color == Color.WHITE, min_size)


func _show_home() -> void:
	_show_topics()


func _start_from_home() -> void:
	var target := progress_store.resume_target(topics)
	if target.is_empty() or target["level"].is_empty():
		_show_topics()
		return
	_show_game(target["topic"], target["level"], target["mode"])


func _show_last_topic_levels() -> void:
	var topic := progress_store.last_topic_or_first(topics)
	if topic.is_empty():
		_show_topics()
		return
	_show_levels(topic, progress_store.focus_level_id(topic))


func _show_topics() -> void:
	_persist_current_puzzle_state()
	current_screen = "topics"
	_clear_ui()
	_clear_board()
	var ui_scale := _topics_ui_scale()
	var viewport_size := get_viewport_rect().size
	_add_theme_list_background()
	topics_island_items.clear()
	topics_scroll_offset = 0.0
	topics_scroll_velocity = 0.0
	topics_drag_active = false
	topics_content = Control.new()
	topics_content.name = "topics_content"
	topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(topics_content)
	var columns := 2 if viewport_size.x / maxf(1.0, viewport_size.y) >= 0.65 else 1
	var side_margin := 18.0 * ui_scale
	var gap := 6.0 * ui_scale
	var card_width := (viewport_size.x - side_margin * 2.0 - gap * float(columns - 1)) / float(columns)
	var card_height := card_width * _theme_card_aspect()
	var count := topics.size()
	var top := _grid_top_offset(_theme_topbar_height(ui_scale), ui_scale)
	var y := top
	if topics.is_empty():
		var empty := _empty_topic_message()
		empty.position = Vector2((viewport_size.x - empty.custom_minimum_size.x) * 0.5, y)
		topics_content.add_child(empty)
		y += empty.custom_minimum_size.y
	for index in count:
		var topic: Dictionary = topics[index]
		var col := index % columns
		var row := index / columns
		var x := side_margin + float(col) * (card_width + gap)
		y = top + float(row) * (card_height + gap)
		var card := _theme_card(topic, card_width, ui_scale)
		card.position = Vector2(x, y)
		topics_content.add_child(card)
		topics_island_items.append({
			"rect": Rect2(Vector2(x, y), Vector2(card_width, card_height)),
			"action": func(t: Dictionary = topic) -> void: _show_levels(t, progress_store.focus_level_id(t)),
		})
	if not topics.is_empty():
		y += card_height
	topics_content_height = y + 32.0 * ui_scale
	var catcher := Control.new()
	catcher.name = "topics_scroll_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_topics_gui_input)
	screen_root.add_child(catcher)
	screen_root.add_child(_theme_list_topbar(ui_scale))
	_apply_topics_scroll()
	_fade_control_in(topics_content)


func _topics_ui_scale() -> float:
	# capped below the raw iPad ratio so top-bar chrome stays compact and
	# the freed width goes to the cards instead
	return clampf(get_viewport_rect().size.x / 390.0, 1.0, 3.3)


func _grid_top_offset(topbar_bottom: float, ui_scale: float) -> float:
	return topbar_bottom + 10.0 * ui_scale


func _theme_topbar_height(ui_scale: float) -> float:
	return 104.0 * ui_scale


func _add_theme_list_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#FBF0DC")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(bg)
	var paper_bg := TextureRect.new()
	paper_bg.texture = repository.cached_texture(THEME_LIST_BG_PATH)
	paper_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(paper_bg)


func _theme_list_topbar(ui_scale: float) -> Control:
	var viewport_width := get_viewport_rect().size.x
	var bar := Control.new()
	bar.name = "theme_topbar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = _theme_topbar_height(ui_scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button_size := 64.0 * ui_scale
	var side_margin := 20.0 * ui_scale
	var settings_button := _theme_square_button(THEME_SETTINGS_ICON_PATH, _show_settings_modal, _t("settings"), button_size)
	settings_button.name = "theme_settings_button"
	settings_button.position = Vector2(viewport_width - side_margin - button_size, 18.0 * ui_scale)
	bar.add_child(settings_button)
	var logo := TextureRect.new()
	logo.name = "theme_logo"
	logo.texture = repository.cached_texture(THEME_LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_width := minf(viewport_width * 0.49, 230.0 * ui_scale)
	var logo_height := logo_width * 0.5
	logo.position = Vector2((viewport_width - logo_width) * 0.5, 4.0 * ui_scale)
	logo.size = Vector2(logo_width, logo_height)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(logo)
	return bar


func _theme_square_button(icon_path: String, action: Callable, tooltip: String, button_size: float) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.size = button.custom_minimum_size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var base := TextureRect.new()
	base.texture = repository.cached_texture(THEME_SQUARE_BUTTON_PATH)
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(base)
	var icon := TextureRect.new()
	icon.texture = repository.cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inset := button_size * 0.24
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button



func _theme_card_aspect() -> float:
	return 0.285


func _theme_card(topic: Dictionary, card_width: float, ui_scale: float) -> Control:
	var card_height := card_width * _theme_card_aspect()
	var topic_color := _topic_color(topic)
	var done := _topic_available_done_count(topic)
	var total := _topic_available_mode_total(topic)
	var ratio := 0.0 if total <= 0 else clampf(float(done) / float(total), 0.0, 1.0)
	var card := Control.new()
	card.name = "theme_card_%s" % str(topic.get("id", ""))
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_radius := int(card_height * 0.10)
	var base := Panel.new()
	base.name = "theme_card_base"
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	var base_style := _rounded_panel_style(Color("#FFF8EC").lerp(topic_color, 0.16), card_radius)
	base_style.border_color = topic_color.lightened(0.14)
	base_style.border_color.a = 0.5
	base_style.border_width_left = 1
	base_style.border_width_top = 1
	base_style.border_width_right = 1
	base_style.border_width_bottom = 1
	base_style.shadow_color = Color(0.35, 0.23, 0.13, 0.14)
	base_style.shadow_size = int(5.0 * ui_scale)
	base_style.shadow_offset = Vector2(0, 2.0 * ui_scale)
	base.add_theme_stylebox_override("panel", base_style)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(base)
	var pad := 5.0 * ui_scale
	var top_y := pad
	var bottom_y := card_height - pad
	var cover_height := card_height - pad * 2.0
	var cover_width := cover_height * 1.58
	var cover_radius := int(card_radius * 0.75)
	var cover_texture := _rounded_topic_cover_texture(topic, Vector2i(int(cover_width), int(cover_height)), cover_radius)
	if cover_texture != null:
		var cover_rect := TextureRect.new()
		cover_rect.name = "theme_card_cover"
		cover_rect.texture = cover_texture
		cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover_rect.stretch_mode = TextureRect.STRETCH_SCALE
		cover_rect.position = Vector2(pad, top_y)
		cover_rect.size = Vector2(cover_width, cover_height)
		cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cover_rect)
	else:
		var cover := Panel.new()
		cover.name = "theme_card_cover"
		cover.position = Vector2(pad, top_y)
		cover.size = Vector2(cover_width, cover_height)
		cover.add_theme_stylebox_override("panel", _rounded_panel_style(Color("#FFF5E3").lerp(topic_color, 0.26), cover_radius))
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cover)
		var fallback_path := str(topic.get("island", ""))
		var fallback_texture := repository.cached_texture(fallback_path) if not fallback_path.is_empty() else null
		if fallback_texture != null:
			var art := TextureRect.new()
			art.name = "theme_card_cover_art"
			art.texture = fallback_texture
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var art_inset := cover_height * 0.035
			art.position = Vector2(pad + art_inset, top_y + art_inset)
			art.size = Vector2(cover_width - art_inset * 2.0, cover_height - art_inset * 2.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
	var text_x := pad + cover_width + card_width * 0.04
	var circle_size := card_height * 0.38
	var right_edge := card_width - pad - card_width * 0.025
	var badge_size := Vector2(card_height * 0.36, card_height * 0.18)
	var badge_position := Vector2(right_edge - badge_size.x, top_y + card_height * 0.07)
	var title := Label.new()
	title.name = "theme_card_title"
	title.text = str(topic.get("name", ""))
	title.position = Vector2(text_x, top_y + card_height * 0.14)
	title.size = Vector2(maxf(0.0, badge_position.x - text_x - card_width * 0.02), card_height * 0.24)
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", maxi(16, int(card_height * 0.17)))
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var bar_height := card_height * 0.085
	var available_bar_width := right_edge - circle_size - card_width * 0.025 - text_x
	var bar_width := minf(card_width * 0.32, maxf(card_width * 0.22, available_bar_width))
	var bar := _topic_progress_bar(done, total, Vector2(bar_width, bar_height), topic_color)
	bar.name = "theme_card_progress"
	bar.position = Vector2(text_x, top_y + card_height * 0.60)
	card.add_child(bar)
	var count_height := card_height * 0.14
	var count := Label.new()
	count.name = "theme_card_progress_count"
	count.text = "%d/%d" % [done, total]
	count.position = Vector2(text_x, top_y + card_height * 0.73)
	count.size = Vector2(bar_width, count_height)
	count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	count.add_theme_font_size_override("font_size", maxi(12, int(card_height * 0.11)))
	count.add_theme_color_override("font_color", soft_brown)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(count)
	var badge := Panel.new()
	badge.name = "theme_card_percent_badge"
	badge.position = badge_position
	badge.size = badge_size
	var badge_style := _rounded_panel_style(topic_color, int(badge_size.y * 0.5))
	badge_style.border_color = Color(1.0, 1.0, 1.0, 0.75)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	var percent := Label.new()
	percent.text = "%d%%" % roundi(ratio * 100.0)
	percent.set_anchors_preset(Control.PRESET_FULL_RECT)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size", maxi(12, int(card_height * 0.105)))
	percent.add_theme_color_override("font_color", Color.WHITE)
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(percent)
	var circle := TextureRect.new()
	circle.name = "theme_card_arrow_button"
	circle.texture = repository.cached_texture(THEME_CIRCLE_BUTTON_PATH)
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle.position = Vector2(right_edge - circle_size, bottom_y - circle_size - card_height * 0.10)
	circle.size = Vector2(circle_size, circle_size)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(circle)
	var arrow := TextureRect.new()
	arrow.texture = repository.cached_texture(THEME_ARROW_ICON_PATH)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var arrow_inset := circle_size * 0.28
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.offset_left = arrow_inset
	arrow.offset_top = arrow_inset
	arrow.offset_right = -arrow_inset
	arrow.offset_bottom = -arrow_inset
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(arrow)
	return card


func _on_topics_gui_input(event: InputEvent) -> void:
	if current_screen != "topics" and current_screen != "levels":
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var wheel_step := 160.0 * _topics_ui_scale() * maxf(mouse_event.factor, 0.25)
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_impulse_topics_scroll(-wheel_step)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_impulse_topics_scroll(wheel_step)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_topics_drag()
			else:
				_end_topics_drag(mouse_event.position)
	elif event is InputEventMouseMotion:
		if topics_drag_active:
			_update_topics_drag(event as InputEventMouseMotion)
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		_stop_topics_inertia()
		_scroll_topics_to(topics_scroll_offset + pan.delta.y * 14.0 * _topics_ui_scale())


func _begin_topics_drag() -> void:
	_stop_topics_inertia()
	topics_drag_active = true
	topics_drag_total = Vector2.ZERO
	topics_drag_last_msec = Time.get_ticks_msec()


func _update_topics_drag(motion: InputEventMouseMotion) -> void:
	topics_drag_total += motion.relative
	var now := Time.get_ticks_msec()
	var elapsed := maxf(0.001, float(now - topics_drag_last_msec) / 1000.0)
	topics_drag_last_msec = now
	topics_scroll_velocity = -motion.relative.y / elapsed
	_scroll_topics_to(topics_scroll_offset - motion.relative.y)


func _end_topics_drag(screen_pos: Vector2) -> void:
	if not topics_drag_active:
		return
	topics_drag_active = false
	if topics_drag_total.length() <= TOPICS_TAP_THRESHOLD * _topics_ui_scale() * 0.5:
		topics_scroll_velocity = 0.0
		_activate_island_at(screen_pos)
		return
	if absf(topics_scroll_velocity) >= TOPICS_INERTIA_MIN_SPEED * 3.0:
		topics_inertia_active = true
		set_process(true)
	else:
		topics_scroll_velocity = 0.0


func _activate_island_at(screen_pos: Vector2) -> void:
	var content_pos := screen_pos + Vector2(0.0, topics_scroll_offset)
	for item in topics_island_items:
		var rect: Rect2 = item["rect"]
		if rect.has_point(content_pos):
			var action = item.get("action", null)
			if action is Callable and action.is_valid():
				action.call()
			return


func _scroll_topics_to(target: float) -> void:
	topics_scroll_offset = clampf(target, 0.0, _topics_max_scroll())
	_apply_topics_scroll()


func _topics_max_scroll() -> float:
	return maxf(0.0, topics_content_height - get_viewport_rect().size.y)


func _apply_topics_scroll() -> void:
	if topics_content != null and is_instance_valid(topics_content):
		topics_content.position.y = -topics_scroll_offset


func _impulse_topics_scroll(distance: float) -> void:
	topics_scroll_velocity += distance * TOPICS_SCROLL_FRICTION
	topics_inertia_active = true
	set_process(true)


func _stop_topics_inertia() -> void:
	topics_inertia_active = false
	topics_scroll_velocity = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if not topics_inertia_active or (current_screen != "topics" and current_screen != "levels"):
		_stop_topics_inertia()
		return
	var previous := topics_scroll_offset
	_scroll_topics_to(topics_scroll_offset + topics_scroll_velocity * delta)
	topics_scroll_velocity *= maxf(0.0, 1.0 - TOPICS_SCROLL_FRICTION * delta)
	if absf(topics_scroll_velocity) < TOPICS_INERTIA_MIN_SPEED or is_equal_approx(previous, topics_scroll_offset):
		_stop_topics_inertia()


func _show_levels(topic: Dictionary, focus_level_id := "") -> void:
	_persist_current_puzzle_state()
	current_screen = "levels"
	current_topic = topic
	_clear_ui()
	_clear_board()
	var ui_scale := _topics_ui_scale()
	var viewport_size := get_viewport_rect().size
	_add_level_list_background(topic)
	topics_island_items.clear()
	topics_scroll_offset = 0.0
	topics_scroll_velocity = 0.0
	topics_drag_active = false
	topics_content = Control.new()
	topics_content.name = "levels_content"
	topics_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(topics_content)
	var columns := 3 if viewport_size.x / maxf(1.0, viewport_size.y) >= 0.65 else 2
	var side_margin := 14.0 * ui_scale
	var gap := 10.0 * ui_scale
	var card_width := (viewport_size.x - side_margin * 2.0 - gap * float(columns - 1)) / float(columns)
	var card_height := card_width * 4.0 / 3.0
	var locks := _compute_level_locks(topic)
	var levels: Array = topic.get("levels", [])
	var count := levels.size()
	var top := _grid_top_offset(_theme_topbar_height(ui_scale), ui_scale)
	var y := top
	var focus_row := -1
	if levels.is_empty():
		var empty := _empty_level_message()
		empty.position = Vector2((viewport_size.x - empty.custom_minimum_size.x) * 0.5, y)
		topics_content.add_child(empty)
		y += empty.custom_minimum_size.y
	for index in count:
		var level: Dictionary = levels[index]
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var col := index % columns
		var row := index / columns
		var x := side_margin + float(col) * (card_width + gap)
		y = top + float(row) * (card_height + gap)
		var unlocked: bool = locks.get(str(level.get("id", "")), false)
		var card := _level_grid_card(topic, level, unlocked, card_width, ui_scale)
		card.position = Vector2(x, y)
		topics_content.add_child(card)
		if unlocked and str(topic.get("id", "")) == newly_unlocked_topic_id and str(level.get("id", "")) == newly_unlocked_level_id:
			_animate_new_unlock_card(card, topic, card_width)
		var item := {"rect": Rect2(Vector2(x, y), Vector2(card_width, card_height))}
		if unlocked:
			item["action"] = func(l: Dictionary = level) -> void: _show_mode_dialog(l)
		topics_island_items.append(item)
		if str(level.get("id", "")) == focus_level_id:
			focus_row = row
	if not levels.is_empty():
		y += card_height
	topics_content_height = y + 32.0 * ui_scale
	var catcher := Control.new()
	catcher.name = "levels_scroll_catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_topics_gui_input)
	screen_root.add_child(catcher)
	screen_root.add_child(_level_list_topbar(topic, ui_scale))
	if focus_row > 0:
		topics_scroll_offset = clampf(top + float(focus_row) * (card_height + gap) - viewport_size.y * 0.30, 0.0, _topics_max_scroll())
	_apply_topics_scroll()
	_fade_control_in(topics_content)
	if str(topic.get("id", "")) == newly_unlocked_topic_id:
		newly_unlocked_topic_id = ""
		newly_unlocked_level_id = ""


func _compute_level_locks(topic: Dictionary) -> Dictionary:
	# first level is free; completing any mode of a level grants `unlock_grant`
	# (default 1) further unlocks down the list
	var unlocked := {}
	var budget := 1
	for level in topic.get("levels", []):
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var level_id := str(level.get("id", ""))
		if budget > 0:
			unlocked[level_id] = true
			budget -= 1
			if not progress_store.completed_modes(level_id).is_empty():
				budget += maxi(1, int(level.get("unlock_grant", 1)))
		else:
			unlocked[level_id] = false
	return unlocked


func _add_level_list_background(topic: Dictionary) -> void:
	var topic_color := _topic_color(topic)
	var bg := ColorRect.new()
	bg.color = topic_color.darkened(0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(bg)
	var bg_path := str(topic.get("level_background", ""))
	var bg_texture := repository.cached_texture(bg_path) if not bg_path.is_empty() else null
	if bg_texture != null:
		var image_bg := TextureRect.new()
		image_bg.texture = bg_texture
		image_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		image_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_root.add_child(image_bg)
		return
	var glow := ColorRect.new()
	glow.color = Color(topic_color.lightened(0.30), 0.16)
	glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = get_viewport_rect().size.y * 0.30
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(glow)


func _level_list_topbar(topic: Dictionary, ui_scale: float) -> Control:
	var viewport_width := get_viewport_rect().size.x
	var palette := _topic_ui_palette(topic)
	var surface: Color = palette.surface
	var foreground: Color = palette.foreground
	var outline: Color = palette.outline
	var accent: Color = palette.accent
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = _theme_topbar_height(ui_scale)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button_size := 52.0 * ui_scale
	var side_margin := 20.0 * ui_scale
	var back_button := _level_back_button(button_size, palette)
	back_button.position = Vector2(side_margin, 20.0 * ui_scale)
	bar.add_child(back_button)
	var title_panel := Panel.new()
	title_panel.position = Vector2(viewport_width * 0.22, 20.0 * ui_scale)
	title_panel.size = Vector2(viewport_width * 0.56, button_size)
	var title_style := _rounded_panel_style(surface, int(button_size * 0.48))
	title_style.border_color = outline
	title_style.border_width_left = maxi(1, int(ui_scale))
	title_style.border_width_top = maxi(1, int(ui_scale))
	title_style.border_width_right = maxi(1, int(ui_scale))
	title_style.border_width_bottom = maxi(1, int(ui_scale))
	title_style.shadow_color = Color(outline, 0.22)
	title_style.shadow_size = maxi(2, int(4.0 * ui_scale))
	title_style.shadow_offset = Vector2(0.0, 2.0 * ui_scale)
	title_panel.add_theme_stylebox_override("panel", title_style)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title_panel)
	var title := Label.new()
	title.text = str(topic.get("name", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", int(26.0 * ui_scale))
	title.add_theme_color_override("font_color", foreground)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title)
	var done := _topic_available_done_count(topic)
	var total := _topic_available_mode_total(topic)
	var pill_size := Vector2(96.0 * ui_scale, 34.0 * ui_scale)
	var pill := Panel.new()
	pill.position = Vector2(viewport_width - side_margin - pill_size.x, 20.0 * ui_scale + (button_size - pill_size.y) * 0.5)
	pill.size = pill_size
	var pill_style := _rounded_panel_style(surface, int(pill_size.y * 0.5))
	pill_style.border_color = outline
	pill_style.border_width_left = maxi(1, int(ui_scale))
	pill_style.border_width_top = maxi(1, int(ui_scale))
	pill_style.border_width_right = maxi(1, int(ui_scale))
	pill_style.border_width_bottom = maxi(1, int(ui_scale))
	pill_style.shadow_color = Color(outline, 0.18)
	pill_style.shadow_size = maxi(1, int(3.0 * ui_scale))
	pill_style.shadow_offset = Vector2(0.0, 1.0 * ui_scale)
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pill)
	var pill_bar := _topic_progress_bar(done, total, Vector2(pill_size.x * 0.42, 7.0 * ui_scale), accent, Color(outline, 0.28))
	pill_bar.position = Vector2(pill_size.x * 0.10, (pill_size.y - 7.0 * ui_scale) * 0.5)
	pill.add_child(pill_bar)
	var pill_label := Label.new()
	pill_label.text = "%d/%d" % [done, total]
	pill_label.position = Vector2(pill_size.x * 0.56, 0.0)
	pill_label.size = Vector2(pill_size.x * 0.38, pill_size.y)
	pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_label.add_theme_font_size_override("font_size", int(13.0 * ui_scale))
	pill_label.add_theme_color_override("font_color", foreground)
	pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(pill_label)
	return bar


func _level_back_button(button_size: float, palette: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = _t("back")
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.size = button.custom_minimum_size
	var surface: Color = palette.surface
	var outline: Color = palette.outline
	button.add_theme_stylebox_override("normal", _topic_nav_button_style(surface, outline, button_size))
	button.add_theme_stylebox_override("hover", _topic_nav_button_style(surface.lightened(0.06), outline, button_size))
	button.add_theme_stylebox_override("pressed", _topic_nav_button_style(surface.darkened(0.04), outline, button_size, false))
	button.add_theme_stylebox_override("disabled", _topic_nav_button_style(surface, outline, button_size, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var arrow := TextureRect.new()
	arrow.texture = repository.cached_texture(THEME_ARROW_ICON_PATH)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.flip_h = true
	var inset := button_size * 0.28
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.offset_left = inset
	arrow.offset_top = inset
	arrow.offset_right = -inset
	arrow.offset_bottom = -inset
	arrow.modulate = palette.foreground
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(arrow)
	button.pressed.connect(_show_topics)
	_wire_button_animation(button)
	return button


func _topic_nav_button_style(surface: Color, outline: Color, button_size: float, with_shadow := true) -> StyleBoxFlat:
	var style := _rounded_panel_style(surface, int(button_size * 0.5))
	style.border_color = outline
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if with_shadow:
		style.shadow_color = Color(outline, 0.22)
		style.shadow_size = maxi(2, int(button_size * 0.08))
		style.shadow_offset = Vector2(0.0, button_size * 0.04)
	return style


func _level_grid_card(topic: Dictionary, level: Dictionary, unlocked: bool, card_width: float, ui_scale: float) -> Control:
	var card_height := card_width * 4.0 / 3.0
	var topic_color := _topic_color(topic)
	var radius := int(card_width * 0.07)
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_width, card_height)
	card.size = card.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		_add_level_card_back(card, topic, topic_color, card_width, card_height, radius)
		return card
	var level_config := repository.load_level_config(level)
	_add_level_card_cover(card, level_config, topic_color, card_width, card_height, radius)
	var overlay_height := card_height * 0.27
	var overlay := Panel.new()
	overlay.name = "level_card_overlay"
	overlay.position = Vector2(0.0, card_height - overlay_height)
	overlay.size = Vector2(card_width, overlay_height)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.08, 0.07, 0.06, 0.42)
	overlay_style.corner_radius_bottom_left = radius
	overlay_style.corner_radius_bottom_right = radius
	overlay.add_theme_stylebox_override("panel", overlay_style)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(overlay)
	var available_modes := _available_modes_for_config(level_config)
	var name_label := Label.new()
	name_label.text = _level_display_title(level)
	name_label.position = Vector2(card_width * 0.05, overlay_height * 0.06)
	name_label.size = Vector2(card_width * 0.90, overlay_height * 0.42)
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", maxi(14, int(overlay_height * 0.34)))
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(name_label)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", int(card_width * 0.075))
	icons.position = Vector2(0.0, overlay_height * 0.50)
	icons.size = Vector2(card_width, overlay_height * 0.44)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icons)
	var icon_size := overlay_height * 0.40
	for play_mode in available_modes:
		var state := _level_mode_state(topic, level, play_mode)
		var icon := _mode_state_icon(play_mode, state, icon_size)
		icons.add_child(icon)
	return card


func _add_level_card_cover(card: Control, level_config: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> void:
	var thumb_path := repository.level_thumbnail_source_path(level_config)
	var cover_texture: Texture2D = null
	if not thumb_path.is_empty() and (ResourceLoader.exists(thumb_path) or FileAccess.file_exists(repository.image_file_path(thumb_path))):
		cover_texture = _rounded_level_thumbnail_texture(thumb_path, Vector2i(int(card_width), int(card_height)), radius)
	if cover_texture != null:
		var rect := TextureRect.new()
		rect.name = "level_card_cover"
		rect.texture = cover_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rect)
		return
	var panel := Panel.new()
	panel.name = "level_card_cover"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := _rounded_panel_style(topic_color.lightened(0.18), radius)
	style.border_color = topic_color.lightened(0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)


func _add_level_card_back(card: Control, topic: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> void:
	var back_path := str(topic.get("card_back", ""))
	var back_texture := repository.cached_texture(back_path) if not back_path.is_empty() else null
	if back_texture != null:
		var rect := TextureRect.new()
		rect.name = "level_card_back"
		rect.texture = back_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rect)
	else:
		var panel := Panel.new()
		panel.name = "level_card_back"
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var style := _rounded_panel_style(topic_color.darkened(0.42), radius)
		style.border_color = topic_color.lightened(0.10)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(panel)
		var inner := Panel.new()
		inner.position = Vector2(card_width * 0.06, card_width * 0.06)
		inner.size = Vector2(card_width * 0.88, card_height - card_width * 0.12)
		var inner_style := StyleBoxFlat.new()
		inner_style.draw_center = false
		inner_style.border_color = Color(topic_color.lightened(0.20), 0.55)
		inner_style.border_width_left = 2
		inner_style.border_width_top = 2
		inner_style.border_width_right = 2
		inner_style.border_width_bottom = 2
		inner_style.corner_radius_top_left = int(radius * 0.7)
		inner_style.corner_radius_top_right = int(radius * 0.7)
		inner_style.corner_radius_bottom_left = int(radius * 0.7)
		inner_style.corner_radius_bottom_right = int(radius * 0.7)
		inner.add_theme_stylebox_override("panel", inner_style)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)


func _level_mode_state(topic: Dictionary, level: Dictionary, play_mode: String) -> String:
	if progress_store.is_done(str(level.get("id", "")), play_mode):
		return "done"
	if not progress_store.play_state(topic, level, play_mode).is_empty():
		return "active"
	return "todo"


func _mode_state_icon(play_mode: String, state: String, size: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = _mode_icon_texture(play_mode, state == "done")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "active":
		var dot_size := size * 0.36
		var dot := Panel.new()
		dot.position = Vector2(size - dot_size * 0.80, size - dot_size * 0.80)
		dot.size = Vector2(dot_size, dot_size)
		var dot_style := _rounded_panel_style(orange, int(dot_size * 0.5))
		dot_style.border_color = Color.WHITE
		dot_style.border_width_left = 2
		dot_style.border_width_top = 2
		dot_style.border_width_right = 2
		dot_style.border_width_bottom = 2
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(dot)
	return rect


func _level_display_title(level: Dictionary) -> String:
	var title := str(level.get("title", "")).strip_edges()
	if title.is_empty():
		return str(level.get("id", ""))
	return title


func _color_from_value(value: String, fallback: Color) -> Color:
	var clean := value.strip_edges()
	return Color(clean) if clean.begins_with("#") else fallback


func _empty_level_message() -> Label:
	var label := Label.new()
	label.text = _t("no_levels")
	label.custom_minimum_size = Vector2(380, 110)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", soft_brown)
	return label


func _empty_topic_message() -> Label:
	var label := Label.new()
	label.text = _t("no_topics")
	label.custom_minimum_size = Vector2(380, 160)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", soft_brown)
	return label


func _topic_progress_block(topic: Dictionary) -> Control:
	var holder := HBoxContainer.new()
	holder.custom_minimum_size.y = 44
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = _t("series_progress")
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", brown)
	holder.add_child(label)
	holder.add_child(_progress_bar(_topic_available_done_count(topic), _topic_available_mode_total(topic), Vector2(250, 12)))
	var count := Label.new()
	count.text = "%d/%d" % [_topic_available_done_count(topic), _topic_available_mode_total(topic)]
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", brown)
	holder.add_child(count)
	return holder


func _progress_bar(done: int, total: int, size: Vector2, light_track := false) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = size
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 0.96, 0.86, 0.72) if light_track else Color(0.78, 0.64, 0.48, 0.20)
	track.corner_radius_top_left = int(size.y * 0.5)
	track.corner_radius_top_right = int(size.y * 0.5)
	track.corner_radius_bottom_left = int(size.y * 0.5)
	track.corner_radius_bottom_right = int(size.y * 0.5)
	holder.add_theme_stylebox_override("panel", track)
	var ratio := 0.0 if total <= 0 else clampf(float(done) / float(total), 0.0, 1.0)
	var fill_panel := Panel.new()
	fill_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill_panel.offset_left = 0
	fill_panel.offset_top = 0
	fill_panel.offset_right = maxf(size.y, size.x * ratio)
	fill_panel.offset_bottom = 0
	fill_panel.visible = ratio > 0.0
	fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = orange
	fill_style.border_color = Color(1.0, 0.78, 0.34, 0.38)
	fill_style.border_width_top = 1
	fill_style.corner_radius_top_left = int(size.y * 0.5)
	fill_style.corner_radius_top_right = int(size.y * 0.5)
	fill_style.corner_radius_bottom_left = int(size.y * 0.5)
	fill_style.corner_radius_bottom_right = int(size.y * 0.5)
	fill_panel.add_theme_stylebox_override("panel", fill_style)
	holder.add_child(fill_panel)
	return holder


func _topic_color(topic: Dictionary) -> Color:
	var value := str(topic.get("color", "#D9933F"))
	return Color(value) if value.begins_with("#") else orange


func _topic_ui_palette(topic: Dictionary) -> Dictionary:
	var topic_color := _topic_color(topic)
	var defaults := {
		"surface": Color("#FFF4DE").lerp(topic_color, 0.14),
		"foreground": topic_color.darkened(0.62),
		"outline": topic_color.darkened(0.20),
		"accent": topic_color,
	}
	var raw = topic.get("ui_palette", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return defaults
	var palette: Dictionary = raw
	return {
		"surface": _topic_ui_color(palette, "surface", defaults.surface),
		"foreground": _topic_ui_color(palette, "foreground", defaults.foreground),
		"outline": _topic_ui_color(palette, "outline", defaults.outline),
		"accent": _topic_ui_color(palette, "accent", defaults.accent),
	}


func _topic_ui_color(palette: Dictionary, key: String, fallback: Color) -> Color:
	var value := str(palette.get(key, ""))
	return Color.from_string(value, fallback) if not value.is_empty() else fallback


func _topic_progress_bar(done: int, total: int, size: Vector2, fill_color: Color, track_color := Color(0.78, 0.64, 0.48, 0.22)) -> Panel:
	var holder := Panel.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = track_color
	var radius := int(size.y * 0.5)
	track.corner_radius_top_left = radius
	track.corner_radius_top_right = radius
	track.corner_radius_bottom_left = radius
	track.corner_radius_bottom_right = radius
	holder.add_theme_stylebox_override("panel", track)
	var ratio := 0.0 if total <= 0 else clampf(float(done) / float(total), 0.0, 1.0)
	var fill := Panel.new()
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_left = 0
	fill.offset_top = 0
	fill.offset_right = size.x * ratio
	fill.offset_bottom = 0
	fill.visible = ratio > 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = radius
	fill_style.corner_radius_top_right = radius
	fill_style.corner_radius_bottom_left = radius
	fill_style.corner_radius_bottom_right = radius
	fill.add_theme_stylebox_override("panel", fill_style)
	holder.add_child(fill)
	return holder


func _card_button(text: String, size: Vector2, action: Callable) -> Button:
	var card := Button.new()
	card.text = text
	card.custom_minimum_size = size
	card.icon = texture
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.add_theme_font_size_override("font_size", 24)
	card.add_theme_color_override("font_color", brown)
	card.add_theme_color_override("font_hover_color", deep_orange)
	card.add_theme_color_override("font_pressed_color", brown)
	_apply_card_style(card)
	card.pressed.connect(action)
	_wire_button_animation(card)
	return card


func _apply_card_style(card: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = paper
	normal.border_color = Color(0.73, 0.50, 0.28, 0.35)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.content_margin_left = 18
	normal.content_margin_top = 16
	normal.content_margin_right = 18
	normal.content_margin_bottom = 16
	card.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#FFF1DA")
	hover.border_color = orange
	card.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = soft_beige
	pressed.border_color = deep_orange
	card.add_theme_stylebox_override("pressed", pressed)


func _status_icon(mode: String, done: bool, size: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = _mode_icon_texture(mode, done)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _swap_mode_badge(done: bool, size: float) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(size, size)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#6f9d67") if done else Color("#d0cac0")
	style.border_color = Color("#5f8d55") if done else Color("#aaa49a")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "3x4"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", max(12, int(size * 0.28)))
	label.add_theme_color_override("font_color", Color.WHITE if done else Color("#756e65"))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _mode_icon_texture(mode: String, done: bool) -> Texture2D:
	var key := _mode_key(mode)
	if key == "polygon":
		return icon_mode_polygon_done if done else icon_mode_polygon_todo
	if key == "swap":
		return icon_mode_swap_done if done else icon_mode_swap_todo
	return icon_mode_knob_done if done else icon_mode_knob_todo


func _mode_label(mode: String) -> String:
	var key := _mode_key(mode)
	if key == "polygon":
		return _t("mode_polygon")
	if key == "swap":
		return _t("mode_swap")
	return _t("mode_knob")


func _summary_item(icon: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.texture = icon
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(30, 30)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _summary_text_item(mark: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_swap_mode_badge(true, 30))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _show_mode_dialog(level: Dictionary) -> void:
	current_level = level
	var available_modes := _available_modes_for_level(level)
	var preferred := _preferred_available_mode(level, available_modes)
	if not preferred.is_empty():
		progress_store.mark_last_played(current_topic, level, preferred)
	_show_modal()
	var box := _mode_modal_box(_mode_dialog_size(available_modes.size()))
	box.add_child(_mode_dialog_header())
	if available_modes.is_empty():
		box.add_child(_mode_empty_label())
		return
	for play_mode in available_modes:
		box.add_child(_mode_select_card(level, play_mode))


func _mode_dialog_size(mode_count: int) -> Vector2:
	var mode_rows: int = maxi(1, mode_count)
	var desired_height := 264.0 + float(mode_rows) * 192.0
	var available_height := get_viewport_rect().size.y - _screen_margin() * 2.0 - 40.0
	return Vector2(_mode_dialog_panel_width(), minf(1180.0, minf(desired_height, maxf(1.0, available_height))))


func _mode_dialog_panel_width() -> float:
	var available_width := get_viewport_rect().size.x - _screen_margin() * 2.0
	return minf(1000.0, maxf(1.0, available_width))


func _mode_dialog_horizontal_padding(panel_width: float = 0.0) -> float:
	var width := panel_width if panel_width > 0.0 else _mode_dialog_panel_width()
	if width < 520.0:
		return 24.0
	if width < 760.0:
		return 40.0
	return 56.0


func _mode_dialog_content_width() -> float:
	var panel_width := _mode_dialog_panel_width()
	return maxf(1.0, panel_width - _mode_dialog_horizontal_padding(panel_width) * 2.0)


func _mode_dialog_layout_scale() -> float:
	var width := _mode_dialog_content_width()
	if width >= 860.0:
		return 1.0
	return maxf(0.68, width / 860.0)


func _mode_empty_label() -> Label:
	var label := Label.new()
	label.text = _t("mode_empty")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", soft_brown)
	return label


func _mode_dialog_header() -> Control:
	var holder := Control.new()
	var content_width := _mode_dialog_content_width()
	holder.custom_minimum_size = Vector2(content_width, 132)
	holder.add_child(_mode_title_side_decoration(Vector2(content_width * 0.5 - 244.0, 28), true))
	holder.add_child(_mode_title_side_decoration(Vector2(content_width * 0.5 + 118.0, 28), false))
	var title := Label.new()
	title.text = "选择模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 78
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", brown)
	title.add_theme_color_override("font_shadow_color", Color(0.42, 0.20, 0.06, 0.12))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(title)
	var hint := Label.new()
	hint.text = "选择一个模式开始游戏"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 82
	hint.offset_bottom = 122
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", soft_brown)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hint)
	return holder


func _mode_title_side_decoration(position_value: Vector2, flipped: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = mode_title_side_decoration_texture
	rect.position = position_value
	rect.custom_minimum_size = Vector2(126, 44)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.flip_h = flipped
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _mode_header_mark(position: Vector2, text: String, color: Color, font_size: int) -> Label:
	var mark := Label.new()
	mark.text = text
	mark.position = position
	mark.custom_minimum_size = Vector2(32, 32)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", font_size)
	mark.add_theme_color_override("font_color", color)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark


func _mode_title_block(text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(432, 76)
	var banner := TextureRect.new()
	banner.texture = level_name_banner_texture
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -156
	banner.offset_top = -4
	banner.offset_right = 156
	banner.offset_bottom = 72
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(banner)
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0.42, 0.20, 0.06, 0.42))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -128
	title.offset_top = 8
	title.offset_right = 128
	title.offset_bottom = 58
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(title)
	return holder


func _decor_paw(position: Vector2, size: float, rotation_value: float) -> TextureRect:
	var paw := TextureRect.new()
	paw.texture = icon_cat_paw
	paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paw.custom_minimum_size = Vector2(size, size)
	paw.position = position
	paw.rotation = rotation_value
	paw.modulate = Color(0.72, 0.44, 0.20, 0.48)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return paw


func _mode_dialog_image(level: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(432, 148)
	var rect := TextureRect.new()
	rect.texture = repository.level_thumbnail(level)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.custom_minimum_size = Vector2(136, 136)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	return holder


func _mode_select_card(level: Dictionary, play_mode: String) -> Button:
	var done := progress_store.is_done(level["id"], play_mode)
	var has_saved_state := not done and not progress_store.play_state(current_topic, level, play_mode).is_empty()
	var layout_scale := _mode_dialog_layout_scale()
	var card_width := _mode_dialog_content_width()
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(card_width, 168.0 * layout_scale)
	var normal := _mode_select_style(play_mode, false)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", _mode_select_style(play_mode, true))
	card.add_theme_stylebox_override("pressed", _mode_select_style(play_mode, true))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 42.0 * layout_scale
	row.offset_top = 30.0 * layout_scale
	row.offset_right = -40.0 * layout_scale
	row.offset_bottom = -30.0 * layout_scale
	row.add_theme_constant_override("separation", int(32.0 * layout_scale))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_status_icon(play_mode, done, 92.0 * layout_scale))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", int(10.0 * layout_scale))
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)
	var name := Label.new()
	name.text = _mode_modal_name(play_mode)
	name.add_theme_font_size_override("font_size", maxi(24, int(34.0 * layout_scale)))
	name.add_theme_color_override("font_color", brown)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name)
	var state := Label.new()
	state.text = "%s · %s" % [_mode_modal_description(play_mode), _t("in_progress")] if has_saved_state else _mode_modal_description(play_mode)
	state.add_theme_font_size_override("font_size", maxi(18, int(22.0 * layout_scale)))
	state.add_theme_color_override("font_color", _mode_accent_color(play_mode).darkened(0.14) if done else soft_brown)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(state)
	var action: Callable = func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", maxi(6, int(8.0 * layout_scale)))
	row.add_child(actions)
	actions.add_child(_mode_action_button(
		_t("replay") if done else (_t("continue") if has_saved_state else _t("start_game")),
		play_mode,
		action,
		Vector2(maxf(118.0, 168.0 * layout_scale), maxf(48.0, 58.0 * layout_scale)),
		maxi(18, int(24.0 * layout_scale))
	))
	if has_saved_state:
		actions.add_child(_mode_secondary_action_button(
			_t("restart"),
			func() -> void: _show_mode_restart_confirm(level, play_mode),
			Vector2(maxf(118.0, 168.0 * layout_scale), maxf(36.0, 42.0 * layout_scale)),
			maxi(15, int(18.0 * layout_scale))
		))
	if done:
		card.add_child(_mode_corner_check_badge(_mode_accent_color(play_mode)))
	card.pressed.connect(func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	)
	_wire_button_animation(card)
	return card


func _animate_new_unlock_card(card: Control, topic: Dictionary, card_width: float) -> void:
	if _ui_motion_reduced():
		return
	var card_height := card_width * 4.0 / 3.0
	var topic_color := _topic_color(topic)
	var radius := int(card_width * 0.07)
	# Cover the fresh card with the locked look right away, then reveal it.
	var overlay := Control.new()
	overlay.name = "unlock_reveal_overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_level_card_back(overlay, topic, topic_color, card_width, card_height, radius)
	card.add_child(overlay)
	var back_image := await _render_card_back_snapshot(topic, topic_color, card_width, card_height, radius)
	if not is_instance_valid(card) or not card.is_inside_tree() or not is_instance_valid(overlay):
		return
	if back_image == null or back_image.is_empty():
		_animate_unlock_flip_fallback(card, overlay)
		return
	if unlock_effect_style == "shatter":
		_animate_unlock_shatter(card, overlay, back_image, card_width, card_height)
	else:
		_animate_unlock_burn(card, overlay, back_image, card_width, card_height)


func _animate_unlock_burn(card: Control, overlay: Control, back_image: Image, card_width: float, card_height: float) -> void:
	for child in overlay.get_children():
		child.queue_free()
	var burn := TextureRect.new()
	burn.texture = ImageTexture.create_from_image(back_image)
	burn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burn.stretch_mode = TextureRect.STRETCH_SCALE
	burn.set_anchors_preset(Control.PRESET_FULL_RECT)
	burn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _unlock_burn_shader_resource()
	material.set_shader_parameter("noise_tex", _unlock_burn_noise_texture())
	material.set_shader_parameter("aspect", card_width / maxf(1.0, card_height))
	var seeds := _unlock_burn_seed_points()
	material.set_shader_parameter("seed_points", seeds)
	material.set_shader_parameter("field_max", _unlock_burn_field_max(seeds, card_width / maxf(1.0, card_height)))
	material.set_shader_parameter("progress", 0.0)
	burn.material = material
	overlay.add_child(burn)
	var tween := card.create_tween()
	tween.tween_interval(0.55)
	tween.tween_method(
		func(value: float) -> void: material.set_shader_parameter("progress", value),
		0.0, 1.0, 3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(overlay.queue_free)


func _animate_unlock_shatter(card: Control, overlay: Control, back_image: Image, card_width: float, card_height: float) -> void:
	# Glass break in two hits: first the cracks appear, then the shards fly out.
	for child in overlay.get_children():
		child.queue_free()
	var texture := ImageTexture.create_from_image(back_image)
	var intact := TextureRect.new()
	intact.texture = texture
	intact.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intact.stretch_mode = TextureRect.STRETCH_SCALE
	intact.set_anchors_preset(Control.PRESET_FULL_RECT)
	intact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(intact)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var impact := Vector2(card_width * rng.randf_range(0.36, 0.64), card_height * rng.randf_range(0.34, 0.62))
	var geometry := _unlock_crack_geometry(impact, card_width, card_height, rng)
	var tween := card.create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(func() -> void: _unlock_crack_stage(overlay, geometry))
	tween.tween_interval(0.7)
	tween.tween_callback(func() -> void:
		if is_instance_valid(intact):
			intact.queue_free()
		_unlock_shatter_stage(overlay, geometry, texture, impact, card_width, rng)
	)
	tween.tween_interval(1.0)
	tween.tween_callback(overlay.queue_free)


func _unlock_crack_geometry(impact: Vector2, card_width: float, card_height: float, rng: RandomNumberGenerator) -> Dictionary:
	# Radial cracks from the impact point plus two irregular concentric rings;
	# shards are the cells this pattern cuts out of the card rectangle.
	var rect_points := PackedVector2Array([
		Vector2.ZERO, Vector2(card_width, 0.0), Vector2(card_width, card_height), Vector2(0.0, card_height)
	])
	var far := (card_width + card_height) * 4.0
	var ray_count := rng.randi_range(7, 9)
	var angles: Array[float] = []
	for i in range(ray_count):
		angles.append(TAU * (float(i) + rng.randf_range(-0.28, 0.28)) / float(ray_count))
	var dirs: Array[Vector2] = []
	var ring1 := PackedVector2Array()
	var ring2 := PackedVector2Array()
	var rays: Array[PackedVector2Array] = []
	for i in range(ray_count):
		var dir := Vector2.from_angle(angles[i])
		dirs.append(dir)
		var exit_distance := _rect_ray_exit_distance(impact, dir, card_width, card_height)
		var r1 := impact + dir * exit_distance * 0.32 * rng.randf_range(0.8, 1.2)
		var r2 := impact + dir * exit_distance * 0.64 * rng.randf_range(0.85, 1.15)
		ring1.append(r1)
		ring2.append(r2)
		rays.append(PackedVector2Array([impact, r1, r2, impact + dir * exit_distance]))
	var shards: Array[PackedVector2Array] = []
	var min_area := card_width * card_height * 0.0008
	for i in range(ray_count):
		var j := (i + 1) % ray_count
		var angle_next := angles[j] + (TAU if j == 0 else 0.0)
		var mid := Vector2.from_angle((angles[i] + angle_next) * 0.5)
		var wedge := PackedVector2Array([impact, impact + dirs[i] * far, impact + mid * far, impact + dirs[j] * far])
		for wedge_part in Geometry2D.intersect_polygons(wedge, rect_points):
			for poly in Geometry2D.intersect_polygons(wedge_part, ring1):
				if _polygon_points_area(poly) >= min_area:
					shards.append(poly)
			for band in Geometry2D.clip_polygons(ring2, ring1):
				for poly in Geometry2D.intersect_polygons(wedge_part, band):
					if _polygon_points_area(poly) >= min_area:
						shards.append(poly)
			for poly in Geometry2D.clip_polygons(wedge_part, ring2):
				if _polygon_points_area(poly) >= min_area:
					shards.append(poly)
	return {"rays": rays, "rings": [ring1, ring2], "shards": shards}


func _rect_ray_exit_distance(origin: Vector2, dir: Vector2, width: float, height: float) -> float:
	var best := width + height
	if absf(dir.x) > 0.0001:
		var tx := ((width if dir.x > 0.0 else 0.0) - origin.x) / dir.x
		if tx > 0.0:
			best = minf(best, tx)
	if absf(dir.y) > 0.0001:
		var ty := ((height if dir.y > 0.0 else 0.0) - origin.y) / dir.y
		if ty > 0.0:
			best = minf(best, ty)
	return best


func _polygon_points_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area * 0.5)


func _unlock_crack_stage(overlay: Control, geometry: Dictionary) -> void:
	if not is_instance_valid(overlay):
		return
	var cracks := Node2D.new()
	cracks.name = "crack_lines"
	overlay.add_child(cracks)
	for ray in geometry["rays"]:
		_add_crack_line(cracks, ray, false)
	for ring in geometry["rings"]:
		_add_crack_line(cracks, ring, true)
	cracks.modulate.a = 0.0
	var fade := cracks.create_tween()
	fade.tween_property(cracks, "modulate:a", 1.0, 0.07)
	var shake := overlay.create_tween()
	shake.tween_property(overlay, "position", Vector2(3.0, -2.0), 0.03).as_relative()
	shake.tween_property(overlay, "position", Vector2(-5.0, 3.0), 0.05).as_relative()
	shake.tween_property(overlay, "position", Vector2(2.0, -1.0), 0.04).as_relative()


func _add_crack_line(parent: Node2D, points: PackedVector2Array, closed: bool) -> void:
	var glow := Line2D.new()
	glow.points = points
	glow.closed = closed
	glow.width = 5.0
	glow.default_color = Color(1.0, 1.0, 1.0, 0.22)
	parent.add_child(glow)
	var line := Line2D.new()
	line.points = points
	line.closed = closed
	line.width = 2.0
	line.default_color = Color(1.0, 1.0, 1.0, 0.85)
	parent.add_child(line)


func _unlock_shatter_stage(overlay: Control, geometry: Dictionary, texture: Texture2D, impact: Vector2, card_width: float, rng: RandomNumberGenerator) -> void:
	if not is_instance_valid(overlay):
		return
	var cracks := overlay.get_node_or_null("crack_lines")
	if cracks != null:
		cracks.queue_free()
	var jolt := overlay.create_tween()
	jolt.tween_property(overlay, "position", Vector2(-4.0, 3.0), 0.03).as_relative()
	jolt.tween_property(overlay, "position", Vector2(4.0, -3.0), 0.05).as_relative()
	for shard_points in geometry["shards"]:
		var centroid := Vector2.ZERO
		for point in shard_points:
			centroid += point
		centroid /= float(shard_points.size())
		var local := PackedVector2Array()
		for point in shard_points:
			local.append(point - centroid)
		var shard := Polygon2D.new()
		shard.polygon = local
		shard.uv = shard_points
		shard.texture = texture
		shard.position = centroid
		overlay.add_child(shard)
		var direction := centroid - impact
		direction = direction.normalized() if direction.length() > 0.001 else Vector2.from_angle(rng.randf_range(0.0, TAU))
		direction = (direction + Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))).normalized()
		var fly_distance := card_width * rng.randf_range(0.45, 0.95)
		var duration := rng.randf_range(0.55, 0.85)
		var target := centroid + direction * fly_distance + Vector2(0.0, card_width * 0.18)
		var tween := shard.create_tween().set_parallel(true)
		tween.tween_property(shard, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation", rng.randf_range(-1.6, 1.6), duration)
		tween.tween_property(shard, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)


func _render_card_back_snapshot(topic: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(maxi(2, int(card_width)), maxi(2, int(card_height)))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var holder := Control.new()
	holder.size = Vector2(card_width, card_height)
	viewport.add_child(holder)
	_add_level_card_back(holder, topic, topic_color, card_width, card_height, radius)
	add_child(viewport)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return null
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _unlock_burn_seed_points() -> PackedVector2Array:
	# 3-4 ignition points scattered anywhere on the card, kept just far enough
	# apart that the fire does not start as a single blob. The shader always
	# reads 4 points, so "3 points" pads with a near-duplicate.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := rng.randi_range(3, 4)
	var seeds := PackedVector2Array()
	for attempt in range(64):
		if seeds.size() >= count:
			break
		var candidate := Vector2(rng.randf_range(0.06, 0.94), rng.randf_range(0.06, 0.94))
		var separated := true
		for seed in seeds:
			if candidate.distance_to(seed) < 0.30:
				separated = false
				break
		if separated:
			seeds.append(candidate)
	if seeds.is_empty():
		seeds.append(Vector2(0.5, 0.5))
	while seeds.size() < 4:
		var base: Vector2 = seeds[rng.randi_range(0, seeds.size() - 1)]
		seeds.append(base + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)))
	return seeds


func _unlock_burn_field_max(seeds: PackedVector2Array, aspect: float) -> float:
	# Largest distance-field value on the card, so the tween's progress range
	# maps exactly onto the visible burn (mirrors the shader's field math).
	var max_distance := 0.0
	for gy in range(7):
		for gx in range(7):
			var point := Vector2(aspect * float(gx) / 6.0, float(gy) / 6.0)
			var nearest := 1e9
			for seed in seeds:
				nearest = minf(nearest, point.distance_to(Vector2(seed.x * aspect, seed.y)))
			max_distance = maxf(max_distance, nearest)
	return max_distance / 1.55 + 0.09


func _unlock_burn_shader_resource() -> Shader:
	if unlock_burn_shader == null:
		unlock_burn_shader = Shader.new()
		unlock_burn_shader.code = UNLOCK_BURN_SHADER_CODE
	return unlock_burn_shader


func _unlock_burn_noise_texture() -> Texture2D:
	if unlock_burn_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_octaves = 2
		unlock_burn_noise = ImageTexture.create_from_image(noise.get_seamless_image(192, 192))
	return unlock_burn_noise


func _animate_unlock_flip_fallback(card: Control, overlay: Control) -> void:
	card.pivot_offset = card.size * 0.5
	overlay.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(overlay, "scale:x", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(overlay.queue_free)
	tween.tween_property(card, "scale:x", 1.0, 0.26).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _mode_secondary_action_button(text: String, action: Callable, min_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", soft_brown)
	button.add_theme_color_override("font_hover_color", deep_orange)
	button.add_theme_color_override("font_pressed_color", deep_orange)
	button.add_theme_color_override("font_disabled_color", Color(soft_brown, 0.34))
	var normal := _rounded_panel_style(Color(1.0, 1.0, 1.0, 0.34), int(min_size.y * 0.42))
	normal.border_color = Color(soft_brown, 0.40)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.95, 0.84, 0.72)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _show_mode_restart_confirm(level: Dictionary, play_mode: String) -> void:
	_show_modal()
	var box := _modal_box(Vector2(360, 230))
	box.add_child(_modal_title(_t("confirm_restart")))
	box.add_child(_button(_t("confirm"), func() -> void:
		progress_store.clear_play_state(current_topic, level, play_mode)
		_close_modal()
		_show_game(current_topic, level, play_mode, true)
	))
	box.add_child(_button(_t("back"), func() -> void: _show_mode_dialog(level), false))


func _mode_select_style(play_mode: String, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF9EC") if not hover else Color("#FFF2D8")
	if _mode_key(play_mode) == "swap":
		style.bg_color = Color("#FFF5E9") if not hover else Color("#FFEBD8")
	style.border_color = _mode_accent_color(play_mode).lightened(0.08)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_color = Color(0.42, 0.24, 0.07, 0.12)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style


func _mode_modal_name(play_mode: String) -> String:
	var key := _mode_key(play_mode)
	if key == "polygon":
		return "多边形模式"
	if key == "swap":
		return "交换模式"
	return "经典凹凸模式"


func _mode_modal_description(play_mode: String) -> String:
	var key := _mode_key(play_mode)
	if key == "polygon":
		return "自由拼片边缘"
	if key == "swap":
		return "移动交换还原"
	return "经典拼图体验"


func _refresh_mode_checks(checks: Dictionary, selected_mode: String) -> void:
	for mode in checks.keys():
		var check: Label = checks[mode]
		if is_instance_valid(check):
			check.text = "✓" if str(mode) == selected_mode else "○"


func _mode_choice_card(level: Dictionary, play_mode: String) -> Panel:
	var done := progress_store.is_done(level["id"], play_mode)
	var accent := _mode_accent_color(play_mode)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(472, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.985, 0.93, 0.96)
	style.border_color = Color(0.78, 0.52, 0.28, 0.28)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.42, 0.25, 0.08, 0.10)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_top = 16
	row.offset_right = -22
	row.offset_bottom = -16
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_status_icon(play_mode, done, 66))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)
	var name := Label.new()
	name.text = _mode_label(play_mode)
	name.add_theme_font_size_override("font_size", 25)
	name.add_theme_color_override("font_color", brown)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name)
	var status := Label.new()
	status.text = _t("done") if done else _t("todo")
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("#6f9d67") if done else orange)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(status)
	row.add_child(_mode_action_button(_t("replay") if done else _t("start_game"), play_mode, func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	))
	if done:
		card.add_child(_complete_check_badge())
	return card


func _mode_action_button(text: String, _play_mode: String, action: Callable, min_size: Vector2 = Vector2(140, 50), font_size: int = 22) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var is_replay := text == _t("replay")
	var accent := green if is_replay else orange
	var accent_pressed := accent.darkened(0.10)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent_pressed
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.shadow_color = Color(0.42, 0.25, 0.08, 0.12)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.06)
	hover.border_color = accent_pressed
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = accent_pressed
	pressed.border_color = accent_pressed
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(action)
	_wire_button_animation(button)
	return button


func _mode_corner_check_badge(accent: Color) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(48, 48)
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = -2
	badge.offset_top = -2
	badge.offset_right = 46
	badge.offset_bottom = 46
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 22
	style.corner_radius_bottom_right = 18
	badge.add_theme_stylebox_override("panel", style)
	var check := Label.new()
	check.text = "✓"
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_theme_font_size_override("font_size", 32)
	check.add_theme_color_override("font_color", Color.WHITE)
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	check.offset_left = -3
	check.offset_top = -4
	check.offset_right = -4
	check.offset_bottom = -4
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(check)
	return badge


func _complete_check_badge() -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(42, 42)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -52
	badge.offset_top = -12
	badge.offset_right = -10
	badge.offset_bottom = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#6f9d67")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	badge.add_theme_stylebox_override("panel", style)
	var check := Label.new()
	check.text = "✓"
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.add_theme_font_size_override("font_size", 30)
	check.add_theme_color_override("font_color", Color.WHITE)
	check.set_anchors_preset(Control.PRESET_FULL_RECT)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(check)
	return badge


func _mode_accent_color(mode: String) -> Color:
	var key := _mode_key(mode)
	if key == "polygon":
		return Color("#6f9d67")
	if key == "swap":
		return Color("#F0874D")
	return Color("#A38DBE")


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String, discard_current_state := false) -> void:
	if not discard_current_state:
		_persist_current_puzzle_state()
	current_screen = "game"
	current_topic = topic
	current_level = level
	active_level_config = repository.load_level_config(current_level)
	var available_modes := _available_modes_for_config(active_level_config)
	current_mode = _mode_key(play_mode)
	if not available_modes.has(current_mode):
		current_mode = available_modes[0] if not available_modes.is_empty() else ""
	if current_mode.is_empty():
		_show_levels(topic, str(level.get("id", "")))
		return
	progress_store.mark_last_played(topic, level, current_mode)
	var restore_state := progress_store.play_state(topic, level, current_mode)
	_apply_level_media(active_level_config)
	_clear_ui()
	_clear_board()
	var random_rotation := progress_store.random_rotation_enabled() and current_mode != "swap"
	var loaded: bool = puzzle_board.start(active_level_config, current_mode, texture, source_image, source_size, _icon_button_size(), random_rotation, restore_state)
	_build_game_hud(_level_display_title(level))
	if not loaded:
		status_label.text = _t("status_missing_mode")
	elif not progress_store.tutorial_seen(current_mode):
		_show_tutorial_modal()


func _set_game_status(text: String) -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = text
		status_label.visible = not text.is_empty()


func _set_zoom_label(percent: int) -> void:
	if zoom_label != null and is_instance_valid(zoom_label):
		zoom_label.text = "%d%%" % percent


func _on_puzzle_completed() -> void:
	var locks_before := _compute_level_locks(current_topic)
	progress_store.mark_completed(current_level["id"], current_mode)
	var locks_after := _compute_level_locks(current_topic)
	for level in current_topic.get("levels", []):
		var level_id := str(level.get("id", ""))
		if not bool(locks_before.get(level_id, false)) and bool(locks_after.get(level_id, false)):
			newly_unlocked_topic_id = str(current_topic.get("id", ""))
			newly_unlocked_level_id = level_id
			break
	progress_store.clear_play_state(current_topic, current_level, current_mode)
	_show_complete_modal()


func _on_puzzle_state_changed(state: Dictionary) -> void:
	if current_screen != "game" or current_topic.is_empty() or current_level.is_empty() or current_mode.is_empty():
		return
	progress_store.save_play_state(current_topic, current_level, current_mode, state)


func _build_game_hud(level_title: String) -> void:
	var bar_height := _game_top_bar_height()
	var hint_button_size := _game_hint_button_size()
	var hint_icon_inset := UI_ICON_INSET * GAME_HINT_BUTTON_SCALE
	var top_bar := Control.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 0
	top_bar.offset_bottom = bar_height
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(top_bar)
	var back_button := _icon_button(icon_left_arrow, _return_to_current_level_list, _t("back"), hint_button_size, hint_icon_inset, false, true, brown, deep_orange)
	back_button.position = Vector2(10, (bar_height - hint_button_size) * 0.5)
	top_bar.add_child(back_button)
	var title := Label.new()
	title.text = level_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = hint_button_size + 22.0
	title.offset_top = (bar_height - hint_button_size) * 0.5
	title.offset_right = -(hint_button_size + 22.0)
	title.offset_bottom = title.offset_top + hint_button_size
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", brown)
	title.add_theme_color_override("font_shadow_color", Color(0.42, 0.20, 0.06, 0.12))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(title)
	var top_actions := HBoxContainer.new()
	top_actions.alignment = BoxContainer.ALIGNMENT_END
	top_actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_actions.offset_left = -_game_top_actions_width()
	top_actions.offset_top = (bar_height - hint_button_size) * 0.5
	top_actions.offset_right = -10
	top_actions.offset_bottom = top_actions.offset_top + hint_button_size
	top_actions.add_theme_constant_override("separation", 6)
	top_bar.add_child(top_actions)
	swap_undo_button = null
	if current_mode == "swap":
		swap_undo_button = _tool_text_button(_t("undo"), puzzle_board.undo_last_swap, _t("undo"))
		swap_undo_button.disabled = not puzzle_board.can_undo_swap()
		top_actions.add_child(swap_undo_button)
	var hint_button := _icon_button(icon_lightbulb, puzzle_board.show_hint, _t("hint"), hint_button_size, hint_icon_inset)
	top_actions.add_child(hint_button)
	zoom_label = null
	status_label = Label.new()
	status_label.text = ""
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", brown)
	screen_root.add_child(status_label)
	_layout_game_status_label()
	hud_blocker_controls.clear()
	hud_blocker_controls.append(back_button)
	if swap_undo_button != null:
		hud_blocker_controls.append(swap_undo_button)
	hud_blocker_controls.append(hint_button)
	hud_blocker_controls.append(status_label)
	_queue_game_drag_blocker_refresh()
	_animate_screen_in(screen_root)


func _hud_top_icons_width() -> float:
	return _game_top_actions_width()


func _game_top_bar_height() -> float:
	return _game_hint_button_size() + 22.0


func _game_top_actions_width() -> float:
	var width := _game_hint_button_size() + 20.0
	if current_mode == "swap":
		width += _hud_text_button_width(_t("undo")) + 12.0
	return width


func _set_swap_undo_available(available: bool) -> void:
	if swap_undo_button != null and is_instance_valid(swap_undo_button):
		swap_undo_button.disabled = not available


func _hud_title_size(text: String) -> Vector2:
	return Vector2(maxf(48.0, float(text.length()) * 24.0 * 0.9), _icon_button_size())


func _hud_button_separation() -> float:
	return 3.0 if get_viewport_rect().size.x < 430.0 else 4.0


func _icon_button_size() -> float:
	return UI_ICON_BUTTON_SIZE


func _game_hint_button_size() -> float:
	return _icon_button_size() * GAME_HINT_BUTTON_SCALE


func _layout_game_status_label() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var viewport_width := get_viewport_rect().size.x
	var margin := 18.0
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_left = margin
	status_label.offset_top = _game_top_bar_height()
	status_label.offset_right = -margin
	status_label.offset_bottom = _game_top_bar_height() + 34.0
	status_label.custom_minimum_size = Vector2(maxf(0.0, viewport_width - margin * 2.0), 34.0)


func _texture_size(icon: Texture2D) -> Vector2:
	if icon == null:
		return Vector2(48, 48)
	var size := icon.get_size()
	return Vector2(maxf(1.0, size.x), maxf(1.0, size.y))


func _hud_text_button_width(text: String) -> float:
	return maxf(20.0, float(text.length()) * HUD_TEXT_BUTTON_FONT_SIZE * 0.9)


func _hud_text_button_height() -> float:
	return float(HUD_TEXT_BUTTON_FONT_SIZE) + 8.0


func _mode_key(play_mode: String) -> String:
	return "knob" if play_mode == "classic" else play_mode


func _available_modes_for_level(level: Dictionary) -> Array[String]:
	var level_config := repository.load_level_config(level)
	return _available_modes_for_config(level_config)


func _available_modes_for_config(level_config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for play_mode in PLAY_MODES:
		if _level_has_mode_data(level_config, play_mode):
			result.append(play_mode)
	return result


func _level_has_mode_data(level_config: Dictionary, play_mode: String) -> bool:
	var mode := _mode_key(play_mode)
	if mode == "swap":
		return not repository.level_image_path(level_config).is_empty()
	if mode == "knob":
		var knob_config := repository.mode_config(level_config, play_mode)
		return not knob_config.is_empty() and not repository.level_image_path(level_config).is_empty()
	var mode_data := repository.mode_config(level_config, play_mode)
	if mode_data.is_empty():
		return false
	var pieces = mode_data.get("pieces", [])
	return typeof(pieces) == TYPE_ARRAY and not pieces.is_empty()


func _preferred_available_mode(level: Dictionary, available_modes: Array[String]) -> String:
	if available_modes.is_empty():
		return ""
	var preferred := _mode_key(progress_store.preferred_mode(level))
	if available_modes.has(preferred):
		return preferred
	return available_modes[0]


func _topic_available_mode_total(topic: Dictionary) -> int:
	var total := 0
	for level in topic.get("levels", []):
		total += _available_modes_for_level(level).size()
	return total


func _topic_available_done_count(topic: Dictionary) -> int:
	var done := 0
	for level in topic.get("levels", []):
		for play_mode in _available_modes_for_level(level):
			if progress_store.is_done(level["id"], play_mode):
				done += 1
	return done


func _topic_mode_total(topic: Dictionary, play_mode: String) -> int:
	var total := 0
	for level in topic.get("levels", []):
		if _available_modes_for_level(level).has(_mode_key(play_mode)):
			total += 1
	return total


func _topic_mode_done_count(topic: Dictionary, play_mode: String) -> int:
	var done := 0
	var key := _mode_key(play_mode)
	for level in topic.get("levels", []):
		if _available_modes_for_level(level).has(key) and progress_store.is_done(level["id"], key):
			done += 1
	return done


func _game_bottom_reserved_height() -> float:
	return BoardLayoutScript.game_bottom_reserved_height(_icon_button_size())


func _queue_game_drag_blocker_refresh() -> void:
	_layout_game_status_label()
	call_deferred("_refresh_game_drag_blockers")


func _refresh_game_drag_blockers() -> void:
	if current_screen != "game" or puzzle_board == null:
		return
	var blockers: Array[Rect2] = []
	for control in hud_blocker_controls:
		if not is_instance_valid(control) or not control.visible:
			continue
		var rect := Rect2(control.global_position, control.size).grow(HUD_BLOCKER_PADDING)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			blockers.append(rect)
	puzzle_board.set_drag_blockers(blockers)


func _apply_level_media(level_config: Dictionary) -> void:
	var media := repository.apply_level_media(level_config)
	texture = media["texture"]
	source_image = media["image"]
	source_size = media["source_size"]


func _return_to_current_level_list() -> void:
	if current_topic.is_empty():
		_show_topics()
		return
	_show_levels(current_topic, str(current_level.get("id", "")))


func _show_pause_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(360, 360))
	box.add_child(_modal_title(_t("pause")))
	box.add_child(_button(_t("resume"), _close_modal))
	box.add_child(_button(_t("restart"), _show_restart_confirm, false))
	box.add_child(_button(_t("return_levels"), func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, false))
	box.add_child(_button(_t("return_topics"), func() -> void:
		_close_modal()
		_show_topics()
	, false))


func _show_restart_confirm() -> void:
	_show_modal()
	var box := _modal_box(Vector2(360, 230))
	box.add_child(_modal_title(_t("confirm_restart")))
	box.add_child(_button(_t("confirm"), func() -> void:
		progress_store.clear_play_state(current_topic, current_level, current_mode)
		_close_modal()
		_show_game(current_topic, current_level, current_mode, true)
	))
	box.add_child(_button(_t("back"), _show_pause_modal, false))


func _show_settings_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(520, 520))
	var panel := box.get_parent() as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	panel_style.content_margin_left = 40
	panel_style.content_margin_top = 34
	panel_style.content_margin_right = 40
	panel_style.content_margin_bottom = 34
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.add_child(_modal_title(_t("settings_title")))
	var haptics_check := CheckBox.new()
	haptics_check.text = _t("haptics")
	haptics_check.button_pressed = progress_store.haptics_enabled()
	_style_settings_checkbox(haptics_check, 24)
	haptics_check.toggled.connect(func(enabled: bool) -> void:
		progress_store.set_haptics_enabled(enabled)
		puzzle_board.set_feedback_preferences(enabled, progress_store.reduced_motion_enabled(), progress_store.edge_contrast_mode())
	)
	box.add_child(haptics_check)
	var motion_check := CheckBox.new()
	motion_check.text = _t("reduce_motion")
	motion_check.button_pressed = progress_store.reduced_motion_enabled()
	_style_settings_checkbox(motion_check, 24)
	motion_check.toggled.connect(func(enabled: bool) -> void:
		progress_store.set_reduced_motion_enabled(enabled)
		puzzle_board.set_feedback_preferences(progress_store.haptics_enabled(), enabled, progress_store.edge_contrast_mode())
	)
	box.add_child(motion_check)
	var edge_row := HBoxContainer.new()
	edge_row.add_theme_constant_override("separation", 12)
	var edge_label := Label.new()
	edge_label.text = _t("piece_edges")
	edge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	edge_label.add_theme_font_size_override("font_size", 22)
	edge_label.add_theme_color_override("font_color", brown)
	edge_row.add_child(edge_label)
	var edge_select := OptionButton.new()
	edge_select.custom_minimum_size = Vector2(150, 52)
	edge_select.add_theme_font_size_override("font_size", 20)
	var edge_modes := ["auto", "dark", "light"]
	for mode in edge_modes:
		edge_select.add_item(_t("edge_%s" % mode))
	edge_select.select(maxi(0, edge_modes.find(progress_store.edge_contrast_mode())))
	edge_select.item_selected.connect(func(index: int) -> void:
		var mode := str(edge_modes[clampi(index, 0, edge_modes.size() - 1)])
		progress_store.set_edge_contrast_mode(mode)
		puzzle_board.set_feedback_preferences(progress_store.haptics_enabled(), progress_store.reduced_motion_enabled(), mode)
	)
	edge_row.add_child(edge_select)
	box.add_child(edge_row)
	var rotation_check := CheckBox.new()
	rotation_check.text = _t("random_rotation")
	rotation_check.button_pressed = progress_store.random_rotation_enabled()
	_style_settings_checkbox(rotation_check, 22)
	rotation_check.toggled.connect(func(enabled: bool) -> void:
		progress_store.set_random_rotation_enabled(enabled)
		if current_screen == "game":
			_set_game_status(_t("random_rotation_next"))
	)
	box.add_child(rotation_check)
	var close_button := _button(_t("close"), _close_modal, true, Vector2(420, 64))
	close_button.add_theme_font_size_override("font_size", 22)
	box.add_child(close_button)


func _style_settings_checkbox(check: CheckBox, font_size: int) -> void:
	check.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(color_name, brown)


func _show_tutorial_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(420, 290))
	box.add_child(_modal_title(_t("tutorial_title")))
	var text := Label.new()
	if current_mode == "swap":
		text.text = _t("tutorial_swap")
	elif progress_store.random_rotation_enabled():
		text.text = _t("tutorial_rotate")
	else:
		text.text = _t("tutorial_drag")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", brown)
	box.add_child(text)
	box.add_child(_button(_t("got_it"), func() -> void:
		progress_store.mark_tutorial_seen(current_mode)
		_close_modal()
	))


func _show_complete_modal() -> void:
	_show_modal(Color(0.16, 0.11, 0.08, 0.78), true)
	var viewport_size := get_viewport_rect().size
	var description := _level_description(current_level)
	var content_width := minf(viewport_size.x * 0.82, 860.0)
	var image_height := content_width * 4.0 / 3.0
	var max_image_height := viewport_size.y * (0.46 if not description.is_empty() else 0.56)
	if image_height > max_image_height:
		image_height = max_image_height
		content_width = image_height * 0.75
	content_width = maxf(280.0, content_width)
	image_height = content_width * 4.0 / 3.0
	var button_size := Vector2(minf(360.0, content_width * 0.62), 72.0)
	var description_height := 0.0 if description.is_empty() else 150.0
	var total_height := 94.0 + image_height + 52.0 + description_height + button_size.y + 48.0
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(content_width, total_height)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -content_width * 0.5
	box.offset_top = -total_height * 0.5
	box.offset_right = content_width * 0.5
	box.offset_bottom = total_height * 0.5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.z_index = 8
	modal_root.add_child(box)
	box.add_child(_complete_simple_title(content_width))
	box.add_child(_complete_full_image(Vector2(content_width, image_height)))
	var level_name := Label.new()
	level_name.text = _level_display_title(current_level)
	level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_name.add_theme_font_size_override("font_size", 34)
	level_name.add_theme_color_override("font_color", Color.WHITE)
	level_name.add_theme_color_override("font_shadow_color", Color(0.22, 0.12, 0.05, 0.42))
	level_name.add_theme_constant_override("shadow_offset_y", 3)
	level_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(level_name)
	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = content_width
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 22)
		desc.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 0.94))
		desc.add_theme_color_override("font_shadow_color", Color(0.22, 0.12, 0.05, 0.36))
		desc.add_theme_constant_override("shadow_offset_y", 2)
		desc.add_theme_constant_override("line_spacing", 6)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(desc)
	var button_holder := CenterContainer.new()
	button_holder.custom_minimum_size = Vector2(content_width, button_size.y)
	var confirm := _button(_t("confirm"), func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, true, button_size)
	confirm.add_theme_font_size_override("font_size", 26)
	button_holder.add_child(confirm)
	box.add_child(button_holder)
	_animate_modal_panel(box)
	_start_complete_confetti()


func _level_description(level: Dictionary) -> String:
	var description := str(level.get("description", "")).strip_edges()
	if not description.is_empty():
		return description
	var level_config := repository.load_level_config(level)
	return str(level_config.get("description", "")).strip_edges()


func _complete_simple_title(content_width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(content_width, 78)
	var label := Label.new()
	label.text = _t("complete")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.28, 0.13, 0.03, 0.46))
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return holder


func _complete_full_image(size: Vector2) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	var level_config := repository.load_level_config(current_level)
	var image_path := repository.level_image_path(level_config)
	var target_size := Vector2i(maxi(1, int(round(size.x))), maxi(1, int(round(size.y))))
	image.texture = _rounded_complete_image_texture(image_path, target_size, 28)
	if image.texture == null:
		image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(image)
	return holder


func _complete_heading() -> Control:
	var holder := HBoxContainer.new()
	holder.custom_minimum_size.y = 54
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 10)
	var left := _olive_branch(true)
	holder.add_child(left)
	var label := Label.new()
	label.text = _t("complete")
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	holder.add_child(_olive_branch(false))
	return holder


func _olive_branch(mirrored: bool) -> TextureRect:
	var branch := TextureRect.new()
	branch.texture = olive_branch_texture
	branch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	branch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	branch.custom_minimum_size = Vector2(52, 44)
	branch.flip_h = mirrored
	branch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return branch


func _complete_mode_badge() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(_status_icon(current_mode, true, 30))
	var label := Label.new()
	label.text = _t("completed_mode") % _mode_label(current_mode)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", soft_brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row


func _complete_actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var next := _next_level_target()
	if not next.is_empty():
		row.add_child(_button(_t("next"), _play_next_level, true, Vector2(132, 50)))
	if _has_unfinished_alternate_mode():
		row.add_child(_button(_t("switch_mode"), func() -> void:
			_close_modal()
			_show_game(current_topic, current_level, _next_mode_key(current_mode))
		, false, Vector2(132, 50)))
	row.add_child(_button(_t("return_levels"), func() -> void:
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
	, false, Vector2(150, 50)))
	return row


func _has_unfinished_alternate_mode() -> bool:
	for play_mode in _available_modes_for_level(current_level):
		if _mode_key(play_mode) != current_mode and not progress_store.is_done(current_level["id"], play_mode):
			return true
	return false


func _next_mode_key(mode: String) -> String:
	var modes := _available_modes_for_level(current_level)
	if modes.is_empty():
		return _mode_key(mode)
	var key := _mode_key(mode)
	var index := modes.find(key)
	if index < 0:
		return modes[0]
	return modes[(index + 1) % modes.size()]


func _add_complete_paw_marks(panel: Control) -> void:
	var marks := [
		{ "pos": Vector2(34, 110), "size": 34.0, "rot": -0.25, "alpha": 0.16 },
		{ "pos": Vector2(492, 112), "size": 30.0, "rot": 0.22, "alpha": 0.14 },
		{ "pos": Vector2(62, 480), "size": 28.0, "rot": 0.18, "alpha": 0.12 },
		{ "pos": Vector2(462, 448), "size": 36.0, "rot": -0.16, "alpha": 0.12 },
	]
	for item in marks:
		var paw := TextureRect.new()
		paw.texture = icon_cat_paw
		paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paw.custom_minimum_size = Vector2(item["size"], item["size"])
		paw.position = item["pos"]
		paw.rotation = item["rot"]
		paw.modulate = Color(0.82, 0.50, 0.22, item["alpha"])
		paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(paw)


func _play_next_level() -> void:
	var target := _next_level_target()
	if target.is_empty():
		_close_modal()
		_show_levels(current_topic, str(current_level.get("id", "")))
		return
	_close_modal()
	_show_game(target["topic"], target["level"], target["mode"])


func _next_level_target() -> Dictionary:
	var seen_current := false
	for topic in topics:
		for level in topic.get("levels", []):
			if seen_current:
				var modes := _available_modes_for_level(level)
				if not modes.is_empty():
					var next_mode := current_mode if modes.has(current_mode) else modes[0]
					return {"topic": topic, "level": level, "mode": next_mode}
			elif str(topic.get("id", "")) == str(current_topic.get("id", "")) and str(level.get("id", "")) == str(current_level.get("id", "")):
				seen_current = true
	return {}


func _show_album() -> void:
	current_screen = "album"
	var wrap := _base_screen()
	_header(wrap, _t("album"), _show_topics)
	var hint := Label.new()
	hint.text = _t("album_hint")
	hint.add_theme_color_override("font_color", brown)
	wrap.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = _wide_grid_columns(3, 2)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for topic in topics:
		for level in topic["levels"]:
			var modes := _completed_mode_labels(level)
			if modes.is_empty():
				continue
			var card := _card_button(
				"%s\n%s" % [level["title"], " / ".join(modes)],
				Vector2(260, 170),
				func(t: Dictionary = topic, l: Dictionary = level, m: Array = modes) -> void: _show_album_detail(t, l, m)
			)
			grid.add_child(card)


func _wide_grid_columns(wide_columns: int, narrow_columns: int) -> int:
	return narrow_columns if get_viewport_rect().size.x < 900.0 else wide_columns


func _show_album_detail(topic: Dictionary, level: Dictionary, modes: Array) -> void:
	var wrap := _base_screen()
	_header(wrap, level["title"], _show_album)
	wrap.add_child(_image_rect(Vector2(560, 420)))
	var desc := Label.new()
	desc.text = "%s\n%s" % [level["description"], _t("completed_modes") % " / ".join(modes)]
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", brown)
	wrap.add_child(desc)


func _completed_mode_labels(level: Dictionary) -> Array:
	var modes := []
	for play_mode in PLAY_MODES:
		if progress_store.is_done(level["id"], play_mode):
			modes.append(_mode_label(play_mode))
	return modes


func _start_complete_confetti() -> void:
	_stop_complete_confetti()
	if _ui_motion_reduced():
		return
	complete_confetti_layer = Control.new()
	complete_confetti_layer.name = "CompleteConfettiLayer"
	complete_confetti_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	complete_confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_confetti_layer.z_index = 20
	modal_root.add_child(complete_confetti_layer)
	complete_confetti_layer.add_child(ConfettiEffectScript.new())


func _stop_complete_confetti() -> void:
	if complete_confetti_layer != null and is_instance_valid(complete_confetti_layer):
		if not complete_confetti_layer.is_queued_for_deletion():
			complete_confetti_layer.queue_free()
	complete_confetti_layer = null


func _show_modal(shade_color := Color(0, 0, 0, 0.42), blur_background := false) -> void:
	_stop_complete_confetti()
	for child in modal_root.get_children():
		if not child.is_queued_for_deletion():
			child.queue_free()
	modal_open = true
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = shade_color
	if blur_background:
		shade.color = Color.WHITE
		shade.material = _modal_blur_material(shade_color)
	shade.modulate.a = 0.0
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(shade)
	if _ui_motion_reduced():
		shade.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(shade, "modulate:a", 1.0, 0.14)


func _modal_blur_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.16, 0.11, 0.08, 0.78);
uniform float blur_lod = 3.2;

void fragment() {
	vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod);
	COLOR = mix(blurred, vec4(tint.rgb, 1.0), tint.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", tint)
	return material


func _modal_box(size: Vector2, bg_color := Color("#FFF6E6")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _mode_modal_box(size: Vector2) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.clip_contents = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFF8EC")
	style.border_color = Color("#E7B47E")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 36
	style.corner_radius_top_right = 36
	style.corner_radius_bottom_left = 36
	style.corner_radius_bottom_right = 36
	style.shadow_color = Color(0.36, 0.20, 0.08, 0.16)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	var close := _mode_close_button()
	panel.add_child(close)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var horizontal_padding := _mode_dialog_horizontal_padding(size.x)
	box.offset_left = horizontal_padding
	box.offset_top = 66
	box.offset_right = -horizontal_padding
	box.offset_bottom = -52
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	return box


func _mode_close_button() -> Button:
	var button := Button.new()
	button.text = "×"
	button.custom_minimum_size = Vector2(58, 58)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -78
	button.offset_top = 26
	button.offset_right = -20
	button.offset_bottom = 84
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", brown)
	button.add_theme_color_override("font_hover_color", deep_orange)
	button.add_theme_color_override("font_pressed_color", deep_orange)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_close_modal)
	_wire_button_animation(button)
	return button


func _complete_modal_box(size: Vector2) -> VBoxContainer:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.clip_contents = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = cream
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", style)
	modal_root.add_child(panel)
	_animate_modal_panel(panel)
	_add_complete_paw_marks(panel)
	var box := VBoxContainer.new()
	box.clip_contents = false
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32
	box.offset_top = 0
	box.offset_right = -32
	box.offset_bottom = -28
	panel.add_child(box)
	return box


func _modal_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", brown)
	return label


func _close_modal() -> void:
	_stop_complete_confetti()
	for child in modal_root.get_children():
		if not child.is_queued_for_deletion():
			child.queue_free()
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_open = false
