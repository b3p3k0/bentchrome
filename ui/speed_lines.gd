extends Control
## Windshield speed streaks: thin vertical lines whipping south past the play
## square once the run gets properly fast — density and reach ramp from
## THRESHOLD_FRAC to a full-tilt read at FULL_FRAC. Both are fractions of the
## car's OWN honest top on asphalt (SpeedBand.road_top), so the slowest ride
## on the roster reads "flat out" exactly like the fastest: nothing at
## cruise, a whisper flat out, the full windshield on the boost. Pure
## overlay, ignores the mouse.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")

static var THRESHOLD_FRAC := 0.90   # of the car's top: where the streaks fade in
static var FULL_FRAC := 1.35        # of the car's top: maximum streak intensity

## 0 = no streaks, 1 = full tilt, for a speed against a car's top.
static func intensity(speed: float, top: float) -> float:
	if top <= 0.0:
		return 0.0
	return clampf((speed / top - THRESHOLD_FRAC) / (FULL_FRAC - THRESHOLD_FRAC), 0.0, 1.0)

var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var player := VehiclesHelper.local(get_tree())
	if player == null or not player.has_method(&"get_speed"):
		return
	var k := intensity(player.get_speed(), SpeedBand.road_top(player))
	if k <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242  # stable lanes; only the scroll moves
	var n := int(4.0 + k * 10.0)
	for i in n:
		var x := rng.randf_range(6.0, size.x - 6.0)
		var scroll := rng.randf_range(900.0, 1500.0)
		var streak := rng.randf_range(36.0, 90.0) * (0.5 + k)
		var y := fposmod(rng.randf() * size.y + _t * scroll, size.y + streak) - streak
		draw_line(Vector2(x, y), Vector2(x, y + streak),
			Color(1.0, 1.0, 1.0, 0.05 + 0.14 * k), 2.0)
