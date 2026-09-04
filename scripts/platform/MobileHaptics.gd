extends RefCounted
class_name MobileHaptics

const LOCKED_PULSE_INTERVAL_MS := 80
const LIGHT_DURATION_MS := 32
const LIGHT_AMPLITUDE := 0.58
const PICKUP_DURATION_MS := 52
const PICKUP_AMPLITUDE := 0.82
const LOCKED_DURATION_MS := 34
const LOCKED_AMPLITUDE := 0.72
const CONFIRM_DURATION_MS := 90
const CONFIRM_AMPLITUDE := 1.0
const ANDROID_VIBRATION_EFFECT_API := 26
const ANDROID_AMPLITUDE_MAX := 255

var _generation := 0


func play(kind: String) -> void:
	# Completion has no extra pulse: the final placement already confirms success.
	# A near-target preview or an unsuccessful drop is not a successful placement.
	if kind not in ["button", "locked", "pickup", "snap", "swap"]:
		return
	_generation += 1
	_play_pulse(kind, 1)
	if kind != "locked":
		return
	var tree := Engine.get_main_loop() as SceneTree
	var ticket := _generation
	if tree == null:
		return
	tree.create_timer(LOCKED_PULSE_INTERVAL_MS / 1000.0, true, false, true).timeout.connect(
		func() -> void:
			if ticket != _generation or not DisplayServer.window_is_focused():
				return
			_play_pulse(kind, 2)
	)


func _play_pulse(kind: String, pulse: int) -> void:
	var duration_ms := LIGHT_DURATION_MS
	var amplitude := LIGHT_AMPLITUDE
	if kind == "pickup":
		duration_ms = PICKUP_DURATION_MS
		amplitude = PICKUP_AMPLITUDE
	elif kind == "locked":
		duration_ms = LOCKED_DURATION_MS
		amplitude = LOCKED_AMPLITUDE
	elif kind == "snap" or kind == "swap":
		duration_ms = CONFIRM_DURATION_MS
		amplitude = CONFIRM_AMPLITUDE
	if _play_android_vibration(kind, pulse, duration_ms, amplitude):
		return
	Input.vibrate_handheld(duration_ms, amplitude)
	if OS.is_debug_build():
		print(
			"JIGCAT_HAPTIC ",
			(
				JSON
				. stringify(
					{
						"kind": kind,
						"duration_ms": duration_ms,
						"amplitude": amplitude,
						"pulse": pulse,
						"driver": "direct",
					}
				)
			)
		)


func _play_android_vibration(kind: String, pulse: int, duration_ms: int, amplitude: float) -> bool:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	var context = runtime.getApplicationContext()
	if context == null:
		return false
	var vibrator = context.getSystemService("vibrator")
	if vibrator == null or not vibrator.hasVibrator():
		return false
	var sdk_version = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if int(sdk_version.SDK_INT) >= ANDROID_VIBRATION_EFFECT_API:
		var vibration_effect = JavaClassWrapper.wrap("android.os.VibrationEffect")
		var effect = vibration_effect.createOneShot(
			duration_ms, clampi(roundi(amplitude * ANDROID_AMPLITUDE_MAX), 1, ANDROID_AMPLITUDE_MAX)
		)
		vibrator.vibrate(effect)
	else:
		vibrator.vibrate(duration_ms)
	if OS.is_debug_build():
		print(
			"JIGCAT_HAPTIC ",
			(
				JSON
				. stringify(
					{
						"kind": kind,
						"duration_ms": duration_ms,
						"amplitude": amplitude,
						"pulse": pulse,
						"driver": "android_vibrator",
					}
				)
			)
		)
	return true


func cancel_pending() -> void:
	_generation += 1
