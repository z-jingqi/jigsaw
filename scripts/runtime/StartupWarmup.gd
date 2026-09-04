class_name StartupWarmup
extends RefCounted

const LevelsScene := preload("res://scenes/screens/LevelListScreen.tscn")


func prepare(
	host: Control, content: ContentRepository, catalog: CatalogPresenter, on_progress: Callable
) -> void:
	var topics := content.topics()
	var tree := host.get_tree()
	for index in topics.size():
		var screen := LevelsScene.instantiate() as RuntimeLevelListScreen
		host.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.navigation_enter(
			{"view_model": catalog.level_list(str(topics[index].id))}, {"reduced_motion": true}
		)
		# Render under the opaque loading layer to prepare fonts and GPU materials too.
		await tree.process_frame
		while is_instance_valid(screen) and not screen.is_content_ready():
			await tree.process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		screen.queue_free()
		if on_progress.is_valid():
			on_progress.call(float(index + 1) / float(topics.size()))
		await tree.process_frame
