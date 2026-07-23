class_name ThemeCard
extends ActionButton

@onready var title_label: Label = $Margin/Content/Title
@onready var progress_label: Label = $Margin/Content/Progress

var theme_id := ""

func _ready() -> void:
	kind = Kind.CARD
	super._ready()

func set_view_model(view_model: Variant) -> void:
	theme_id = str(view_model.get("theme_id"))
	title_label.text = str(view_model.get("title"))
	var progress = view_model.get("progress")
	progress_label.text = str(progress.get("accessibility_text"))
	tooltip_text = "%s, %s" % [title_label.text, progress_label.text]
	accessibility_name = tooltip_text
