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
const BoardLayoutScript := preload("res://scripts/BoardLayout.gd")
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
		"restart": "Restart",
		"return_levels": "Level list",
		"return_topics": "Topics",
		"confirm_restart": "Restart this level?",
		"confirm": "Confirm",
		"settings_title": "Settings",
		"music": "Music",
		"sfx": "Sound effects",
		"haptics": "Haptics",
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
		"restart": "重新开始",
		"return_levels": "返回关卡列表",
		"return_topics": "返回主题选择",
		"confirm_restart": "确认重新开始？",
		"confirm": "确认",
		"settings_title": "设置",
		"music": "音乐",
		"sfx": "音效",
		"haptics": "震动反馈",
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
		"restart": "最初から",
		"return_levels": "レベル一覧",
		"return_topics": "テーマへ",
		"confirm_restart": "このレベルをやり直しますか？",
		"confirm": "確認",
		"settings_title": "設定",
		"music": "音楽",
		"sfx": "効果音",
		"haptics": "振動",
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
var screen_root: Control
var modal_root: Control

var topics: Array[Dictionary] = []
var progress_store = ProgressStoreScript.new()
var current_topic: Dictionary = {}
var current_level: Dictionary = {}
var current_mode := "knob"
var current_screen := "home"
var modal_open := false
var complete_confetti_timer: Timer
var complete_confetti_layer: Control
var complete_confetti_rng := RandomNumberGenerator.new()

var status_label: Label
var zoom_label: Label
var hud_blocker_controls: Array[Control] = []
var lazy_thumbnail_items: Array[Dictionary] = []
var lazy_thumbnail_queue: Array[Dictionary] = []
var lazy_thumbnail_processing := false
var rounded_topic_cover_cache: Dictionary = {}
var rounded_level_thumbnail_cache: Dictionary = {}
var rounded_complete_image_cache: Dictionary = {}
var active_locale := "en"


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
	add_child(puzzle_board)
	get_viewport().size_changed.connect(_queue_game_drag_blocker_refresh)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_build_catalog()
	_apply_level_media({})
	_show_topics()


func _lock_portrait_orientation() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _input(event: InputEvent) -> void:
	if current_screen != "game":
		return
	if puzzle_board.handle_input(event, modal_open):
		get_viewport().set_input_as_handled()


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
		"status_swap": _t("status_swap"),
		"pan_hint": _t("pan_hint"),
	}


func _clear_ui() -> void:
	_stop_complete_confetti()
	lazy_thumbnail_items.clear()
	lazy_thumbnail_queue.clear()
	lazy_thumbnail_processing = false
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


func _animate_screen_in(control: Control) -> void:
	control.modulate.a = 0.0
	control.position.y = 18.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)
	tween.tween_property(control, "position:y", 0.0, 0.24)


func _animate_modal_panel(panel: Control) -> void:
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
	var source_texture := repository.cached_texture(image_path)
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


