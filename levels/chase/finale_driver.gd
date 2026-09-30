extends Driver
## The locked-in player (the bridge is out). From the moment the clock runs
## out the car is the show's: APPROACH centres it on the road and governs it
## to LAUNCH_SPEED with the nitro lit; on the DECK it owns the velocity
## outright (is_forcing: no controller, no drag) so the arc is the numbers'
## and not the car's; at the brink it pops FINALE_VZ and holds the velocity
## through the AIR; LANDED it keeps driving north until the card. Steering
## reuses the chase wheel's cone; nobody fires.

const SpeedBand := preload("res://levels/chase/speed_band.gd")
const Pedal := preload("res://levels/chase/chase_player_driver.gd")

## LAUNCH_SPEED × the airtime of FINALE_VZ is the jump: 700 × (2·860/1300 =
## 1.323s) = 926px from the brink — 300px past the deep channel's kill rect.
static var LAUNCH_SPEED := 700.0
static var FINALE_VZ := 860.0
static var CENTER_GAIN := 4.0     # forcing: lateral px/s per px off the centreline
static var CENTER_MAX := 140.0

enum Stage { APPROACH, DECK, AIR, LANDED }

signal popped                     # the brink: the arc has begun (the camera hands off here)

var stage: int = Stage.APPROACH
var _course = null
var _deck_y := 0.0                # world y where forcing begins
var _brink_y := 0.0               # world y of the pop

func setup(course, deck_y: float, brink_y: float) -> void:
	_course = course
	_deck_y = deck_y
	_brink_y = brink_y

func is_forcing() -> bool:
	return stage != Stage.APPROACH

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	var own: Vector2 = vehicle.global_position
	var cx: float = _course.sample(-own.y)["x"] if _course != null else own.x
	var airborne: bool = vehicle.get("height") != null and float(vehicle.get("height")) > 0.0
	match stage:
		Stage.APPROACH:
			# Centre up and settle on the launch speed, nitro lit for the look.
			intent["steer"] = Pedal.lane_steer(vehicle.heading, clampf((cx - own.x) / 240.0, -1.0, 1.0))
			intent["throttle"] = SpeedBand.toward(_fwd(vehicle), LAUNCH_SPEED, true)
			intent["boost"] = true
			if own.y <= _deck_y and not airborne:
				stage = Stage.DECK
				_force(vehicle, cx, false)   # from this tick on the velocity is ours
		Stage.DECK:
			_force(vehicle, cx, false)
			if own.y <= _brink_y:
				vehicle.velocity = Vector2(0.0, -LAUNCH_SPEED)
				if vehicle.has_method(&"pop_airborne"):
					vehicle.pop_airborne(FINALE_VZ)
				var audio: Node = get_node_or_null(^"/root/AudioDirector") if is_inside_tree() else null
				if audio != null and audio.has_method(&"play"):
					audio.play(&"jump_pad")
				stage = Stage.AIR
				popped.emit()
		Stage.AIR:
			_force(vehicle, cx, true)
			if not airborne:
				stage = Stage.LANDED
		Stage.LANDED:
			_force(vehicle, cx, false)
	return intent

## The forced velocity: LAUNCH_SPEED north, a gentle pull to the centreline
## on the ground and none at all in the air.
func _force(vehicle, cx: float, airborne: bool) -> void:
	var vx := 0.0
	if not airborne:
		vx = clampf((cx - vehicle.global_position.x) * CENTER_GAIN, -CENTER_MAX, CENTER_MAX)
	vehicle.velocity = Vector2(vx, -LAUNCH_SPEED)
	vehicle.set("heading", -PI / 2.0)
	if vehicle.has_method(&"get_controller"):
		var ctrl = vehicle.get_controller()
		if ctrl != null and ctrl.get("boosting") != null:
			ctrl.boosting = true   # the flame stays lit (the controller is skipped while forcing)

func _fwd(vehicle) -> float:
	var vv: Variant = vehicle.get("velocity")
	if vv is Vector2:
		return vv.dot(Vector2.RIGHT.rotated(vehicle.heading))
	return 0.0
