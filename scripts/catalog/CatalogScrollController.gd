extends RefCounted
class_name CatalogScrollController

const SCROLL_FRICTION := 7.0
const TAP_THRESHOLD := 14.0
const INERTIA_MIN_SPEED := 40.0

var game: Node


func _init(owner: Node) -> void:
	game = owner


func handle_gui_input(event: InputEvent) -> void:
	if game.current_screen != "topics" and game.current_screen != "levels":
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var wheel_step: float = 160.0 * float(game._topics_ui_scale()) * maxf(mouse_event.factor, 0.25)
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			impulse_scroll(-wheel_step)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			impulse_scroll(wheel_step)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				begin_drag()
			else:
				end_drag(mouse_event.position)
	elif event is InputEventMouseMotion:
		if game.topics_drag_active:
			update_drag(event as InputEventMouseMotion)
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		stop_inertia()
		scroll_to(game.topics_scroll_offset + pan.delta.y * 14.0 * game._topics_ui_scale())


func begin_drag() -> void:
	stop_inertia()
	game.topics_drag_active = true
	game.topics_drag_total = Vector2.ZERO
	game.topics_drag_last_msec = Time.get_ticks_msec()


func update_drag(motion: InputEventMouseMotion) -> void:
	game.topics_drag_total += motion.relative
	var now := Time.get_ticks_msec()
	var elapsed := maxf(0.001, float(now - game.topics_drag_last_msec) / 1000.0)
	game.topics_drag_last_msec = now
	game.topics_scroll_velocity = -motion.relative.y / elapsed
	scroll_to(game.topics_scroll_offset - motion.relative.y)


func end_drag(screen_pos: Vector2) -> void:
	if not game.topics_drag_active:
		return
	game.topics_drag_active = false
	if game.topics_drag_total.length() <= TAP_THRESHOLD * game._topics_ui_scale() * 0.5:
		game.topics_scroll_velocity = 0.0
		activate_item_at(screen_pos)
		return
	if absf(game.topics_scroll_velocity) >= INERTIA_MIN_SPEED * 3.0:
		game.topics_inertia_active = true
		game.set_process(true)
	else:
		game.topics_scroll_velocity = 0.0


func activate_item_at(screen_pos: Vector2) -> void:
	var content_pos: Vector2 = screen_pos + Vector2(0.0, game.topics_scroll_offset)
	for item in game.topics_island_items:
		var rect: Rect2 = item["rect"]
		if rect.has_point(content_pos):
			var action = item.get("action", null)
			if action is Callable and action.is_valid():
				action.call()
			return


func scroll_to(target: float) -> void:
	game.topics_scroll_offset = clampf(target, 0.0, max_scroll())
	apply_scroll()


func max_scroll() -> float:
	return maxf(0.0, game.topics_content_height - game.get_viewport_rect().size.y)


func apply_scroll() -> void:
	if game.topics_content != null and is_instance_valid(game.topics_content):
		game.topics_content.position.y = -game.topics_scroll_offset
	if game.current_screen == "levels":
		refresh_level_cards()


func refresh_level_cards() -> void:
	if game.topics_content == null or not is_instance_valid(game.topics_content):
		return
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var visible_top := maxf(0.0, game.topics_scroll_offset - game.level_virtual_overscan)
	var visible_bottom: float = game.topics_scroll_offset + viewport_size.y + game.level_virtual_overscan
	var required: Dictionary = {}
	for index in game.level_virtual_items.size():
		var item: Dictionary = game.level_virtual_items[index]
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.end.y < visible_top or rect.position.y > visible_bottom:
			continue
		required[index] = true
		if game.level_virtual_nodes.has(index):
			continue
		var card: Control = game._level_grid_card(
			item.get("topic", {}),
			item.get("level", {}),
			bool(item.get("unlocked", false)),
			float(item.get("card_width", rect.size.x)),
			float(item.get("ui_scale", 1.0)),
		)
		card.position = rect.position
		game.topics_content.add_child(card)
		game.level_virtual_nodes[index] = card
		if bool(item.get("animate_unlock", false)):
			game._animate_new_unlock_card(card, item.get("topic", {}), float(item.get("card_width", rect.size.x)))
			item["animate_unlock"] = false
	for index in game.level_virtual_nodes.keys():
		if required.has(index):
			continue
		var card: Control = game.level_virtual_nodes[index]
		game.level_virtual_nodes.erase(index)
		if is_instance_valid(card):
			card.queue_free()


func impulse_scroll(distance: float) -> void:
	game.topics_scroll_velocity += distance * SCROLL_FRICTION
	game.topics_inertia_active = true
	game.set_process(true)


func stop_inertia() -> void:
	game.topics_inertia_active = false
	game.topics_scroll_velocity = 0.0
	game.set_process(false)


func process(delta: float) -> void:
	if not game.topics_inertia_active or (game.current_screen != "topics" and game.current_screen != "levels"):
		stop_inertia()
		return
	var previous: float = game.topics_scroll_offset
	scroll_to(game.topics_scroll_offset + game.topics_scroll_velocity * delta)
	game.topics_scroll_velocity *= maxf(0.0, 1.0 - SCROLL_FRICTION * delta)
	if absf(game.topics_scroll_velocity) < INERTIA_MIN_SPEED or is_equal_approx(previous, game.topics_scroll_offset):
		stop_inertia()
