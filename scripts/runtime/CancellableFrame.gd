extends RefCounted
## Wait for one zero-argument frame signal, or synchronously stop on cancellation.


class Gate:
	extends RefCounted
	signal resolved(value: bool)

	var done := false
	var value := false
	var _frame: Signal
	var _cancel: Signal

	func arm(frame_signal: Signal, cancel_signal: Signal) -> void:
		_frame = frame_signal
		_cancel = cancel_signal
		if _frame.is_null() or _cancel.is_null() or _frame == _cancel:
			_finish(false)
			return
		if _frame.connect(_on_frame) != OK:
			_finish(false)
			return
		if _cancel.connect(_on_cancel) != OK:
			_finish(false)

	func _on_frame() -> void:
		_finish(true)

	func _on_cancel() -> void:
		_finish(false)

	func _finish(result: bool) -> void:
		if done:
			return
		done = true
		value = result
		# Resume only after cleanup: the waiter may free owners or start another wait.
		if not _frame.is_null() and _frame.is_connected(_on_frame):
			_frame.disconnect(_on_frame)
		if not _cancel.is_null() and _cancel.is_connected(_on_cancel):
			_cancel.disconnect(_on_cancel)
		_frame = Signal()
		_cancel = Signal()
		resolved.emit(result)


static func wait(frame_signal: Signal, cancel_signal: Signal) -> bool:
	var gate := Gate.new()
	gate.arm(frame_signal, cancel_signal)
	if gate.done:
		return gate.value
	return await gate.resolved
