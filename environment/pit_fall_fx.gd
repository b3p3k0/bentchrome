class_name PitFallFX
extends Node2D
## Tiny bottom-of-the-canyon punctuation: a distant hot star and dust ring.
## It owns no particles, light, shake, damage, or sound; Vehicle times it to
## the muted thud already baked into pit_fall.

const HOT := Color(1.0, 0.92, 0.55)
const ORANGE := Color(1.0, 0.48, 0.12)
const SMOKE := Color(0.25, 0.23, 0.25)

static var LIFETIME := 0.32
static var MAX_RADIUS := 20.0

var _age := 0.0

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		queue_free()

func _draw() -> void:
	var f: float = clampf(_age / maxf(LIFETIME, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - f
	var radius: float = lerpf(3.0, MAX_RADIUS, 1.0 - (1.0 - f) * (1.0 - f))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(ORANGE, fade),
		1.0 + 2.0 * fade)
	if f < 0.48:
		var flash_f: float = f / 0.48
		var flash_radius: float = lerpf(4.0, MAX_RADIUS * 0.72, flash_f)
		draw_colored_polygon(_star(flash_radius, flash_radius * 0.38),
			Color(HOT, 1.0 - flash_f))
	# Four restrained dust motes make the mark read as a tiny faraway impact,
	# never a normal car-sized explosion.
	for i in 4:
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 4.0 + 0.32)
		var mote_at: Vector2 = direction * radius * (0.55 + 0.08 * float(i % 2))
		draw_circle(mote_at, lerpf(2.4, 0.5, f), Color(SMOKE, fade * 0.75))

func _star(outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16:
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 16.0) * radius)
	return points
