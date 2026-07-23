extends RefCounted
class_name TopicPagerGesture

const DRAG_THRESHOLD_RATIO := 0.18
const FLING_VELOCITY := 750.0

var game: Node
var controller
var active := false
var total := Vector2.ZERO
var velocity_x := 0.0
var last_usec := 0


func _init(owner: Node, pager_controller) -> void:
	game = owner
	controller = pager_controller


func reset() -> void:
	active = false
	total = Vector2.ZERO
	velocity_x = 0.0
	last_usec = 0
	if game != null:
		game.topics_drag_active = false
		game.topics_drag_total = Vector2.ZERO


func handle_gui_input(event: InputEvent) -> void:
	if game.current_screen != "topics" or controller.track == null or controller.page_count <= 1 or controller.transitioning:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				begin(mouse_event.position)
			else:
				end(mouse_event.position)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			controller.go_relative(-1)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			controller.go_relative(1)
	elif event is InputEventMouseMotion and active:
		drag_by((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			begin(touch.position)
		else:
			end(touch.position)
	elif event is InputEventScreenDrag and active:
		drag_by((event as InputEventScreenDrag).relative)


func begin(_screen_position: Vector2) -> void:
	if controller.track == null or controller.page_count <= 1 or controller.transitioning:
		return
	controller.cancel_transition()
	active = true
	total = Vector2.ZERO
	velocity_x = 0.0
	last_usec = Time.get_ticks_usec()
	game.topics_drag_active = true
	game.topics_drag_total = Vector2.ZERO


func drag_by(delta: Vector2, elapsed_override := -1.0) -> void:
	if not active or controller.track == null:
		return
	var now := Time.get_ticks_usec()
	var elapsed: float = elapsed_override
	if elapsed <= 0.0:
		elapsed = maxf(0.001, float(now - last_usec) / 1000000.0)
	last_usec = now
	total += delta
	game.topics_drag_total = total
	velocity_x = lerpf(velocity_x, delta.x / elapsed, 0.45)
	controller.set_track_x(controller.constrained_track_x(controller.track.position.x + delta.x))


func end(_screen_position: Vector2) -> void:
	if not active or controller.track == null:
		return
	active = false
	game.topics_drag_active = false
	var displacement: float = controller.track.position.x + controller.page_width
	var threshold: float = controller.page_width * DRAG_THRESHOLD_RATIO
	var fling_threshold: float = FLING_VELOCITY * game._topics_ui_scale()
	var direction := 0
	if displacement <= -threshold or velocity_x <= -fling_threshold:
		direction = 1
	elif displacement >= threshold or velocity_x >= fling_threshold:
		direction = -1
	if direction == 0:
		controller.snap_back()
	else:
		controller.settle_relative(direction)


func clear_momentum() -> void:
	total = Vector2.ZERO
	velocity_x = 0.0


func shutdown() -> void:
	reset()
	controller = null
	game = null
