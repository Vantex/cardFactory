class_name DesktopLayout
extends RefCounted

const REFERENCE_SIZE := Vector2(1152, 648)

static func metrics(viewport_size: Vector2, preferences: Dictionary) -> Dictionary:
	var automatic := clampf(minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y), 0.85, 4.0)
	var font := automatic * float(preferences.font_scale)
	var width_factor := automatic * sqrt(float(preferences.font_scale))
	var authored: bool = is_equal_approx(automatic, 1.0) and is_equal_approx(float(preferences.font_scale), 1.0) and preferences.density == "compact"
	return {
		"automatic_scale": automatic,
		"font_scale": font,
		"left_width": roundf(clampf(216 * width_factor, 170, viewport_size.x * 0.25)),
		"right_width": roundf(clampf(286 * width_factor, 220, viewport_size.x * 0.30)),
		"top_height": 52.0 if authored else ceilf(maxf(52 * automatic, 34 * font + 28 * automatic)),
		"dock_height": 92.0 if authored else ceilf(maxf(92 * automatic, 56 * font + 28 * automatic)),
		"gap": roundf(10 * automatic),
		"authored": authored,
	}
