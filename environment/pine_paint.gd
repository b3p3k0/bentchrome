extends RefCounted
## Shared snow-pine silhouette. Full-size Clutter and the tiny pit-bottom
## landmarks call the same painter so their size difference carries depth.

const TRUNK := Color(0.25, 0.18, 0.12)
const SHADOW := Color(0.01, 0.02, 0.025, 0.32)
const PINE_DARK := Color(0.025, 0.19, 0.075)
const PINE_MID := Color(0.035, 0.36, 0.12)
const PINE_LIGHT := Color(0.12, 0.5, 0.19)
const SNOW := Color(0.9, 0.96, 1.0)
const FAR_DARK := Color(0.035, 0.12, 0.08)
const FAR_MID := Color(0.045, 0.21, 0.1)
const FAR_LIGHT := Color(0.09, 0.28, 0.12)
const FAR_SNOW := Color(0.52, 0.62, 0.72)

static func paint(canvas: CanvasItem, center: Vector2, radius: float, seed: int,
		distant := false) -> void:
	radius = maxf(radius, 2.5)
	var dark: Color = FAR_DARK if distant else PINE_DARK
	var mid: Color = FAR_MID if distant else PINE_MID
	var light: Color = FAR_LIGHT if distant else PINE_LIGHT
	var snow: Color = FAR_SNOW if distant else SNOW
	var shadow_offset := Vector2(radius * 0.18, radius * 0.24)
	canvas.draw_colored_polygon(_crown(center + shadow_offset, radius * 1.03,
		seed + 91, 0.1), SHADOW)
	canvas.draw_circle(center + Vector2(0.0, radius * 0.08), radius * 0.16, TRUNK)
	canvas.draw_colored_polygon(_crown(center, radius, seed, 0.0), dark)
	canvas.draw_colored_polygon(_crown(center + Vector2(-radius * 0.07, -radius * 0.08),
		radius * 0.72, seed + 17, 0.22), mid)
	canvas.draw_colored_polygon(_crown(center + Vector2(-radius * 0.11, -radius * 0.15),
		radius * 0.43, seed + 37, -0.16), light)
	# Snow sits on the lit northwest boughs at every scale. Three restrained
	# clumps survive the one-sixth-size pit treatment without becoming noise.
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.28),
		radius * 0.15, snow)
	canvas.draw_circle(center + Vector2(radius * 0.05, -radius * 0.43),
		radius * 0.12, snow)
	canvas.draw_circle(center + Vector2(-radius * 0.12, -radius * 0.08),
		radius * 0.1, snow)

static func _crown(center: Vector2, radius: float, seed: int,
		rotation: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points := PackedVector2Array()
	for i in 16:
		var tooth: float = 1.0 if i % 2 == 0 else 0.74
		var wobble: float = rng.randf_range(0.92, 1.08)
		var angle: float = rotation + TAU * float(i) / 16.0
		points.append(center + Vector2.RIGHT.rotated(angle) * radius * tooth * wobble)
	return points
