class_name AudioPalette
extends RefCounted
## Newly generated ElevenLabs recordings, processed for short, quiet feedback.

const MUSIC_PATH := "res://assets/audio/music/soft_tabletop.ogg"
const CUES := {
	&"tap": {"file": "ui_tap", "gain": -4.0, "gap": 90, "family": &"ui"},
	&"page": {"file": "page_turn", "gain": -5.0, "gap": 140, "family": &"motion"},
	&"theme": {"file": "theme_glide", "gain": -5.0, "gap": 140, "family": &"motion"},
	&"pickup": {"file": "piece_pickup", "gain": -7.0, "gap": 100, "family": &"piece"},
	&"drop": {"file": "piece_drop", "gain": -5.0, "gap": 100, "family": &"piece"},
	&"snap": {"file": "piece_snap", "gain": -1.0, "gap": 120, "family": &"piece"},
	&"swap": {"file": "tile_swap", "gain": -3.0, "gap": 120, "family": &"piece"},
	&"hint": {"file": "hint", "gain": -3.0, "gap": 600, "family": &"accent"},
	&"complete": {"file": "complete", "gain": 0.0, "gap": 1000, "family": &"accent"},
}


static func cue_path(kind: StringName) -> String:
	return "res://assets/audio/sfx/%s.wav" % CUES[kind].file


static func music_gain(route: StringName) -> float:
	match route:
		&"gameplay":
			return 1.0
		&"completion", &"settings":
			return -5.0
	return 3.0
