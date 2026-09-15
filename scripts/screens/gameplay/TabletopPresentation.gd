class_name TabletopPresentation
extends TextureRect
## Select the quiet tabletop for gameplay, including its modal overlays.

const CalmTexture := preload("res://assets/ui/gameplay/tabletop-calm.webp")
const ShanhaiTexture := preload("res://assets/ui/gameplay/shanhai-landscape.webp")
const TopAlignedCoverShader := preload("res://shaders/ui/top_aligned_cover.gdshader")

@export var navigator_path: NodePath

@onready var _navigator: AppNavigator = get_node(navigator_path)
@onready var _default_texture: Texture2D = texture
@onready var _default_material: Material = material
@onready var _default_stretch_mode := stretch_mode

var _shanhai_material: ShaderMaterial


func _ready() -> void:
	_shanhai_material = ShaderMaterial.new()
	_shanhai_material.shader = TopAlignedCoverShader
	_navigator.route_changed.connect(_on_route_changed)
	resized.connect(_refresh_cover_aspect)
	_refresh.call_deferred()


func _on_route_changed(_route: StringName, _payload: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var entry := _navigator.current_screen_entry()
	if entry.get("route", &"") != &"gameplay":
		_apply_standard_background(_default_texture)
		return
	var payload: Dictionary = entry.get("payload", {})
	if str(payload.get("theme_id", "")) == "topic_01":
		texture = ShanhaiTexture
		stretch_mode = TextureRect.STRETCH_SCALE
		material = _shanhai_material
		_refresh_cover_aspect()
	else:
		_apply_standard_background(CalmTexture)


func _apply_standard_background(value: Texture2D) -> void:
	texture = value
	stretch_mode = _default_stretch_mode
	material = _default_material


func _refresh_cover_aspect() -> void:
	if material != _shanhai_material or texture == null or size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	_shanhai_material.set_shader_parameter("rect_aspect", size.x / size.y)
	_shanhai_material.set_shader_parameter("texture_aspect", texture_size.x / texture_size.y)
