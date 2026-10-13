extends RefCounted
## Mounts the persistent board inside its page so every layer shares page motion.

var _host: Node2D
var _parent: Node
var _transform := Transform2D.IDENTITY
var _z_index := 0


func mount(host: Node2D, slot: Node2D) -> void:
	if host == _host:
		return
	release()
	_host = host
	_parent = host.get_parent()
	_transform = host.transform
	_z_index = host.z_index
	host.reparent(slot, false)
	host.transform = Transform2D.IDENTITY
	# Include the board frame's negative local Z in the page's CanvasGroup.
	host.z_index = 64


func release() -> void:
	if is_instance_valid(_host) and is_instance_valid(_parent):
		_host.reparent(_parent, false)
		_host.transform = _transform
		_host.z_index = _z_index
	_host = null
	_parent = null
