class_name GameplayRuntimeHost
extends RefCounted

const ModeSelectScene := preload("res://scenes/modals/ModeSelectModal.tscn")
const GameplayScreenScene := preload("res://scenes/screens/GameplayScreen.tscn")
const BoardSessionIdentityScript := preload("res://scripts/gameplay/runtime/BoardSessionIdentity.gd")

var game: Node
var mode_modal: Control
var gameplay_screen: GameplayScreen


func _init(owner: Node) -> void:
	game = owner


func show_mode_select(level: Dictionary) -> void:
	clear_mode_select()
	mode_modal = ModeSelectScene.instantiate() as Control
	game.modal_root.add_child(mode_modal)
	mode_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_modal.close_requested.connect(_on_mode_close_requested)
	mode_modal.mode_selected.connect(func(mode: StringName, start_policy: StringName) -> void:
		_on_mode_selected(level, mode, start_policy))
	game.current_modal = "mode_select"
	game.modal_open = true
	mode_modal.call(&"navigation_enter", {"view_model": _mode_view_model(level)}, {"reduced_motion": game.progress_store.reduced_motion_enabled()})


func show_gameplay(level: Dictionary, mode: String) -> GameplayScreen:
	clear_gameplay()
	gameplay_screen = GameplayScreenScene.instantiate() as GameplayScreen
	game.screen_root.add_child(gameplay_screen)
	gameplay_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_screen.back_requested.connect(_on_back_requested)
	gameplay_screen.hint_requested.connect(_on_hint_requested)
	gameplay_screen.move_swap_up_requested.connect(_on_move_swap_up_requested)
	gameplay_screen.move_swap_down_requested.connect(_on_move_swap_down_requested)
	gameplay_screen.navigation_enter({"view_model": _gameplay_view_model(level, mode)}, {"reduced_motion": game.progress_store.reduced_motion_enabled()})
	return gameplay_screen


func gameplay_top_reserved_height() -> float:
	return gameplay_screen.top_reserved_height() if is_instance_valid(gameplay_screen) else 64.0


func gameplay_bottom_reserved_height() -> float:
	return gameplay_screen.bottom_reserved_height() if is_instance_valid(gameplay_screen) else 0.0


func gameplay_tray_rect() -> Rect2:
	return gameplay_screen.tray_rect() if is_instance_valid(gameplay_screen) else Rect2()


func mark_board_live() -> void:
	if not is_instance_valid(gameplay_screen):
		return
	gameplay_screen.mark_board_live()
	refresh_board_blockers()


func refresh_board_blockers() -> void:
	if game.puzzle_board == null or not is_instance_valid(gameplay_screen):
		return
	game.puzzle_board.set_drag_blockers(gameplay_screen.board_reserved_rects())


func clear_gameplay() -> void:
	if not is_instance_valid(gameplay_screen):
		return
	gameplay_screen.navigation_exit({})
	gameplay_screen.queue_free()
	gameplay_screen = null


func clear_mode_select() -> void:
	if not is_instance_valid(mode_modal):
		return
	mode_modal.call(&"navigation_exit", {})
	mode_modal.queue_free()
	mode_modal = null


func _on_mode_close_requested() -> void:
	clear_mode_select()
	game.current_modal = ""
	game.modal_open = false


func _on_mode_selected(level: Dictionary, mode: StringName, start_policy: StringName) -> void:
	clear_mode_select()
	game.current_modal = ""
	game.modal_open = false
	game._show_game(game.current_topic, level, String(mode), start_policy == &"replay")


func _on_back_requested() -> void:
	game._persist_current_puzzle_state()
	game._return_to_current_level_list()


func _on_hint_requested() -> void:
	if game.puzzle_board != null:
		game.puzzle_board.show_hint()


func _on_move_swap_up_requested() -> void:
	if game.puzzle_board != null:
		game.puzzle_board.shift_swap_rows_up()


func _on_move_swap_down_requested() -> void:
	if game.puzzle_board != null:
		game.puzzle_board.shift_swap_rows_down()


func _mode_view_model(level: Dictionary) -> Dictionary:
	var options: Array[Dictionary] = []
	var config: Dictionary = game.repository.load_level_config(level)
	for mode in game._available_modes_for_level(level):
		var completed: bool = game.progress_store.is_done(str(level.get("id", "")), mode)
		var piece_ids: Array[String] = BoardSessionIdentityScript.piece_ids(config, mode)
		var has_state: bool = not completed and not game.session_repository.play_state(str(game.current_topic.get("id", "")), str(level.get("id", "")), mode, piece_ids).is_empty()
		options.append({
			"mode": mode,
			"label": game._mode_label(mode),
			"status": "completed" if completed else ("in_progress" if has_state else "not_started"),
			"action": "replay" if completed else ("resume" if has_state else "start"),
			"enabled": true,
		})
	return {"theme_id": str(game.current_topic.get("id", "")), "level_id": str(level.get("id", "")), "level_title": game._level_display_title(level), "options": options}


func _gameplay_view_model(level: Dictionary, mode: String) -> Dictionary:
	var palette: Dictionary = game._topic_ui_palette(game.current_topic)
	return {"theme_id": str(game.current_topic.get("id", "")), "level_id": str(level.get("id", "")), "level_title": game._level_display_title(level), "mode": mode, "ui_scale": game._topics_ui_scale(), "foreground": palette.get("foreground", Color("#062F43"))}
