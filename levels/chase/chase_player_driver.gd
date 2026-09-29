extends PlayerDriver
## The forced-scroll pace pedal: you can speed up or slow down, never stop.
## W is flat out, hands off settles at cruise, and S eases the car down to a
## floor and HOLDS it there — no standstill, no reverse gear. Every lift is a
## trade: the pack's pace sits between cruise and top, so slowing for a
## chicane spends gap you have to earn back. The band is governed here
## (speed_band.gd) because the controller's throttle is an acceleration
## scalar; steer, weapons, handbrake and boost pass straight through.

const SpeedBand := preload("res://levels/chase/speed_band.gd")

const FALLBACK_TOP := 484.0  # bare fixtures with no controller

func get_intent(vehicle, delta: float) -> Dictionary:
	var intent := super(vehicle, delta)
	var ctrl = vehicle.get_controller() if vehicle.has_method(&"get_controller") else null
	var top: float = ctrl.max_speed if ctrl != null else FALLBACK_TOP
	var boosting: bool = intent.get("boost", false) and ctrl != null \
		and "boost_fuel" in ctrl and ctrl.boost_fuel > 0.0
	var forward := Vector2.RIGHT.rotated(vehicle.heading)
	var fwd_speed: float = vehicle.velocity.dot(forward)
	intent["throttle"] = SpeedBand.pedal(intent["throttle"], fwd_speed, top, boosting)
	return intent