func _root_title(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 72
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var title := TextureRect.new()
	title.texture = title_texture
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(168, 60)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	actions.add_child(_icon_button(icon_album, _show_album, _t("album"), HOME_ICON_BUTTON_SIZE, HOME_ICON_INSET, true))
	actions.add_child(_icon_button(icon_setting, _show_settings_modal, _t("settings"), HOME_ICON_BUTTON_SIZE, HOME_ICON_INSET, true))
	row.add_child(actions)


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
	current_screen = "topics"
	var wrap := _base_screen(cream)
	_root_title(wrap)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	var columns := 1
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", _screen_margin())
	grid.add_theme_constant_override("v_separation", _screen_margin())
	center.add_child(grid)
	if topics.is_empty():
		grid.add_child(_empty_topic_message())
		return
	for topic in topics:
		var card := _topic_card_button(topic, _topic_card_width(columns), func(t: Dictionary = topic) -> void: _show_levels(t, progress_store.focus_level_id(t)))
		grid.add_child(card)


func _show_levels(topic: Dictionary, focus_level_id := "") -> void:
	current_screen = "levels"
	current_topic = topic
	var wrap := _base_screen(cream)
	wrap.add_child(_levels_header(topic))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = _levels_content_width()
	list.add_theme_constant_override("separation", 22)
	center.add_child(list)
	var focus_card: Control = null
	var rendered_count := 0
	var groups: Array = topic.get("groups", [])
	if groups.is_empty() and topic.has("levels"):
		groups = [{"id": "default", "name": "", "levels": topic.get("levels", [])}]
	for group in groups:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		var panel_result := _level_group_panel(group, _topic_color(topic), focus_level_id)
		if int(panel_result.get("count", 0)) <= 0:
			continue
		list.add_child(panel_result["panel"])
		rendered_count += int(panel_result.get("count", 0))
		var candidate = panel_result.get("focus_card", null)
		if candidate != null:
			focus_card = candidate
	if rendered_count <= 0:
		list.add_child(_empty_level_message())
	if focus_card != null:
		call_deferred("_scroll_level_card_into_view", scroll, focus_card)


func _levels_content_width() -> float:
	var width := get_viewport_rect().size.x - _screen_margin() * 2.0
	return minf(maxf(280.0, width), 1040.0)


func _levels_header(topic: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(_levels_content_width(), 166)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_button := _levels_back_button()
	back_button.position = Vector2(0, 40)
	back_button.z_index = 3
	row.add_child(back_button)
	var title := Label.new()
	title.text = str(topic.get("name", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 130
	title.offset_top = 26
	title.offset_right = -190
	title.offset_bottom = 128
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", brown)
	title.add_theme_color_override("font_shadow_color", Color(0.42, 0.20, 0.06, 0.16))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.z_index = 2
	row.add_child(title)
	return row


func _levels_back_button() -> Button:
	var button_size := 84.0
	var button := _icon_button(icon_left_arrow, _show_topics, _t("back"), button_size, 20.0, false, true, brown, deep_orange)
	for child in button.get_children():
		if child is TextureRect:
			child.modulate = brown
			button.mouse_entered.connect(func() -> void:
				if is_instance_valid(child):
					child.modulate = brown
			)
			button.mouse_exited.connect(func() -> void:
				if is_instance_valid(child):
					child.modulate = brown
			)
			button.button_down.connect(func() -> void:
				if is_instance_valid(child):
					child.modulate = deep_orange
			)
			button.button_up.connect(func() -> void:
				if is_instance_valid(child):
					child.modulate = brown
			)
	return button


func _level_group_panel(group: Dictionary, fallback_color: Color, focus_level_id: String) -> Dictionary:
	var group_levels: Array = group.get("levels", [])
	if group_levels.is_empty():
		return {"panel": Control.new(), "count": 0, "focus_card": null}
	var group_color_value := str(group.get("color", "")).strip_edges()
	var accent := _color_from_value(group_color_value, fallback_color)
	if group_color_value.is_empty() or group_color_value.to_lower() == "#f6ebd4":
		accent = fallback_color
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = _levels_content_width()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = accent.lightened(0.58)
	panel_style.bg_color.a = 0.34
	panel_style.border_color = accent.lightened(0.18)
	panel_style.border_color.a = 0.36
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 28
	panel_style.corner_radius_top_right = 28
	panel_style.corner_radius_bottom_left = 28
	panel_style.corner_radius_bottom_right = 28
	panel_style.content_margin_left = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_right = 22
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_level_group_title(str(group.get("name", "")), accent))
	var focus_card: Control = null
	var count := 0
	for level in group_levels:
		if typeof(level) != TYPE_DICTIONARY:
			continue
		var row := _level_list_row(level, func(l: Dictionary = level) -> void: _show_mode_dialog(l))
		box.add_child(row)
		count += 1
		if str(level.get("id", "")) == focus_level_id:
			focus_card = row
	return {"panel": panel, "count": count, "focus_card": focus_card}


func _level_group_title(text: String, accent: Color) -> Control:
	var holder := HBoxContainer.new()
	holder.custom_minimum_size.y = 50
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.add_theme_constant_override("separation", 14)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = accent
	dot_style.corner_radius_top_left = 9
	dot_style.corner_radius_top_right = 9
	dot_style.corner_radius_bottom_left = 9
	dot_style.corner_radius_bottom_right = 9
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dot)
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(150, 42)
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = accent.lightened(0.42)
	pill_style.bg_color.a = 0.72
	pill_style.corner_radius_top_left = 21
	pill_style.corner_radius_top_right = 21
	pill_style.corner_radius_bottom_left = 21
	pill_style.corner_radius_bottom_right = 21
	pill_style.content_margin_left = 26
	pill_style.content_margin_right = 26
	pill.add_theme_stylebox_override("panel", pill_style)
	holder.add_child(pill)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", accent.darkened(0.42))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return holder


func _level_list_row(level: Dictionary, action: Callable) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(_levels_content_width() - 44.0, 118)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var available_modes := _available_modes_for_level(level)
	var level_config := repository.load_level_config(level)
	var thumbnail_source_path := repository.level_thumbnail_source_path(level_config)
	var enabled := not thumbnail_source_path.is_empty() and not available_modes.is_empty()
	card.disabled = not enabled
	_apply_level_row_style(card)
	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26
	content.offset_top = 14
	content.offset_right = -26
	content.offset_bottom = -14
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 28)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_level_round_thumbnail(thumbnail_source_path, 88))
	var title := Label.new()
	title.text = _level_display_title(level)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 36)
	modes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(modes)
	for play_mode in PLAY_MODES:
		var done := available_modes.has(play_mode) and progress_store.is_done(level["id"], play_mode)
		modes.add_child(_status_icon(play_mode, done, 54))
	if enabled:
		card.pressed.connect(action)
		_wire_button_animation(card)
	else:
		_highlight_button_bounds(card)
	return card


