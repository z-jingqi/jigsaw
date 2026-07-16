extends RefCounted
class_name TopicCardMotion

const CARD_ENTRY_RISE := 20.0
const CARD_ENTRY_STAGGER := 0.055
const CARD_ENTRY_DURATION := 0.30
const PRESS_SCALE := Vector2(0.985, 0.985)
const ACTIVATION_DELAY := 0.13
const PROGRESS_DELAY := 0.28
const PROGRESS_DURATION := 0.42

var game: Node
var cards_by_topic: Dictionary = {}
var progress_snapshot: Dictionary = {}
var pending_progress_changes: Dictionary = {}
var active_tweens: Array[Tween] = []
var card_tweens: Dictionary = {}
var entry_card_count := 0
var last_progress_topic_id := ""
var activation_pending := false


func _init(owner: Node) -> void:
	game = owner


func begin_screen(topics: Array[Dictionary]) -> void:
	_cancel_motion()
	cards_by_topic.clear()
	pending_progress_changes.clear()
	entry_card_count = 0
	last_progress_topic_id = ""
	activation_pending = false
	var current_snapshot: Dictionary = {}
	for topic in topics:
		var topic_id := str(topic.get("id", ""))
		if topic_id.is_empty():
			continue
		var done: int = game._topic_available_done_count(topic)
		current_snapshot[topic_id] = done
		if progress_snapshot.has(topic_id):
			var previous_done := int(progress_snapshot[topic_id])
			if done > previous_done:
				pending_progress_changes[topic_id] = {"from": previous_done, "to": done}
	progress_snapshot = current_snapshot


func register_card(card: Control, topic: Dictionary, page_index: int, row_index: int) -> void:
	if card == null:
		return
	var topic_id := str(topic.get("id", ""))
	if topic_id.is_empty():
		return
	card.pivot_offset = card.size * 0.5
	card.set_meta("topic_home_page", page_index)
	cards_by_topic[topic_id] = card
	_animate_decoration_fade(card, row_index)
	if pending_progress_changes.has(topic_id):
		var change: Dictionary = pending_progress_changes[topic_id]
		_animate_progress_change(card, topic_id, int(change.get("from", 0)), int(change.get("to", 0)))
		pending_progress_changes.erase(topic_id)


func unregister_page(page_index: int) -> void:
	var removed_topic_ids: Array[String] = []
	for topic_id_value in cards_by_topic.keys():
		var topic_id := str(topic_id_value)
		var card := _card(topic_id)
		if card == null or int(card.get_meta("topic_home_page", -1)) == page_index:
			removed_topic_ids.append(topic_id)
	for topic_id in removed_topic_ids:
		cards_by_topic.erase(topic_id)
		var tween = card_tweens.get(topic_id, null)
		if tween is Tween and tween.is_valid():
			tween.kill()
		active_tweens.erase(tween)
		card_tweens.erase(topic_id)


func animate_entries(first_page: Control, ui_scale: float) -> void:
	entry_card_count = first_page.get_child_count()
	for row_index in first_page.get_child_count():
		var card := first_page.get_child(row_index) as Control
		if card == null:
			continue
		var final_y := card.position.y
		card.position.y = final_y + CARD_ENTRY_RISE * ui_scale
		card.scale = PRESS_SCALE
		card.modulate.a = 0.0
		var delay := float(row_index) * CARD_ENTRY_STAGGER
		var tween := game.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position:y", final_y, CARD_ENTRY_DURATION).set_delay(delay)
		tween.tween_property(card, "modulate:a", 1.0, 0.24).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTRY_DURATION).set_delay(delay).set_trans(Tween.TRANS_BACK)
		_track_tween(tween)


func set_final_entry_state(first_page: Control) -> void:
	entry_card_count = first_page.get_child_count()
	for child in first_page.get_children():
		if child is Control:
			(child as Control).modulate.a = 1.0
			(child as Control).scale = Vector2.ONE


func press_card(topic_id: String) -> void:
	var card := _card(topic_id)
	if card == null or _reduced() or activation_pending:
		return
	var shadow: Control = card.get_node_or_null("theme_card_shadow")
	var tween := _replace_card_tween(topic_id)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", PRESS_SCALE, 0.08)
	if shadow != null:
		tween.tween_property(shadow, "modulate:a", 0.68, 0.08)


func release_card(topic_id: String, action: Callable) -> void:
	var card := _card(topic_id)
	if activation_pending:
		return
	activation_pending = true
	if card == null or _reduced():
		activation_pending = false
		if action.is_valid():
			action.call()
		return
	_restore_card(topic_id, true)
	var action_tween := game.create_tween()
	action_tween.tween_interval(ACTIVATION_DELAY)
	action_tween.tween_callback(func() -> void:
		activation_pending = false
		if action.is_valid():
			action.call()
	)
	_track_tween(action_tween)


