extends SceneTree

const GameUiMotionScript := preload("res://scripts/app/GameUiMotion.gd")


class TestProgress:
	extends RefCounted

	func reduced_motion_enabled() -> bool:
		return false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(540, 960)
	var host := Node.new()
	root.add_child(host)
	var motion = GameUiMotionScript.new(host, TestProgress.new())
	var button := Button.new()
	button.text = "Test"
	button.size = Vector2(160.0, 72.0)
	host.add_child(button)
	await process_frame

	motion.wire_button(button)
	button.button_down.emit()
	button.button_up.emit()
	button.queue_free()
	await process_frame
	await create_timer(0.2).timeout

	var cleaned_after_free: bool = motion.button_tweens.is_empty()
	motion._animate_button_release(null)
	var accepts_expired_button := true
	var result := {
		"cleaned_after_free": cleaned_after_free,
		"accepts_expired_button": accepts_expired_button,
		"ok": cleaned_after_free and accepts_expired_button,
	}
	print("GAME_UI_MOTION %s" % JSON.stringify(result))
	host.queue_free()
	quit(0 if bool(result["ok"]) else 1)
