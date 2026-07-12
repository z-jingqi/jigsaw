extends SceneTree

const LevelRepositoryScript := preload("res://scripts/LevelRepository.gd")
const MAX_EDGE := 800
const WEBP_QUALITY := 0.86


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository = LevelRepositoryScript.new()
	var generated := 0
	var skipped := 0
	var failed := 0
	for topic in repository.build_catalog():
		for level in topic.get("levels", []):
			var config := repository.load_level_config(level)
			var source_path := repository.default_level_image_path(config)
			var output_path := repository.level_thumbnail_path(config)
			if source_path.is_empty() or output_path.is_empty():
				skipped += 1
				print("THUMBNAIL_SKIP %s missing_path" % str(level.get("id", "")))
				continue
			var source_file := repository.image_file_path(source_path)
			if not FileAccess.file_exists(source_path) and not FileAccess.file_exists(source_file):
				skipped += 1
				print("THUMBNAIL_SKIP %s source_missing" % str(level.get("id", "")))
				continue
			var image := Image.load_from_file(source_file)
			if image == null or image.is_empty():
				failed += 1
				print("THUMBNAIL_SKIP %s load_failed" % str(level.get("id", "")))
				continue
			var longest_edge := maxi(image.get_width(), image.get_height())
			if longest_edge > MAX_EDGE:
				var ratio := float(MAX_EDGE) / float(longest_edge)
				image.resize(
					maxi(1, roundi(float(image.get_width()) * ratio)),
					maxi(1, roundi(float(image.get_height()) * ratio)),
					Image.INTERPOLATE_LANCZOS
				)
			var error := image.save_webp(repository.image_file_path(output_path), true, WEBP_QUALITY)
			if error != OK:
				failed += 1
				print("THUMBNAIL_SKIP %s save_failed:%d" % [str(level.get("id", "")), error])
				continue
			generated += 1
			print("THUMBNAIL_OK %s %dx%d %s" % [str(level.get("id", "")), image.get_width(), image.get_height(), output_path])
	print("THUMBNAIL_SUMMARY generated=%d skipped=%d failed=%d" % [generated, skipped, failed])
	quit(0 if failed == 0 else 1)