func _level_display_title(level: Dictionary) -> String:
	var title := str(level.get("title", "")).strip_edges()
	if title.is_empty():
		return str(level.get("id", ""))
	return title


func _apply_level_row_style(card: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.985, 0.94, 0.82)
	normal.border_color = Color(0.70, 0.53, 0.36, 0.20)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	card.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#FFF3DC")
	hover.border_color = Color(0.78, 0.52, 0.28, 0.36)
	card.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#F8E7C7")
	card.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(1.0, 0.985, 0.94, 0.48)
	disabled.border_color = Color(0.70, 0.53, 0.36, 0.13)
	card.add_theme_stylebox_override("disabled", disabled)
	card.add_theme_stylebox_override("focus", normal.duplicate())


func _level_round_thumbnail(image_path: String, size: float) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82, 0.62)
	var radius := int(size * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	holder.add_theme_stylebox_override("panel", style)
	var target_size := Vector2i(int(size), int(size))
	var texture := _rounded_level_thumbnail_texture(image_path, target_size, int(size * 0.5)) if not image_path.is_empty() else null
	if texture == null:
		texture = repository.placeholder_texture()
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	return holder


func _level_mode_legend() -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size.y = 96
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_levels_content_width(), 76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.965, 0.88, 0.68)
	style.border_color = Color(0.78, 0.52, 0.28, 0.30)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 52)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_level_legend_item("polygon", _mode_label("polygon")))
	row.add_child(_level_legend_item("knob", _mode_label("knob")))
	row.add_child(_level_legend_item("swap", _mode_label("swap")))
	return center


func _level_legend_item(play_mode: String, text: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 14)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(_status_icon(play_mode, true, 48))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", brown)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(label)
	return item


func _color_from_value(value: String, fallback: Color) -> Color:
	var clean := value.strip_edges()
	return Color(clean) if clean.begins_with("#") else fallback


