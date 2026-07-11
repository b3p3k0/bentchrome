extends Control
## Windshield speed streaks: thin vertical lines whipping south past the play
## square once the run gets properly fast — density and reach ramp from
## THRESHOLD to a full-tilt read at FULL. Pure overlay, ignores the mouse.

const VehiclesHelper := preload("res://vehicles/vehicles.gd")

static var THRESHOLD := 480.0   # px/s where the streaks fade in
static var FULL := 640.0        # px/s of maximum streak intensity

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
	var speed: float = player.get_speed()
	if speed < THRESHOLD:
		return
	var k := clampf((speed - THRESHOLD) / (FULL - THRESHOLD), 0.0, 1.0)
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
