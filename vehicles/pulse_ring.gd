extends Node2D
## Pulse Wave's expanding neon ring, drawn exactly at the live damage front —
## the telegraph and the hitbox can never disagree (the tornado-swirl rule).
## Pure paint: SpecialController owns the lifecycle and feeds radius/range
## per tick; parented to the LEVEL at the cast position (the wave detaches
## from the caster, who hops away mid-blast).

const FACE_COLOR := Color(0.22, 1.0, 0.42)      # neon green
const UNDER_COLOR := Color(0.03, 0.12, 0.05)    # dark under-ring: readable anywhere
const AFTERGLOW := Color(0.5, 1.0, 0.65)

var radius := 0.0  # the live damage front
var range_px := 270.0  # full reach — drives the fade-out

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if radius <= 1.0:
		return
	var t := clampf(radius / maxf(range_px, 1.0), 0.0, 1.0)
	var fade := 1.0 - t * 0.65  # still visible when it dies at the rim
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(UNDER_COLOR, 0.8 * fade), 7.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(FACE_COLOR, 0.95 * fade), 3.5)
	if radius > 24.0:  # trailing afterglow ring inside the front
		draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 40,
			Color(AFTERGLOW, 0.35 * fade), 2.0)