func _level_group_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(380, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", brown)
	return label


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


func _level_card_button(level: Dictionary, action: Callable) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(380, 118)
	_apply_card_style(card)
	var available_modes := _available_modes_for_level(level)
	var level_config := repository.load_level_config(level)
	var thumbnail_source_path := repository.level_thumbnail_source_path(level_config)
	if thumbnail_source_path.is_empty() or available_modes.is_empty():
		card.disabled = true
	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_top = 12
	content.offset_right = -14
	content.offset_bottom = -12
	content.add_theme_constant_override("separation", 16)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_lazy_level_preview(thumbnail_source_path, Vector2(82, 82)))
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 10)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_box)
	var title := Label.new()
	title.text = str(level["title"])
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(row)
	for play_mode in available_modes:
		row.add_child(_status_icon(play_mode, progress_store.is_done(level["id"], play_mode), 38))
	if not thumbnail_source_path.is_empty() and not available_modes.is_empty():
		card.pressed.connect(action)
		_wire_button_animation(card)
	else:
		_highlight_button_bounds(card)
	return card


func _lazy_level_preview(image_path: String, min_size: Vector2) -> Control:
	var holder := _preview_panel(null, min_size, "")
	var item := {
		"holder": holder,
		"path": image_path,
		"size": LEVEL_THUMBNAIL_SIZE,
		"min_size": min_size,
		"queued": false,
		"loaded": false,
	}
	lazy_thumbnail_items.append(item)
	return holder


func _register_level_thumbnail_lazy_loader(scroll: ScrollContainer) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar != null:
		scrollbar.value_changed.connect(func(_value: float) -> void:
			_refresh_lazy_level_thumbnails(scroll)
		)
	scroll.resized.connect(func() -> void:
		_refresh_lazy_level_thumbnails(scroll)
	)
	call_deferred("_refresh_lazy_level_thumbnails", scroll)


func _refresh_lazy_level_thumbnails(scroll: ScrollContainer) -> void:
	if current_screen != "levels" or not is_instance_valid(scroll):
		return
	var viewport := Rect2(scroll.global_position, scroll.size).grow(220.0)
	for item in lazy_thumbnail_items:
		if bool(item.get("loaded", false)) or bool(item.get("queued", false)):
			continue
		var holder: Control = item.get("holder")
		if not is_instance_valid(holder):
			item["loaded"] = true
			continue
		var holder_rect := Rect2(holder.global_position, holder.size)
		if viewport.intersects(holder_rect):
			item["queued"] = true
			lazy_thumbnail_queue.append(item)
	_process_lazy_thumbnail_queue()


func _process_lazy_thumbnail_queue() -> void:
	if lazy_thumbnail_processing:
		return
	lazy_thumbnail_processing = true
	call_deferred("_process_next_lazy_thumbnail")


func _process_next_lazy_thumbnail() -> void:
	if lazy_thumbnail_queue.is_empty():
		lazy_thumbnail_processing = false
		return
	var item: Dictionary = lazy_thumbnail_queue.pop_front()
	var holder: Control = item.get("holder")
	if is_instance_valid(holder) and not bool(item.get("loaded", false)):
		var texture := repository.cached_runtime_thumbnail(str(item.get("path", "")), item.get("size", LEVEL_THUMBNAIL_SIZE))
		if texture != null:
			_set_preview_texture(holder, texture, item.get("min_size", Vector2(82, 82)))
		item["loaded"] = true
	item["queued"] = false
	call_deferred("_process_next_lazy_thumbnail")


func _set_preview_texture(holder: Control, preview_texture: Texture2D, min_size: Vector2) -> void:
	for child in holder.get_children():
		child.queue_free()
	var preview := TextureRect.new()
	preview.texture = preview_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.custom_minimum_size = min_size
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)


func _topic_card_width(columns: int) -> float:
	var available := get_viewport_rect().size.x - _screen_margin() * 2.0 - _screen_margin() * float(max(0, columns - 1))
	return maxf(240.0, floor(available / float(max(1, columns))))


