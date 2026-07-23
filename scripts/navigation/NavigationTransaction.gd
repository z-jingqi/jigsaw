class_name NavigationTransaction
extends RefCounted

var _commit_callback: Callable
var _cancel_callback: Callable
var _resolved := false


func _init(commit_callback: Callable, cancel_callback: Callable) -> void:
	_commit_callback = commit_callback
	_cancel_callback = cancel_callback


func resolve(committed: bool) -> void:
	if _resolved:
		return
	_resolved = true
	if committed:
		_commit_callback.call()
	else:
		_cancel_callback.call()
