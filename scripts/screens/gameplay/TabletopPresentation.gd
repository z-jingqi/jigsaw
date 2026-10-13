class_name TabletopPresentation
extends TextureRect
## Use the home page background for every gameplay theme and its modal overlays.

const Style := preload("res://scripts/screens/gameplay/GameplayStyle.gd")

@export var navigator_path: NodePath

@onready var _navigator: AppNavigator = get_node(navigator_path)
@onready var _default_texture: Texture2D = texture
@onready var _default_material: Material = material
@onready var _default_stretch_mode := stretch_mode


func _ready() -> void:
	_navigator.route_changed.connect(_on_route_changed)
	_navigator.input_lock_changed.connect(func(_locked: bool): _refresh())
	_refresh.call_deferred()


func _on_route_changed(_route: StringName, _payload: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var entry := _navigator.current_screen_entry()
	if entry.get("route", &"") != &"gameplay":
		_apply_standard_background(_default_texture)
		return
	_apply_standard_background(Style.Background)
	stretch_mode = TextureRect.STRETCH_SCALE


func _apply_standard_background(value: Texture2D) -> void:
	texture = value
	stretch_mode = _default_stretch_mode
	material = _default_material
