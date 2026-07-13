extends Node2D
## The ice-blue snowflake hanging over a frozen car (Chilblain).
## Pure paint: parented to the axis-aligned DriveFX so it stays upright while
## the car sits iced beneath it; DriveFX toggles visibility off is_frozen().

const RADIUS := 9.0
const COLOR := Color(0.72, 0.9, 1.0)
const PULSE_RATE := 4.0

var _t := 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	modulate.a = 0.65 + 0.35 * sin(_t * PULSE_RATE)
	queue_redraw()

func _draw() -> void:
	for i in 3:  # six arms = three crossed spokes
		var dir := Vector2.RIGHT.rotated(TAU * i / 6.0)
		draw_line(-dir * RADIUS, dir * RADIUS, COLOR, 2.0)
		for s in [-1.0, 1.0]:
			var side: float = s
			var barb := dir.rotated(side * TAU / 6.0) * RADIUS * 0.4
			draw_line(dir * RADIUS * 0.55, dir * RADIUS * 0.55 + barb, COLOR, 1.4)
			draw_line(-dir * RADIUS * 0.55, -(dir * RADIUS * 0.55 + barb), COLOR, 1.4)
