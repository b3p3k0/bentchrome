extends PlayerDriver
## The forced-scroll pace pedal: you can speed up or slow down, never stop.
## W is flat out, hands off settles at cruise, and S eases the car down to a
## floor and HOLDS it there — no standstill, no reverse gear. Every lift is a
## trade: the pack's pace sits between cruise and top, so slowing for a
## chicane spends gap you have to earn back. The band is governed here
## (speed_band.gd) because the controller's throttle is an acceleration
## scalar. STEERING IS A LANE CHANGE, not a turn: this isn't an open arena —
## L/R swings the nose at most LANE_YAW_DEG off the ROAD'S heading and the
## car slides across the lanes; hands off, the nose settles onto the road,
## so a sweeper steers itself and you only pick where on it you ride. The
## handbrake (a 180° whip in the arenas) has no business here and is eaten.
## Weapons and boost pass straight through.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

static var LANE_YAW_DEG := 24.0   # the most the nose swings off the road's heading (one 16-step tilt)
static var LANE_GAIN := 4.0       # steer authority per radian of heading error
static var ROAD_LEAD := 120.0     # px up the road the wheel reads the heading from

const NORTH := -PI / 2.0

var _host: Node = null

## The lane-change wheel: `axis` (-1 left .. +1 right) picks a heading inside
## the yaw cone around `road` and the steer output is what carries the nose
## there — and back onto the road at zero. Pure, shared with the autopilot.
static func lane_steer(heading: float, axis: float, road := NORTH, max_yaw_deg := LANE_YAW_DEG,
		gain := LANE_GAIN) -> float:
	var want := road + clampf(axis, -1.0, 1.0) * deg_to_rad(max_yaw_deg)
	return clampf(angle_difference(heading, want) * gain, -1.0, 1.0)

## The road's heading at course distance d (chase_course.sample): the
## centreline's slope over a short reach, so a sweeper reads as "straight" to
## the lane wheel. NORTH without a course (bare fixtures).
static func road_heading(course, d: float) -> float:
	if course == null:
		return NORTH
	var a: Dictionary = course.sample(d - 60.0)
	var b: Dictionary = course.sample(d + 60.0)
	return Vector2(float(b["x"]) - float(a["x"]), -120.0).angle()

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	var road := road_heading(_course(vehicle), -vehicle.global_position.y + ROAD_LEAD)
	intent["steer"] = lane_steer(vehicle.heading, float(intent.get("steer", 0.0)), road)
	intent["handbrake"] = false
	var ctrl = vehicle.get_controller() if vehicle.has_method(&"get_controller") else null
	var top := SpeedBand.road_top(vehicle)
	var boosting: bool = intent.get("boost", false) and ctrl != null \
		and "boost_fuel" in ctrl and ctrl.boost_fuel > 0.0
	var forward := Vector2.RIGHT.rotated(vehicle.heading)
	var fwd_speed: float = vehicle.velocity.dot(forward)
	intent["throttle"] = SpeedBand.pedal(intent["throttle"], fwd_speed, top, boosting)
	return intent

## The course, duck-typed off the chase host (group &"chase_host"); null in
## bare fixtures, where the wheel simply reads north.
func _course(vehicle):
	if _host == null or not is_instance_valid(_host):
		_host = vehicle.get_tree().get_first_node_in_group(&"chase_host")
	return _host.course if _host != null and "course" in _host else null