func _topic_card_button(topic: Dictionary, card_width: float, action: Callable) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(card_width, card_width * 0.42 * (2.0 / 3.0))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var card_size := card.custom_minimum_size
	var inset := maxf(12.0, card_size.y * 0.055)
	var frame := Panel.new()
	frame.name = "topic_card_frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = paper
	frame_style.border_color = Color(0.77, 0.56, 0.34, 0.36)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 22
	frame_style.corner_radius_top_right = 22
	frame_style.corner_radius_bottom_left = 22
	frame_style.corner_radius_bottom_right = 22
	frame.add_theme_stylebox_override("panel", frame_style)
	card.add_child(frame)
	var content_frame := Panel.new()
	content_frame.name = "topic_card_content_frame"
	content_frame.clip_contents = true
	content_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_frame.offset_left = inset
	content_frame.offset_top = inset
	content_frame.offset_right = -inset
	content_frame.offset_bottom = -inset
	content_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frame.add_theme_stylebox_override("panel", _rounded_panel_style(paper, 16))
	frame.add_child(content_frame)
	var topic_color := _topic_color(topic)
	var color_panel := Panel.new()
	color_panel.name = "topic_color_panel"
	color_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	color_panel.offset_left = 0
	color_panel.offset_top = 0
	color_panel.offset_right = card_size.x * 0.20
	color_panel.offset_bottom = 0
	color_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_panel.add_theme_stylebox_override("panel", _left_topic_color_style(topic_color, 16))
	content_frame.add_child(color_panel)
	var bell_width := maxf(8.0, card_size.y * 0.09)
	var bell_height := maxf(38.0, (card_size.y - inset * 2.0) * 0.90)
	var bell := Polygon2D.new()
	bell.name = "topic_color_bell"
	bell.color = topic_color
	bell.position = Vector2(color_panel.offset_right - bell_width * 0.36, (card_size.y - inset * 2.0 - bell_height) * 0.5)
	bell.polygon = _right_peak_bell_polygon(bell_width, bell_height)
	content_frame.add_child(bell)
	var icon_texture := repository.topic_icon_texture(topic)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.name = "topic_icon"
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		var icon_inset := maxf(9.0, card_size.y * 0.15)
		icon.offset_left = icon_inset * 0.7
		icon.offset_top = icon_inset
		icon.offset_right = -(card_size.x - color_panel.offset_right + icon_inset * 0.25)
		icon.offset_bottom = -icon_inset
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_frame.add_child(icon)
	var inner_width := card_size.x - inset * 2.0
	var inner_height := card_size.y - inset * 2.0
	var cover_texture := repository.topic_cover_texture(topic)
	var cover_right_margin := maxf(10.0, inner_width * 0.025)
	var cover_gap := maxf(16.0, inner_width * 0.035)
	var cover_width := inner_width * 0.38
	var cover_holder := Control.new()
	cover_holder.name = "topic_cover_holder"
	cover_holder.clip_contents = false
	cover_holder.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	cover_holder.offset_left = -cover_width - cover_right_margin
	cover_holder.offset_top = 0
	cover_holder.offset_right = -cover_right_margin
	cover_holder.offset_bottom = 0
	cover_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frame.add_child(cover_holder)
	var cover := TextureRect.new()
	cover.name = "topic_cover"
	cover.texture = cover_texture
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_holder.add_child(cover)
	var text_box := Control.new()
	text_box.name = "topic_text_box"
	text_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = color_panel.offset_right + bell_width * 0.68 + 16
	text_box.offset_top = maxf(6.0, inner_height * 0.10)
	text_box.offset_right = -(cover_width + cover_right_margin + cover_gap)
	text_box.offset_bottom = -maxf(6.0, inner_height * 0.10)
	text_box.custom_minimum_size.x = maxf(170.0, inner_width * 0.30)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frame.add_child(text_box)
	var title := Label.new()
	title.name = "topic_title"
	title.text = str(topic["name"])
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = true
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_top = 0
	title.offset_right = 0
	title.offset_bottom = inner_height * 0.42
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.add_theme_font_size_override("font_size", max(18, int(card_size.y * 0.14) + 2))
	title.add_theme_color_override("font_color", brown)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title)
	var done := _topic_available_done_count(topic)
	var total := _topic_available_mode_total(topic)
	var progress_width := maxf(156.0, minf(text_box.custom_minimum_size.x, inner_width * 0.30))
	var progress_label := Label.new()
	progress_label.name = "topic_progress_label"
	progress_label.text = "%d/%d" % [done, total]
	progress_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	progress_label.offset_left = 0
	progress_label.offset_top = -inner_height * 0.28
	progress_label.offset_right = progress_width
	progress_label.offset_bottom = -inner_height * 0.13
	progress_label.add_theme_font_size_override("font_size", max(12, int(card_size.y * 0.075)))
	progress_label.add_theme_color_override("font_color", soft_brown)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(progress_label)
	var bar := _topic_progress_bar(done, total, Vector2(progress_width, maxf(12.0, card_size.y * 0.046)), topic_color)
	bar.name = "topic_progress_bar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 0
	bar.offset_top = -inner_height * 0.09
	bar.offset_right = progress_width
	bar.offset_bottom = -inner_height * 0.09 + bar.custom_minimum_size.y
	text_box.add_child(bar)
	card.pressed.connect(action)
	_wire_button_animation(card)
	return card


