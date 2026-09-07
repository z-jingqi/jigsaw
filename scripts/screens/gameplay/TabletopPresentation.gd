class_name TabletopPresentation
extends TextureRect
## Select the quiet tabletop for gameplay, including its modal overlays.

const CalmTexture := preload("res://assets/ui/gameplay/tabletop-calm.webp")

@export var navigator_path: NodePath

@onready var _navigator: AppNavigator = get_node(navigator_path)
@onready var _default_texture: Texture2D = texture


func _ready() -> void:
	_navigator.route_changed.connect(_on_route_changed)
	_refresh.call_deferred()


func _on_route_changed(_route: StringName, _payload: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var gameplay: bool = _navigator.current_screen_entry().get("route", &"") == &"gameplay"
	texture = CalmTexture if gameplay else _default_texture
