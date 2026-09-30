extends Driver
## A Buzzard in the finale (the bridge is out). Two roles, cast by the
## finale director:
##
##   brake  — pull over to the shoulder and stop short of the bank: the
##            chase is over and it knows it. (A Vehicle can stop; only the
##            chase brain's pace floor ever forbade it.)
##   jump   — follow the car up the deck, never passing it, force a set
##            speed on the deck so the launch lip throws it a set distance —
##            short. It lands in the channel and the river takes it.
##
## Nobody fires. Preloads siblings by path (no bare class_name in the chase
## stack); duck-types the vehicle like every chase driver.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

static var BIKE_JUMP_SPEED := 480.0   # px/s forced on the deck: 1.17s of air = 561px, short of the far bank
static var TRAIL_DY := 260.0          # px behind the player a jumper follows
static var STOP_AHEAD := 40.0         # px short of the bank a braker's stop mark sits
static var BRAKE_ZONE := 250.0        # px from its stop mark a braker goes to the brakes
static var SHOULDER_IN := 110.0       # px inside the road edge a braker pulls over to
const LOOKAHEAD := 240.0
const STEER_GAIN := 2.2
const CENTER_GAIN := 3.0              # jumpers: lateral px/s per px off the deck's centre
const CENTER_MAX := 120.0

var role: StringName = &"brake"
var side := 1.0                       # which shoulder a braker takes
var _course = null
var _stop_y := 0.0                    # brakers: world y of the stop mark
var _deck_y := 0.0                    # jumpers: world y where the deck starts (forcing begins)
var _forcing := false

func setup(course, stop_y: float, deck_y: float, p_role: StringName, p_side := 1.0) -> void:
	_course = course
	_stop_y = stop_y
	_deck_y = deck_y
	role = p_role
	side = p_side

## On the deck and in the air a jumper owns its velocity outright: the
## controller's clamp and drag must not shorten a launch that has to fall short.
func is_forcing() -> bool:
	return _forcing

func get_intent(vehicle, delta: float) -> Dictionary:
	var own: Vector2 = vehicle.global_position
	var s: Dictionary = _course.sample(-own.y) if _course != null else {"x": own.x, "half_w": 360.0}
	var cx: float = s["x"]
	var half: float = s["half_w"]
	var fwd := _fwd(vehicle)
	var intent := super(vehicle, delta)
	if role == &"jump":
		if not _forcing and own.y <= _deck_y:
			_forcing = true
		if _forcing:
			# The deck and the air: a set speed north, a gentle pull to the centre.
			var vx := clampf((cx - own.x) * CENTER_GAIN, -CENTER_MAX, CENTER_MAX)
			if vehicle.get("height") != null and float(vehicle.get("height")) > 0.0:
				vx = 0.0
			vehicle.velocity = Vector2(vx, -BIKE_JUMP_SPEED)
			vehicle.set("heading", -PI / 2.0)
			return intent
		# Following: on the player's tail, never past it.
		var player := vehicle.get_tree().get_first_node_in_group(&"player") as Node2D
		var mark_y: float = own.y - 400.0
		var ask: float = _top(vehicle)
		if player != null and is_instance_valid(player):
			mark_y = player.global_position.y + TRAIL_DY
			var pv: Variant = player.get("velocity")
			var pvn: float = -pv.y if pv is Vector2 else ask
			if own.y < mark_y:
				ask = maxf(pvn - 60.0, BIKE_JUMP_SPEED)
		intent["throttle"] = SpeedBand.toward(fwd, ask, true)
		intent["steer"] = _steer_to(vehicle, Vector2(cx, own.y - LOOKAHEAD))
		return intent
	# Braking: over to the shoulder, and stop before the bank.
	var mark: float = _stop_y + STOP_AHEAD
	var left: float = own.y - mark   # px of road left before the stop mark (+ = still short)
	var want: float = 0.0 if left < BRAKE_ZONE else _top(vehicle) * 0.8
	intent["throttle"] = SpeedBand.toward(fwd, want, true)
	var lane_x := cx + side * (half - SHOULDER_IN)
	intent["steer"] = _steer_to(vehicle, Vector2(lane_x, own.y - LOOKAHEAD)) if fwd > 30.0 else 0.0
	return intent

func _fwd(vehicle) -> float:
	var vv: Variant = vehicle.get("velocity")
	if vv is Vector2:
		return vv.dot(Vector2.RIGHT.rotated(vehicle.heading))
	return 0.0

func _top(vehicle) -> float:
	if vehicle.has_method(&"get_controller") and vehicle.get_controller() != null:
		return vehicle.get_controller().max_speed
	return 500.0

func _steer_to(vehicle, point: Vector2) -> float:
	var want: float = (point - vehicle.global_position).angle()
	return clampf(angle_difference(vehicle.heading, want) * STEER_GAIN, -1.0, 1.0)
