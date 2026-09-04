extends CanvasLayer

const GAME_SCENE_PATH := "res://scenes/app/Game.tscn"
const ButtonHapticsScript := preload("res://scripts/ui/feedback/ButtonHaptics.gd")

var _button_haptics: ButtonHaptics

@onready var status_label: Label = $Content/Center/Status
@onready var progress_bar: ProgressBar = $Content/Center/Progress
@onready var retry_button: Button = $Content/Center/Retry


func _ready() -> void:
	set_process(false)
	_button_haptics = ButtonHapticsScript.new(self)
	retry_button.pressed.connect(_begin_loading)
	_begin_loading.call_deferred()


func _begin_loading() -> void:
	retry_button.hide()
	status_label.text = "正在加载…"
	progress_bar.value = 0.0
	var error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "PackedScene")
	if error != OK:
		_show_error()
		return
	set_process(true)


func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)
	if not progress.is_empty():
		progress_bar.value = maxf(progress_bar.value, float(progress[0]) * 70.0)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_finish_loading.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_error()


func _finish_loading() -> void:
	status_label.text = "正在准备拼图…"
	progress_bar.value = 70.0
	await _wait_for_display()
	var scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if scene == null:
		_show_error()
		return
	var game := scene.instantiate()
	game.set("startup_managed", true)
	get_tree().root.add_child(game)
	var result: Dictionary = await game.call("prepare_startup", _on_warmup_progress)
	if not bool(result.get("ok", false)):
		game.queue_free()
		_show_error()
		return
	status_label.text = "准备好了"
	progress_bar.value = 100.0
	await _wait_for_display()
	get_tree().current_scene = game
	queue_free()


func _on_warmup_progress(progress: float) -> void:
	progress_bar.value = 70.0 + clampf(progress, 0.0, 1.0) * 29.0


func _wait_for_display() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _show_error() -> void:
	set_process(false)
	status_label.text = "加载未完成，请重试"
	retry_button.show()


func _exit_tree() -> void:
	if _button_haptics != null:
		_button_haptics.dispose()
		_button_haptics = null