func cancel_card(topic_id: String) -> void:
	if topic_id.is_empty() or activation_pending:
		return
	_restore_card(topic_id, false)


func debug_state() -> Dictionary:
	var valid_cards := 0
	for card in cards_by_topic.values():
		if is_instance_valid(card) and card is Control:
			valid_cards += 1
	return {
		"registered_card_count": valid_cards,
		"entry_card_count": entry_card_count,
		"pending_progress_count": pending_progress_changes.size(),
		"last_progress_topic_id": last_progress_topic_id,
		"activation_pending": activation_pending,
	}


func shutdown() -> void:
	_cancel_motion()
	game = null


func _animate_decoration_fade(card: Control, row_index: int) -> void:
	var decoration: Control = card.get_node_or_null("theme_card_decoration")
	if decoration == null:
		return
	if _reduced():
		decoration.modulate.a = 1.0
		return
	decoration.modulate.a = 0.0
	var tween := game.create_tween()
	tween.tween_property(decoration, "modulate:a", 1.0, 0.24).set_delay(0.18 + float(row_index) * 0.04).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_track_tween(tween)


func _animate_progress_change(card: Control, topic_id: String, from_done: int, to_done: int) -> void:
	var total := int(card.get_meta("topic_progress_total", 0))
	var bar: Panel = card.get_node_or_null("theme_card_progress")
	var fill: Panel = bar.get_node_or_null("progress_fill") if bar != null else null
	if total <= 0 or bar == null or fill == null:
		return
	last_progress_topic_id = topic_id
	_set_progress_visual(card, from_done, total, _progress_width(bar, from_done, total))
	if _reduced():
		_set_progress_visual(card, to_done, total, _progress_width(bar, to_done, total))
		return
	var from_width := _progress_width(bar, from_done, total)
	var to_width := _progress_width(bar, to_done, total)
	var tween := game.create_tween()
	tween.tween_interval(PROGRESS_DELAY)
	tween.tween_method(func(value: float) -> void:
		if not is_instance_valid(card):
			return
		var display_done := lerpf(float(from_done), float(to_done), value)
		_set_progress_visual(card, roundi(display_done), total, lerpf(from_width, to_width, value))
	, 0.0, 1.0, PROGRESS_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fill, "modulate", Color(1.18, 1.08, 0.76, 1.0), 0.10)
	tween.tween_property(fill, "modulate", Color.WHITE, 0.18).set_ease(Tween.EASE_OUT)
	_track_tween(tween)


func _set_progress_visual(card: Control, done: int, total: int, width: float) -> void:
	var bar: Panel = card.get_node_or_null("theme_card_progress")
	var count: Label = card.get_node_or_null("theme_card_progress_count")
	var fill: Panel = bar.get_node_or_null("progress_fill") if bar != null else null
	if bar == null or fill == null:
		return
	fill.visible = done > 0 or width > 0.0
	fill.size = Vector2(clampf(width, 0.0, bar.size.x), bar.size.y)
	if count != null:
		count.text = "%d/%d" % [clampi(done, 0, total), total]


func _progress_width(bar: Control, done: int, total: int) -> float:
	if done <= 0 or total <= 0:
		return 0.0
	var proportional := bar.size.x * clampf(float(done) / float(total), 0.0, 1.0)
	return clampf(maxf(proportional, minf(bar.size.x, bar.size.y)), 0.0, bar.size.x)


func _restore_card(topic_id: String, spring: bool) -> void:
	var card := _card(topic_id)
	if card == null or _reduced():
		return
	var shadow: Control = card.get_node_or_null("theme_card_shadow")
	var tween := _replace_card_tween(topic_id)
	tween.set_trans(Tween.TRANS_BACK if spring else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.15 if spring else 0.12)
	if shadow != null:
		tween.tween_property(shadow, "modulate:a", 1.0, 0.12)


func _card(topic_id: String) -> Control:
	var card = cards_by_topic.get(topic_id, null)
	return card as Control if is_instance_valid(card) and card is Control else null


func _replace_card_tween(topic_id: String) -> Tween:
	var previous = card_tweens.get(topic_id, null)
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := game.create_tween().set_parallel(true)
	card_tweens[topic_id] = tween
	_track_tween(tween)
	return tween


func _track_tween(tween: Tween) -> void:
	if tween == null:
		return
	active_tweens.append(tween)
	tween.finished.connect(func() -> void:
		active_tweens.erase(tween)
		for topic_id in card_tweens.keys():
			if card_tweens[topic_id] == tween:
				card_tweens.erase(topic_id)
				break
	)


func _cancel_motion() -> void:
	for tween in active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	active_tweens.clear()
	card_tweens.clear()


func _reduced() -> bool:
	return game == null or game._ui_motion_reduced()
