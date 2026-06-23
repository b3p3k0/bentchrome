class_name DrivingController
extends Node
## Arcade "steer-to-drive" physics. Reads {throttle, steer} intent and updates
## the host vehicle's velocity + heading, scaled by the current terrain. Tuning
## is exposed as inspector knobs; per-vehicle data (StatCurves) will feed these.

@export_group("Speed")
@export var max_speed := 520.0
@export var reverse_max_speed := 180.0
@export var acceleration := 900.0
@export var brake_deceleration := 1500.0
@export var coast_deceleration := 420.0

@export_group("Steering")
@export var turn_rate_deg := 190.0
@export var turn_authority_speed := 150.0
@export_range(0.0, 1.0) var min_turn_authority := 0.12

@export_group("Grip")
@export var lateral_grip := 7.5

## Per-surface multipliers on acceleration, top speed, and grip. road = baseline.
const TERRAIN := {
	&"road": {"accel": 1.0, "top": 1.0, "grip": 1.0},
	&"dirt": {"accel": 0.8, "top": 0.85, "grip": 0.6},
	&"ice": {"accel": 0.9, "top": 1.0, "grip": 0.16},
	&"water": {"accel": 0.4, "top": 0.45, "grip": 0.7},
}

func apply(vehicle, intent: Dictionary, delta: float) -> void:
	var throttle: float = clampf(intent.get("throttle", 0.0), -1.0, 1.0)
	var steer: float = clampf(intent.get("steer", 0.0), -1.0, 1.0)

	var mod: Dictionary = TERRAIN.get(vehicle.current_terrain, TERRAIN[&"road"])
	var accel: float = acceleration * mod["accel"]
	var top: float = max_speed * mod["top"]
	var grip: float = lateral_grip * mod["grip"]

	var forward := Vector2.RIGHT.rotated(vehicle.heading)
	var fwd_speed: float = vehicle.velocity.dot(forward)
	var speed: float = vehicle.velocity.length()

	# Steering authority grows with speed (you must roll to turn).
	var authority := clampf(speed / turn_authority_speed, min_turn_authority, 1.0)
	var dir_sign := signf(fwd_speed) if absf(fwd_speed) > 5.0 else 1.0
	vehicle.heading += deg_to_rad(turn_rate_deg) * steer * authority * dir_sign * delta
	forward = Vector2.RIGHT.rotated(vehicle.heading)

	# Throttle / brake / reverse along the nose.
	if throttle > 0.0:
		vehicle.velocity += forward * accel * throttle * delta
	elif throttle < 0.0:
		if fwd_speed > 10.0:
			vehicle.velocity -= forward * brake_deceleration * delta
		else:
			vehicle.velocity += forward * accel * throttle * delta
	else:
		var eased := move_toward(fwd_speed, 0.0, coast_deceleration * delta)
		vehicle.velocity += forward * (eased - fwd_speed)

	# Lateral grip: bleed sideways velocity for predictable drift.
	var right := forward.orthogonal()
	var lat_speed: float = vehicle.velocity.dot(right)
	var lat_retain := clampf(1.0 - grip * delta, 0.0, 1.0)
	vehicle.velocity -= right * lat_speed * (1.0 - lat_retain)

	# Clamp forward speed (separate caps for forward and reverse).
	fwd_speed = vehicle.velocity.dot(forward)
	var cap := top if fwd_speed >= 0.0 else reverse_max_speed
	if absf(fwd_speed) > cap:
		vehicle.velocity -= forward * (fwd_speed - signf(fwd_speed) * cap)
