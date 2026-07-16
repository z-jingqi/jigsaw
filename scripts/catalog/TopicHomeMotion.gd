extends RefCounted
class_name TopicHomeMotion

const TopicCardMotionScript := preload("res://scripts/catalog/TopicCardMotion.gd")
const PAGE_EDGE_SCALE := 0.965
const PAGE_EDGE_ALPHA := 0.72

var game: Node
var card_motion
var screen_tweens: Array[Tween] = []


func _init(owner: Node) -> void:
	game = owner
	card_motion = TopicCardMotionScript.new(owner)


func begin_screen(topics: Array[Dictionary]) -> void:
	_cancel_page_motion()
	card_motion.begin_screen(topics)


func register_card(card: Control, topic: Dictionary, page_index: int, row_index: int) -> void:
	card_motion.register_card(card, topic, page_index, row_index)


func unregister_page(page_index: int) -> void:
	card_motion.unregister_page(page_index)


func animate_entrance(topbar: Control, first_page: Control, indicator: Control, ui_scale: float) -> void:
	if topbar == null or first_page == null:
		return
	var logo: Control = topbar.get_node_or_null("theme_logo")
	var settings: Control = topbar.get_node_or_null("theme_settings_button")
	if _reduced():
		_set_final_topbar_state(logo, settings, indicator)
		card_motion.set_final_entry_state(first_page)
		return
	_animate_logo(logo, ui_scale)
	_animate_settings(settings)
	card_motion.animate_entries(first_page, ui_scale)
	if indicator != null and indicator.visible:
		indicator.modulate.a = 0.0
		var indicator_tween := game.create_tween()
		indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.22).set_delay(0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_track_tween(indicator_tween)


func update_page_transition(rendered_pages: Dictionary, visual_page: float) -> void:
	for page_index_value in rendered_pages.keys():
		var page_index := int(page_index_value)
		var page = rendered_pages[page_index_value]
		if not page is Control or not is_instance_valid(page):
			continue
		var page_control := page as Control
		page_control.pivot_offset = page_control.size * 0.5
		if _reduced():
			page_control.scale = Vector2.ONE
			page_control.modulate.a = 1.0
			continue
		var distance := clampf(absf(float(page_index) - visual_page), 0.0, 1.0)
		var page_scale := lerpf(1.0, PAGE_EDGE_SCALE, distance)
		page_control.scale = Vector2(page_scale, page_scale)
		page_control.modulate.a = lerpf(1.0, PAGE_EDGE_ALPHA, distance)


func press_card(topic_id: String) -> void:
	card_motion.press_card(topic_id)


func release_card(topic_id: String, action: Callable) -> void:
	card_motion.release_card(topic_id, action)


func cancel_card(topic_id: String) -> void:
	card_motion.cancel_card(topic_id)


func debug_state() -> Dictionary:
	return card_motion.debug_state()


func shutdown() -> void:
	_cancel_page_motion()
	card_motion.shutdown()
	card_motion = null
	game = null


func _animate_logo(logo: Control, ui_scale: float) -> void:
	if logo == null:
		return
	logo.pivot_offset = logo.size * 0.5
	var logo_y := logo.position.y
	logo.position.y = logo_y - 12.0 * ui_scale
	logo.scale = Vector2(0.96, 0.96)
	logo.modulate.a = 0.0
	var tween := game.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(logo, "position:y", logo_y, 0.34)
	tween.tween_property(logo, "scale", Vector2.ONE, 0.36)
	tween.tween_property(logo, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC)
	_track_tween(tween)


func _animate_settings(settings: Control) -> void:
	if settings == null:
		return
	settings.pivot_offset = settings.size * 0.5
	settings.scale = Vector2(0.92, 0.92)
	settings.modulate.a = 0.0
	var tween := game.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings, "scale", Vector2.ONE, 0.28).set_delay(0.10)
	tween.tween_property(settings, "modulate:a", 1.0, 0.20).set_delay(0.10).set_trans(Tween.TRANS_CUBIC)
	_track_tween(tween)


func _set_final_topbar_state(logo: Control, settings: Control, indicator: Control) -> void:
	for control in [logo, settings, indicator]:
		if control != null:
			control.modulate.a = 1.0
			control.scale = Vector2.ONE


func _track_tween(tween: Tween) -> void:
	if tween == null:
		return
	screen_tweens.append(tween)
	tween.finished.connect(func() -> void: screen_tweens.erase(tween))


func _cancel_page_motion() -> void:
	for tween in screen_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	screen_tweens.clear()

func _reduced() -> bool:
	return game == null or game._ui_motion_reduced()