func _right_peak_bell_polygon(width: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(0, 0))
	var segments := 12
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var y := t * height
		var normalized := (t - 0.5) * 2.0
		var x := width * exp(-normalized * normalized * 2.8)
		points.append(Vector2(x, y))
	points.append(Vector2(0, height))
	return points


func _topic_color(topic: Dictionary) -> Color:
	var value := str(topic.get("color", "#D9933F"))
	return Color(value) if value.begins_with("#") else orange


func _left_topic_color_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	return style


func _topic_progress_bar(done: int, total: int, size: Vector2, fill_color: Color) -> Panel:
	var holder := Panel.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.78, 0.64, 0.48, 0.22)
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


func _preview_panel(preview_texture: Texture2D, min_size: Vector2, placeholder_text: String) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = min_size
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preview_texture != null:
		var preview := TextureRect.new()
		preview.texture = preview_texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = min_size
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(preview)
		return holder
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = min_size
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.88, 0.86)
	style.border_color = Color(0.73, 0.50, 0.28, 0.35)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	placeholder.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = placeholder_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", muted)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	holder.add_child(placeholder)
	return holder


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
	state.text = _mode_modal_description(play_mode)
	state.add_theme_font_size_override("font_size", maxi(18, int(22.0 * layout_scale)))
	state.add_theme_color_override("font_color", _mode_accent_color(play_mode).darkened(0.14) if done else soft_brown)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(state)
	var action: Callable = func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	row.add_child(_mode_action_button(
		_t("replay") if done else _t("start_game"),
		play_mode,
		action,
		Vector2(maxf(118.0, 168.0 * layout_scale), maxf(48.0, 58.0 * layout_scale)),
		maxi(18, int(24.0 * layout_scale))
	))
	if done:
		card.add_child(_mode_corner_check_badge(_mode_accent_color(play_mode)))
	card.pressed.connect(func() -> void:
		_close_modal()
		_show_game(current_topic, level, play_mode)
	)
	_wire_button_animation(card)
	return card


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


func _show_game(topic: Dictionary, level: Dictionary, play_mode: String) -> void:
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
	elif not progress_store.tutorial_seen():
		_show_tutorial_modal()


func _set_game_status(text: String) -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = text
		status_label.visible = not text.is_empty()


func _set_zoom_label(percent: int) -> void:
	if zoom_label != null and is_instance_valid(zoom_label):
		zoom_label.text = "%d%%" % percent


func _on_puzzle_completed() -> void:
	progress_store.mark_completed(current_level["id"], current_mode)
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
	hud_blocker_controls.append(hint_button)
	hud_blocker_controls.append(status_label)
	_queue_game_drag_blocker_refresh()
	_animate_screen_in(screen_root)


func _hud_top_icons_width() -> float:
	return _game_top_actions_width()


func _game_top_bar_height() -> float:
	return _game_hint_button_size() + 22.0


func _game_top_actions_width() -> float:
	return _game_hint_button_size() + 20.0


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
		_show_game(current_topic, current_level, current_mode)
	))
	box.add_child(_button(_t("back"), _show_pause_modal, false))


