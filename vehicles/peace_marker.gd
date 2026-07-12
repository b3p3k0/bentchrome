extends Node2D
## The purple peace symbol hanging over a disarmed car (Chill Out, Man).
## Pure paint: parented to the axis-aligned DriveFX so it stays upright while
## the car spins beneath it; DriveFX toggles visibility off is_disarmed().

const RADIUS := 9.0
const COLOR := Color(0.66, 0.36, 0.9)
const PULSE_RATE := 4.0

var _t := 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	modulate.a = 0.65 + 0.35 * sin(_t * PULSE_RATE)
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, COLOR, 2.2)
	draw_line(Vector2(0, -RADIUS), Vector2(0, RADIUS), COLOR, 2.2)
	var fork := RADIUS * 0.72
	draw_line(Vector2.ZERO, Vector2(-fork, fork), COLOR, 2.2)
	draw_line(Vector2.ZERO, Vector2(fork, fork), COLOR, 2.2)
