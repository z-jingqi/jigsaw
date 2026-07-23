class_name CompletionRuntimeHost
extends RefCounted

const CompletionModalScene := preload("res://scenes/modals/CompletionModal.tscn")
const ViewModels := preload("res://scripts/runtime/presentation/AppViewModels.gd")

var game: Node
var modal: Control


func _init(owner: Node) -> void:
	game = owner


func show(view_model: ViewModels.CompletionViewModel) -> void:
	clear()
	modal = CompletionModalScene.instantiate() as Control
	game.modal_root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.connect(&"confirm_requested", _on_confirm_requested)
	modal.connect(&"dismissed", _on_dismissed)
	game.current_modal = "complete"
	game.modal_open = true
	modal.call(&"navigation_enter", {"view_model": view_model}, {"reduced_motion": game.progress_store.reduced_motion_enabled()})


func request_close() -> void:
	if is_instance_valid(modal):
		modal.call(&"request_dismiss")


func clear() -> void:
	if not is_instance_valid(modal):
		return
	modal.call(&"navigation_exit", {})
	modal.queue_free()
	modal = null


func shutdown() -> void:
	clear()
	game = null


func _on_confirm_requested(_event_id: String) -> void:
	clear()
	game.current_modal = ""
	game.modal_open = false
	game._return_to_current_level_list()


func _on_dismissed(_event_id: String) -> void:
	clear()
	game.current_modal = ""
	game.modal_open = false