func _show_settings_modal() -> void:
	_show_modal()
	var box := _modal_box(Vector2(420, 390))
	box.add_child(_modal_title(_t("settings_title")))
	for name in [_t("music"), _t("sfx"), _t("haptics")]:
		var check := CheckBox.new()
		check.text = name
		check.button_pressed = true
		check.add_theme_color_override("font_color", brown)
		box.add_child(check)
	var rotation_check := CheckBox.new()
	rotation_check.text = _t("random_rotation")
	rotation_check.button_pressed = progress_store.random_rotation_enabled()
	rotation_check.add_theme_color_override("font_color", brown)
	rotation_check.toggled.connect(func(enabled: bool) -> void:
		progress_store.set_random_rotation_enabled(enabled)
		if current_screen == "game":
			_set_game_status(_t("random_rotation_next"))
	)
	box.add_child(rotation_check)
	box.add_child(_button(_t("close"), _close_modal))


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
		progress_store.mark_tutorial_seen()
		_close_modal()
	))


func _show_complete_modal() -> void:
	_show_modal(Color(0.16, 0.11, 0.08, 0.78), true)
	_start_complete_confetti()
	var viewport_size := get_viewport_rect().size
	var content_width := minf(viewport_size.x * 0.82, 860.0)
	var image_height := content_width * 4.0 / 3.0
	var max_image_height := viewport_size.y * 0.58
	if image_height > max_image_height:
		image_height = max_image_height
		content_width = image_height * 0.75
	content_width = maxf(280.0, content_width)
	image_height = content_width * 4.0 / 3.0
	var button_size := Vector2(minf(360.0, content_width * 0.62), 72.0)
	var total_height := 94.0 + image_height + 42.0 + button_size.y
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(content_width, total_height)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -content_width * 0.5
	box.offset_top = -total_height * 0.5
	box.offset_right = content_width * 0.5
	box.offset_bottom = total_height * 0.5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
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
	complete_confetti_rng.randomize()
	complete_confetti_layer = Control.new()
	complete_confetti_layer.name = "CompleteLightEffectLayer"
	complete_confetti_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	complete_confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	complete_confetti_layer.z_index = 2
	modal_root.add_child(complete_confetti_layer)
	_add_complete_radial_lights()
	for i in range(9):
		_spawn_complete_light_strip(complete_confetti_rng.randf_range(-get_viewport_rect().size.y * 0.70, get_viewport_rect().size.y * 0.35))
	complete_confetti_timer = Timer.new()
	complete_confetti_timer.wait_time = 0.32
	complete_confetti_timer.one_shot = false
	complete_confetti_timer.timeout.connect(_spawn_complete_light_strip_batch)
	modal_root.add_child(complete_confetti_timer)
	complete_confetti_timer.start()


func _stop_complete_confetti() -> void:
	if complete_confetti_timer != null and is_instance_valid(complete_confetti_timer):
		complete_confetti_timer.stop()
		if not complete_confetti_timer.is_queued_for_deletion():
			complete_confetti_timer.queue_free()
	complete_confetti_timer = null
	if complete_confetti_layer != null and is_instance_valid(complete_confetti_layer):
		if not complete_confetti_layer.is_queued_for_deletion():
			complete_confetti_layer.queue_free()
	complete_confetti_layer = null


func _spawn_complete_light_strip_batch() -> void:
	if complete_confetti_layer == null or not is_instance_valid(complete_confetti_layer):
		return
	_spawn_complete_light_strip(-get_viewport_rect().size.y * 0.35)


