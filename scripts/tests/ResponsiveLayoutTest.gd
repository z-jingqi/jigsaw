extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const AtomicJsonStoreScript := preload("res://scripts/runtime/data/AtomicJsonStore.gd")
const SessionRepositoryScript := preload("res://scripts/runtime/data/SessionRepository.gd")

const TEST_PROGRESS_PATH := "user://jigcat-test-responsive-progress.json"
const TEST_SESSION_PATH := "user://jigcat-test-responsive/session_v1.json"
const PRESETS := [
	{"label": "iPhone SE", "size": Vector2i(750, 1334)},
	{"label": "iPhone 15", "size": Vector2i(1179, 2556)},
	{"label": "iPad mini", "size": Vector2i(1536, 2048)},
	{"label": "iPad Pro", "size": Vector2i(2048, 2732)},
]

var _all_ok := true
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_storage()
	for preset in PRESETS:
		await _verify_preset(preset)
	_remove_test_storage()
	var result := {"ok": _all_ok, "failures": _failures}
	print("RESPONSIVE_LAYOUT %s" % JSON.stringify(result))
	quit(0 if _all_ok else 1)


func _verify_preset(preset: Dictionary) -> void:
	root.size = preset["size"]
	var game := MainScene.instantiate()
	game.progress_store.save_path = TEST_PROGRESS_PATH
	game.session_repository = SessionRepositoryScript.new(AtomicJsonStoreScript.new(), TEST_SESSION_PATH)
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.50).timeout
	game.progress_store.progress["tutorial_seen_modes"] = {"polygon": true, "knob": true, "swap": true}
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var topic: Dictionary = game.topics[0]
	var level: Dictionary = topic.levels[0]
	var home_ok: bool = game.current_screen == "topics" and _rect_fits(game.screen_root.get_node("topic_home_fixed_ui").get_global_rect(), viewport_size)

	game._show_levels(topic, str(level.id))
	await process_frame
	var levels_header: Control = game.screen_root.get_node_or_null("level_list_topbar") as Control
	var levels_ok: bool = game.current_screen == "levels" and levels_header != null and _rect_fits(levels_header.get_global_rect(), viewport_size)

	game._show_mode_dialog(level)
	await create_timer(0.32).timeout
	var modal: Control = game.modal_root.get_node_or_null("ModeSelectModal") as Control
	var panel: Control = modal.get_node_or_null("ModalShell/Panel") as Control if modal != null else null
	var modal_ok := modal != null and panel != null and _rect_fits(panel.get_global_rect(), viewport_size)
	if modal != null:
		modal.call("request_close")
	await create_timer(0.16).timeout

	game._show_game(topic, level, "polygon", true)
	await create_timer(0.16).timeout
	var polygon: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	var tray_rect := polygon.tray_rect() if polygon != null else Rect2()
	var polygon_ok := polygon != null and _hud_fits(polygon, viewport_size) and _rect_fits(tray_rect, viewport_size) and _puzzle_excludes(game, polygon.top_reserved_height(), tray_rect.position.y)

	game._show_game(topic, level, "swap", true)
	await create_timer(0.16).timeout
	var swap: GameplayScreen = game.screen_root.get_node_or_null("GameplayScreen") as GameplayScreen
	var swap_bar: Control = swap.get_node_or_null("BottomHost/SwapActionBar") as Control if swap != null else null
	var swap_ok := swap != null and swap_bar != null and _hud_fits(swap, viewport_size) and _swap_bar_fits(swap_bar, viewport_size) and _puzzle_excludes(game, swap.top_reserved_height(), swap_bar.get_global_rect().position.y)

	var result := {
		"preset": preset["label"],
		"window": [preset["size"].x, preset["size"].y],
		"viewport": [roundi(viewport_size.x), roundi(viewport_size.y)],
		"home": home_ok,
		"levels": levels_ok,
		"mode_modal": modal_ok,
		"polygon": polygon_ok,
		"swap": swap_ok,
	}
	result["ok"] = home_ok and levels_ok and modal_ok and polygon_ok and swap_ok
	_all_ok = _all_ok and bool(result["ok"])
	if not bool(result["ok"]):
		_failures.append(str(preset["label"]))
	print("RESPONSIVE_LAYOUT %s" % JSON.stringify(result))
	game._clear_ui()
	game._clear_board()
	game.queue_free()
	await process_frame


func _hud_fits(screen: GameplayScreen, viewport_size: Vector2) -> bool:
	return _rect_fits(screen.get_node("Hud").get_global_rect(), viewport_size) and _rect_fits(screen.get_node("Hud/BackButton").get_global_rect(), viewport_size) and _rect_fits(screen.get_node("Hud/HintButton").get_global_rect(), viewport_size) and _rect_fits(screen.get_node("Hud/Title").get_global_rect(), viewport_size)


func _swap_bar_fits(bar: Control, viewport_size: Vector2) -> bool:
	var actions: HBoxContainer = bar.get_node("Actions") as HBoxContainer
	if not _rect_fits(bar.get_global_rect(), viewport_size) or not _rect_fits(actions.get_global_rect(), viewport_size):
		return false
	if absf(bar.get_global_rect().end.y - viewport_size.y) > 0.75:
		return false
	for child in actions.get_children():
		if not child is Control or not _rect_fits((child as Control).get_global_rect(), viewport_size):
			return false
	return true


func _puzzle_excludes(game, top: float, bottom: float) -> bool:
	var area: Rect2 = game.puzzle_board._world_view_screen_rect()
	return absf(area.position.y - top) <= 0.75 and area.end.y <= bottom + 0.75


func _rect_fits(rect: Rect2, viewport_size: Vector2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0 and rect.position.x >= -0.75 and rect.position.y >= -0.75 and rect.end.x <= viewport_size.x + 0.75 and rect.end.y <= viewport_size.y + 0.75


func _remove_test_storage() -> void:
	for path in [TEST_PROGRESS_PATH, TEST_SESSION_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(absolute_path)
		DirAccess.remove_absolute("%s.tmp" % absolute_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SESSION_PATH).get_base_dir())
