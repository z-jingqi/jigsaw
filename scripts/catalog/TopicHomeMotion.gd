extends RefCounted
class_name TopicHomeMotion

const PAGE_EDGE_ALPHA := 0.0
const PAGE_EDGE_SCALE := 0.985
const PAGE_PARALLAX_RATIO := 0.07

var game: Node
var screen_tweens: Array[Tween] = []


func _init(owner: Node) -> void:
	game = owner


func begin_screen(_topics: Array[Dictionary]) -> void:
	_cancel_motion()


func unregister_page(_page_index: int) -> void:
	pass


func animate_entrance(fixed_ui: Control, current_page: Control, indicator: Control, ui_scale: float) -> void:
	if fixed_ui == null or current_page == null:
		return
	if _reduced():
		fixed_ui.modulate.a = 1.0
		fixed_ui.position.y = 0.0
		current_page.modulate.a = 1.0
		current_page.scale = Vector2.ONE
		if indicator != null:
			indicator.modulate.a = 1.0
		return
	fixed_ui.modulate.a = 0.0
	fixed_ui.position.y = -6.0 * ui_scale
	current_page.pivot_offset = current_page.size * 0.5
	current_page.scale = Vector2(1.025, 1.025)
	current_page.modulate.a = 0.0
	var page_tween := game.create_tween().set_parallel(true)
	page_tween.tween_property(current_page, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	page_tween.tween_property(current_page, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_track(page_tween)
	var ui_tween := game.create_tween().set_parallel(true)
	ui_tween.tween_property(fixed_ui, "modulate:a", 1.0, 0.28).set_delay(0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(fixed_ui, "position:y", 0.0, 0.34).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_track(ui_tween)
	if indicator != null:
		indicator.modulate.a = 0.0
		var indicator_tween := game.create_tween()
		indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.22).set_delay(0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_track(indicator_tween)


func update_page_transition(rendered_pages: Dictionary, visual_offset: float) -> void:
	for offset_value in rendered_pages.keys():
		var page = rendered_pages[offset_value]
		if not page is Control or not is_instance_valid(page):
			continue
		var control := page as Control
		control.pivot_offset = control.size * 0.5
		var distance := clampf(absf(float(offset_value) - visual_offset), 0.0, 1.0)
		if _reduced():
			control.scale = Vector2.ONE
			control.modulate.a = 1.0 if distance < 0.5 else 0.0
			continue
		var parent := control.get_parent_control()
		if parent != null:
			var screen_offset := (float(offset_value) - visual_offset) * control.size.x * PAGE_PARALLAX_RATIO
			control.position.x = -parent.position.x + screen_offset
		var focus := 1.0 - distance
		var eased_focus := smoothstep(0.0, 1.0, focus)
		var scale_value := lerpf(PAGE_EDGE_SCALE, 1.0, eased_focus)
		control.scale = Vector2(scale_value, scale_value)
		control.modulate.a = lerpf(PAGE_EDGE_ALPHA, 1.0, eased_focus)


func animate_topic_text_change(items: Array) -> void:
	if _reduced():
		for item in items:
			if item is CanvasItem and is_instance_valid(item):
				(item as CanvasItem).modulate.a = 1.0
		return
	var tween := game.create_tween().set_parallel(true)
	var has_item := false
	for item in items:
		if not item is CanvasItem or not is_instance_valid(item):
			continue
		has_item = true
		var canvas_item := item as CanvasItem
		canvas_item.modulate.a = 0.0
		tween.tween_property(canvas_item, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if has_item:
		_track(tween)
	else:
		tween.kill()


func animate_enter_theme(fixed_ui: Control, current_page: Control) -> void:
	if fixed_ui == null or current_page == null or _reduced():
		return
	_cancel_motion()
	current_page.pivot_offset = current_page.size * 0.5
	var tween := game.create_tween().set_parallel(true)
	tween.tween_property(fixed_ui, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(current_page, "scale", Vector2(1.08, 1.08), 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_page, "modulate:a", 0.72, 0.34).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_track(tween)
	await tween.finished
	screen_tweens.erase(tween)


func debug_state() -> Dictionary:
	_prune_finished_tweens()
	return {"active_tweens": screen_tweens.size()}


func shutdown() -> void:
	_cancel_motion()
	game = null


func _track(tween: Tween) -> void:
	if tween == null:
		return
	_prune_finished_tweens()
	screen_tweens.append(tween)


func _cancel_motion() -> void:
	for tween in screen_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	screen_tweens.clear()


func _prune_finished_tweens() -> void:
	var active: Array[Tween] = []
	for tween in screen_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			active.append(tween)
	screen_tweens = active


func _reduced() -> bool:
	return game == null or game._ui_motion_reduced()
