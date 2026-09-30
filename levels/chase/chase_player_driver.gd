extends PlayerDriver
## The forced-scroll pace pedal: you can speed up or slow down, never stop.
## W is flat out, hands off settles at cruise, and S eases the car down to a
## floor and HOLDS it there — no standstill, no reverse gear. Every lift is a
## trade: the pack's pace sits between cruise and top, so slowing for a
## chicane spends gap you have to earn back. The band is governed here
## (speed_band.gd) because the controller's throttle is an acceleration
## scalar. STEERING IS A LANE CHANGE, not a turn: this isn't an open arena —
## L/R swings the nose at most LANE_YAW_DEG off straight north and the car
## slides across the lanes; hands off, the nose comes back to north. A
## sweeper is YOURS to drive: the cone is wider than any bend on the course,
## so holding part of it is the perfect line and full lock cuts the apex.
## The handbrake (a 180° whip in the arenas) has no business here and is
## eaten. Weapons and boost pass straight through.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

static var LANE_YAW_DEG := 24.0   # the most the nose swings off north (one 16-step tilt; the course's sweepers bend ~18°)
static var LANE_GAIN := 4.0       # steer authority per radian of heading error

const NORTH := -PI / 2.0

## The lane-change wheel: `axis` (-1 left .. +1 right) picks a heading inside
## the yaw cone and the steer output is what carries the nose there — and
## back to north at zero. Pure, shared with the autopilot probe.
static func lane_steer(heading: float, axis: float, max_yaw_deg := LANE_YAW_DEG,
		gain := LANE_GAIN) -> float:
	var want := NORTH + clampf(axis, -1.0, 1.0) * deg_to_rad(max_yaw_deg)
	return clampf(angle_difference(heading, want) * gain, -1.0, 1.0)

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	intent["steer"] = lane_steer(vehicle.heading, float(intent.get("steer", 0.0)))
	intent["handbrake"] = false
	var ctrl = vehicle.get_controller() if vehicle.has_method(&"get_controller") else null
	var top := SpeedBand.road_top(vehicle)
	var boosting: bool = intent.get("boost", false) and ctrl != null \
		and "boost_fuel" in ctrl and ctrl.boost_fuel > 0.0
	var forward := Vector2.RIGHT.rotated(vehicle.heading)
	var fwd_speed: float = vehicle.velocity.dot(forward)
	intent["throttle"] = SpeedBand.pedal(intent["throttle"], fwd_speed, top, boosting)
	return intent
