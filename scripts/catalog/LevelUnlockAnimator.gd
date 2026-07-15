extends RefCounted
class_name LevelUnlockAnimator

var game: Node


func _init(owner: Node) -> void:
	game = owner


func animate(card: Control, topic: Dictionary, card_width: float) -> void:
	if game._ui_motion_reduced():
		return
	var card_height := card_width * 4.0 / 3.0
	var topic_color: Color = game._topic_color(topic)
	var radius := int(card_width * 0.07)
	var overlay := Control.new()
	overlay.name = "unlock_reveal_overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._add_level_card_back(overlay, topic, topic_color, card_width, card_height, radius)
	card.add_child(overlay)
	var back_image: Image = await render_card_back_snapshot(topic, topic_color, card_width, card_height, radius)
	if not is_instance_valid(card) or not card.is_inside_tree() or not is_instance_valid(overlay):
		return
	game.unlock_reveal_effect.animate(card, overlay, back_image, card_width, card_height, game.unlock_effect_style)


func render_card_back_snapshot(topic: Dictionary, topic_color: Color, card_width: float, card_height: float, radius: int) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(maxi(2, int(card_width)), maxi(2, int(card_height)))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var holder := Control.new()
	holder.size = Vector2(card_width, card_height)
	viewport.add_child(holder)
	game._add_level_card_back(holder, topic, topic_color, card_width, card_height, radius)
	game.add_child(viewport)
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return null
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image
