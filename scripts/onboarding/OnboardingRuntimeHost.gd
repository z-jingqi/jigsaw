class_name OnboardingRuntimeHost
extends RefCounted

const HomeGuideScene := preload("res://scenes/overlays/HomeFirstRunGuide.tscn")
const ModeTutorialScene := preload("res://scenes/modals/ModeTutorialModal.tscn")

const HOME_GUIDE_DELAY := 1.15

var game: Node
var home_guide: Control
var mode_tutorial: Control
var _home_guide_timer: SceneTreeTimer


func _init(owner: Node) -> void:
	game = owner


func schedule_home_guide() -> void:
	_cancel_home_guide_timer()
	if _home_complete() or game.current_screen != "topics":
		return
	_home_guide_timer = game.get_tree().create_timer(HOME_GUIDE_DELAY)
	_home_guide_timer.timeout.connect(_show_home_guide_if_current, CONNECT_ONE_SHOT)


func show_home_guide() -> void:
	_cancel_home_guide_timer()
	if _home_complete() or game.current_screen != "topics":
		return
	if is_instance_valid(home_guide):
		home_guide.call(&"set_step", _next_home_step(), game._reduced_motion_enabled(), _home_guide_labels())
		return
	home_guide = HomeGuideScene.instantiate() as Control
	game.screen_root.add_child(home_guide)
	home_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_guide.connect(&"skip_requested", _skip_home_guide)
	home_guide.call(&"show_step", _next_home_step(), game._reduced_motion_enabled(), _home_guide_labels())


func record_home_swipe() -> void:
	if _home_complete():
		return
	game.onboarding_progress_repository.mark_tutorial_seen(&"home_swipe")
	if is_instance_valid(home_guide):
		home_guide.call(&"set_step", &"enter", game._reduced_motion_enabled(), _home_guide_labels())


func record_home_enter() -> void:
	if _home_complete():
		return
	game.onboarding_progress_repository.mark_tutorial_seen(&"home_enter")
	_close_home_guide()


func show_mode_tutorial(mode: String) -> void:
	if mode.is_empty() or game.onboarding_progress_repository.tutorial_seen(&"mode", mode):
		return
	clear_mode_tutorial()
	mode_tutorial = ModeTutorialScene.instantiate() as Control
	game.modal_root.add_child(mode_tutorial)
	mode_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_tutorial.connect(&"completed", _complete_mode_tutorial.bind(mode))
	mode_tutorial.connect(&"skipped", _complete_mode_tutorial.bind(mode))
	mode_tutorial.connect(&"dismissed", _dismiss_mode_tutorial)
	game.current_modal = "tutorial"
	game.modal_open = true
	mode_tutorial.call(&"navigation_enter", {
		"view_model": game.system_presenter.guide(&"mode", _mode_description(mode)),
		"mode": mode,
		"title": game._t("tutorial_title"),
		"skip_text": game._t("guide_skip"),
		"confirm_text": game._t("got_it"),
	}, {"reduced_motion": game._reduced_motion_enabled()})


func request_close_mode_tutorial() -> void:
	if is_instance_valid(mode_tutorial):
		mode_tutorial.call(&"request_dismiss")


func clear() -> void:
	_cancel_home_guide_timer()
	_close_home_guide()
	clear_mode_tutorial()


func shutdown() -> void:
	clear()
	game = null


func active_motion_count() -> int:
	var result := 0
	if is_instance_valid(home_guide):
		result += int(home_guide.call(&"active_motion_count"))
	if is_instance_valid(mode_tutorial):
		result += int(mode_tutorial.call(&"active_motion_count"))
	return result


func _show_home_guide_if_current() -> void:
	_home_guide_timer = null
	show_home_guide()


func _next_home_step() -> StringName:
	return &"enter" if game.onboarding_progress_repository.tutorial_seen(&"home_swipe") else &"swipe"


func _home_complete() -> bool:
	return (
		game.onboarding_progress_repository.tutorial_seen(&"home_swipe")
		and game.onboarding_progress_repository.tutorial_seen(&"home_enter")
	)


func _skip_home_guide() -> void:
	game.onboarding_progress_repository.mark_tutorial_seen(&"home_swipe")
	game.onboarding_progress_repository.mark_tutorial_seen(&"home_enter")
	_close_home_guide()


func _close_home_guide() -> void:
	if not is_instance_valid(home_guide):
		home_guide = null
		return
	home_guide.call(&"dismiss", game._reduced_motion_enabled())
	home_guide = null


func _complete_mode_tutorial(mode: String) -> void:
	game.onboarding_progress_repository.mark_tutorial_seen(&"mode", mode)
	_dismiss_mode_tutorial()


func _dismiss_mode_tutorial() -> void:
	clear_mode_tutorial()
	if game != null:
		game.current_modal = ""
		game.modal_open = false


func clear_mode_tutorial() -> void:
	if is_instance_valid(mode_tutorial):
		mode_tutorial.call(&"navigation_exit", {})
		mode_tutorial.queue_free()
	mode_tutorial = null


func _cancel_home_guide_timer() -> void:
	if _home_guide_timer != null and is_instance_valid(_home_guide_timer) and _home_guide_timer.timeout.is_connected(_show_home_guide_if_current):
		_home_guide_timer.timeout.disconnect(_show_home_guide_if_current)
	_home_guide_timer = null


func _mode_description(mode: String) -> String:
	match mode:
		"swap":
			return game._t("tutorial_swap")
		_:
			return game._t("tutorial_drag")


func _home_guide_labels() -> Dictionary:
	return {
		"skip": game._t("guide_skip"),
		"swipe": game._t("guide_swipe"),
		"swipe_hint": game._t("guide_swipe_hint"),
		"enter": game._t("guide_enter"),
		"enter_hint": game._t("guide_enter_hint"),
	}
