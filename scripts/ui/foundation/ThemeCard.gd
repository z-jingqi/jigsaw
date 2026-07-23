class_name ThemeCard
extends ActionButton

@onready var cover: TextureRect = $Margin/Content/Cover
@onready var title_label: Label = $Margin/Content/Title
@onready var progress: ThemeProgress = $Margin/Content/Progress

var theme_id := ""
var _view_model: Variant


func _ready() -> void:
	kind = Kind.CARD
	super._ready()
	if _view_model != null:
		_apply_view_model()


func set_view_model(view_model: Variant) -> void:
	_view_model = view_model
	if is_node_ready():
		_apply_view_model()


func source_rect() -> Rect2:
	return get_global_rect()


func set_information_visible(is_visible: bool) -> void:
	$Margin/Content.visible = is_visible


func _apply_view_model() -> void:
	theme_id = str(_read("theme_id"))
	title_label.text = str(_read("title"))
	cover.texture = _read("cover_texture") as Texture2D
	progress.set_view_model(_read("progress"))
	tooltip_text = "%s, %s" % [title_label.text, str(_read_progress_text())]
	accessibility_name = tooltip_text


func _read_progress_text() -> String:
	var value: Variant = _read("progress")
	if value == null:
		return "0 / 0"
	if value is Dictionary:
		return str(value.get("accessibility_text", "0 / 0"))
	return str(value.accessibility_text)


func _read(field: String, fallback: Variant = null) -> Variant:
	if _view_model is Dictionary:
		return _view_model.get(field, fallback)
	return _view_model.get(field) if _view_model != null else fallback
