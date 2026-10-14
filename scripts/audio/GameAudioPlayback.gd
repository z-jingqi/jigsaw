class_name GameAudioPlayback
extends Node
## Owns preloaded recordings, bounded voices, settings, and application suspension.

signal activity_changed(active: bool)

const Palette := preload("res://scripts/audio/AudioPalette.gd")
const EFFECT_VOICES := 4
const SILENT_DB := -70.0

var _settings: SettingsRepository
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _accent: AudioStreamPlayer
var _completion: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_motion: Tween
var _effect_motion: Tween
var _completion_motion: Tween
var _route := &"home"
var _music_enabled := true
var _effects_enabled := true
var _focused := true
var _suspended := false
var _last_family: Dictionary = {}
var _last_cue: Dictionary = {}
var _played: Dictionary = {}
var _suppressed := 0
var _stopped := false


func configure(settings: SettingsRepository) -> void:
	_settings = settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	for kind in Palette.CUES:
		_streams[kind] = load(Palette.cue_path(kind)) as AudioStream
	for index in EFFECT_VOICES:
		var player := _new_player("Effect%d" % index)
		_voices.append(player)
	_accent = _new_player("Accent")
	_completion = _new_player("Completion")
	_music = _new_player("Music")
	if ResourceLoader.exists(Palette.MUSIC_PATH):
		var track := load(Palette.MUSIC_PATH) as AudioStreamOggVorbis
		if track != null:
			track.loop = true
			_music.stream = track
			_music.volume_db = SILENT_DB
	_settings.changed.connect(_on_settings_changed)
	_on_settings_changed(_settings.snapshot(), _settings.revision())


func shutdown() -> void:
	_stopped = true
	if _settings != null and _settings.changed.is_connected(_on_settings_changed):
		_settings.changed.disconnect(_on_settings_changed)
	_settings = null
	_stop_motion(_music_motion)
	_stop_motion(_effect_motion)
	_stop_motion(_completion_motion)
	for player in _all_players():
		player.stop()


func set_context(route: StringName) -> void:
	if _route == route:
		return
	if _route == &"completion" and route != &"completion" and _completion.playing:
		_stop_motion(_completion_motion)
		_completion_motion = create_tween()
		_completion_motion.tween_property(_completion, "volume_db", SILENT_DB, 0.15)
		_completion_motion.tween_callback(_completion.stop)
	_route = route
	_sync_music()


func play(kind: StringName) -> bool:
	if _stopped or not _effects_enabled or not _active() or not _streams.has(kind):
		return false
	var cue: Dictionary = Palette.CUES[kind]
	var now := Time.get_ticks_msec()
	var family: StringName = cue.family
	if (
		now - int(_last_cue.get(kind, -10000)) < int(cue.gap)
		or (family == &"ui" and now - int(_last_family.get(family, -10000)) < 75)
		or (kind != &"complete" and _route == &"completion")
	):
		_suppressed += 1
		return false
	var player := _available_voice(kind)
	if player == null or _streams[kind] == null:
		_suppressed += 1
		return false
	_last_cue[kind] = now
	_last_family[family] = now
	player.stream = _streams[kind]
	player.volume_db = float(cue.gain)
	player.pitch_scale = 1.0
	player.play()
	_played[kind] = int(_played.get(kind, 0)) + 1
	return true


func snapshot() -> Dictionary:
	var active_voices := 0
	for player in _voices:
		active_voices += 1 if player.playing else 0
	return {
		"loaded_cues": _streams.keys(),
		"music_available": _music != null and _music.stream != null,
		"music_enabled": _music_enabled,
		"effects_enabled": _effects_enabled,
		"music_playing": _music != null and _music.playing,
		"music_paused": _music != null and _music.stream_paused,
		"music_position": _music.get_playback_position() if _music != null else 0.0,
		"music_gain": _music.volume_db if _music != null else SILENT_DB,
		"active_voices": active_voices,
		"accent_playing": _accent != null and _accent.playing,
		"completion_playing": _completion != null and _completion.playing,
		"active": _active(),
		"route": String(_route),
		"played": _played.duplicate(),
		"suppressed": _suppressed,
	}


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
		NOTIFICATION_APPLICATION_PAUSED:
			_suspended = true
		NOTIFICATION_APPLICATION_RESUMED:
			_suspended = false
		_:
			return
	if _music == null or _stopped:
		return
	if not _active():
		_stop_motion(_music_motion)
		_stop_motion(_effect_motion)
		_stop_motion(_completion_motion)
		_music.stream_paused = true
		_music.volume_db = SILENT_DB
		for player in _effect_players():
			player.stop()
	else:
		_sync_music()
	activity_changed.emit(_active())


func _on_settings_changed(value: Dictionary, _revision: int) -> void:
	_music_enabled = bool(value.get("music_enabled", true))
	_effects_enabled = bool(value.get("sound_effects_enabled", true))
	_stop_motion(_effect_motion)
	if not _effects_enabled:
		_effect_motion = create_tween().set_parallel(true)
		for player in _effect_players():
			_effect_motion.tween_property(player, "volume_db", SILENT_DB, 0.04)
		_effect_motion.chain().tween_callback(_stop_effects)
	_sync_music()


func _sync_music() -> void:
	if _music == null or _music.stream == null or _stopped:
		return
	_stop_motion(_music_motion)
	if not _active():
		_music.stream_paused = true
		return
	if _music_enabled:
		# Paused playback stays active; resume it instead of starting the song again.
		if not _music.has_stream_playback():
			_music.play()
		_music.stream_paused = false
		_music_motion = create_tween()
		_music_motion.tween_property(_music, "volume_db", Palette.music_gain(_route), 0.45)
	else:
		_music_motion = create_tween()
		_music_motion.tween_property(_music, "volume_db", SILENT_DB, 0.2)
		_music_motion.tween_callback(func() -> void: _music.stream_paused = true)


func _available_voice(kind: StringName) -> AudioStreamPlayer:
	if kind == &"complete":
		return _completion if not _completion.playing else null
	if kind == &"hint":
		if _accent.playing:
			return null
		return _accent
	for player in _voices:
		if not player.playing:
			return player
	return null


func _new_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.mix_target = AudioStreamPlayer.MIX_TARGET_STEREO
	add_child(player)
	return player


func _stop_effects() -> void:
	for player in _effect_players():
		player.stop()


func _active() -> bool:
	return _focused and not _suspended


func _effect_players() -> Array[AudioStreamPlayer]:
	var result := _voices.duplicate()
	if _accent != null:
		result.append(_accent)
	if _completion != null:
		result.append(_completion)
	return result


func _all_players() -> Array[AudioStreamPlayer]:
	var result := _effect_players()
	if _music != null:
		result.append(_music)
	return result


func _stop_motion(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