func _add_complete_radial_lights() -> void:
	if complete_confetti_layer == null or not is_instance_valid(complete_confetti_layer):
		return
	var viewport_size := get_viewport_rect().size
	var ray_root := Node2D.new()
	ray_root.name = "complete_radial_lights"
	ray_root.position = viewport_size * 0.5 + Vector2(0.0, -viewport_size.y * 0.08)
	ray_root.z_index = 0
	ray_root.modulate.a = 0.86
	complete_confetti_layer.add_child(ray_root)
	var ray_count := 34
	var outer_radius := maxf(viewport_size.x, viewport_size.y) * 0.88
	var inner_radius := minf(viewport_size.x, viewport_size.y) * 0.11
	for i in ray_count:
		var angle := TAU * float(i) / float(ray_count) + complete_confetti_rng.randf_range(-0.035, 0.035)
		var direction := Vector2(cos(angle), sin(angle))
		var ray := Line2D.new()
		ray.points = PackedVector2Array([direction * inner_radius, direction * outer_radius])
		ray.width = complete_confetti_rng.randf_range(10.0, 24.0)
		ray.default_color = Color(1.0, complete_confetti_rng.randf_range(0.70, 0.92), 0.38, complete_confetti_rng.randf_range(0.035, 0.085))
		ray.antialiased = true
		ray_root.add_child(ray)
	var rotation_tween := create_tween()
	rotation_tween.bind_node(ray_root)
	rotation_tween.set_loops()
	rotation_tween.set_trans(Tween.TRANS_LINEAR)
	rotation_tween.tween_property(ray_root, "rotation", TAU, 26.0).as_relative()
	var alpha_tween := create_tween()
	alpha_tween.bind_node(ray_root)
	alpha_tween.set_loops()
	alpha_tween.set_ease(Tween.EASE_IN_OUT)
	alpha_tween.set_trans(Tween.TRANS_SINE)
	alpha_tween.tween_property(ray_root, "modulate:a", 0.56, 2.2)
	alpha_tween.tween_property(ray_root, "modulate:a", 0.90, 2.2)


func _spawn_complete_light_strip(start_y: float) -> void:
	if complete_confetti_layer == null or not is_instance_valid(complete_confetti_layer):
		return
	var viewport_size := get_viewport_rect().size
	var palette := _complete_light_palette()
	var color: Color = palette[complete_confetti_rng.randi_range(0, palette.size() - 1)]
	var strip_width := complete_confetti_rng.randf_range(16.0, 40.0)
	var strip_length := viewport_size.y * complete_confetti_rng.randf_range(0.46, 0.82)
	var strip := Panel.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.custom_minimum_size = Vector2(strip_width, strip_length)
	strip.size = strip.custom_minimum_size
	strip.pivot_offset = strip.size * 0.5
	strip.position = Vector2(complete_confetti_rng.randf_range(-viewport_size.x * 0.25, viewport_size.x * 1.05), start_y)
	strip.rotation = complete_confetti_rng.randf_range(-0.58, -0.34)
	strip.z_index = 1
	strip.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.bg_color.a = complete_confetti_rng.randf_range(0.10, 0.20)
	var corner := int(strip_width * 0.5)
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	strip.add_theme_stylebox_override("panel", style)
	var inner := ColorRect.new()
	inner.color = Color(1.0, 1.0, 1.0, 0.10)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = strip_width * 0.32
	inner.offset_right = -strip_width * 0.36
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(inner)
	complete_confetti_layer.add_child(strip)
	var duration := complete_confetti_rng.randf_range(3.4, 5.4)
	var end_position := strip.position + Vector2(complete_confetti_rng.randf_range(140.0, 340.0), viewport_size.y + strip_length * 0.78)
	var tween := create_tween()
	tween.bind_node(strip)
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(strip, "position", end_position, duration)
	tween.tween_property(strip, "modulate:a", 1.0, duration * 0.16)
	tween.tween_property(strip, "modulate:a", 0.0, duration * 0.24).set_delay(duration * 0.74)
	tween.tween_property(strip, "rotation", strip.rotation + complete_confetti_rng.randf_range(-0.10, 0.10), duration)
	tween.finished.connect(func() -> void:
		if is_instance_valid(strip):
			strip.queue_free()
	)


func _complete_light_palette() -> Array[Color]:
	return [
		Color("#FFE39B"),
		Color("#FFD3B5"),
		Color("#FFF7CF"),
		Color("#F6C9FF"),
		Color("#BFEAFF"),
		Color("#CFF8D6"),
	]


func _scroll_level_card_into_view(scroll: ScrollContainer, card: Control) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(card):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(card):
		return
	var target := card.global_position.y - scroll.global_position.y + float(scroll.scroll_vertical) - 24.0
	scroll.scroll_vertical = max(0, int(target))


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
