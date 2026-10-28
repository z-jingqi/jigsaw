extends TextureRect
## Shared silhouette shadow; never baked into artwork or cached 3D pixels.
const ShadowShader := preload("res://scripts/ui/box/BoxShadow.gdshader")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var shadow := ShaderMaterial.new()
	shadow.shader = ShadowShader
	material = shadow
