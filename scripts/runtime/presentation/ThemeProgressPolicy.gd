class_name ThemeProgressPolicy
extends RefCounted


static func build(completed_levels: int, total_levels: int) -> Dictionary:
	var safe_total := maxi(0, total_levels)
	var safe_completed := clampi(completed_levels, 0, safe_total)
	var ratio := float(safe_completed) / float(safe_total) if safe_total > 0 else 0.0
	var is_complete := safe_total > 0 and safe_completed == safe_total
	return {
		"completed_levels": safe_completed,
		"total_levels": safe_total,
		"ratio": ratio,
		"paw_count": paw_count_for_ratio(ratio),
		"is_complete": is_complete,
	}


static func paw_count_for_ratio(ratio: float) -> int:
	var safe_ratio := clampf(ratio, 0.0, 1.0)
	if safe_ratio <= 0.0:
		return 0
	if safe_ratio <= 0.2:
		return 1
	if safe_ratio <= 0.4:
		return 2
	if safe_ratio <= 0.6:
		return 3
	if safe_ratio <= 0.8:
		return 4
	return 5
