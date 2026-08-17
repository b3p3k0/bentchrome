class_name DrivingController
extends Node
## Arcade "steer-to-drive" physics. Reads {throttle, steer} intent and updates
## the host vehicle's velocity + heading, scaled by the current terrain. Tuning
## is exposed as inspector knobs; per-vehicle data (StatCurves) will feed these.

@export_group("Speed")
@export var max_speed := 520.0
@export var reverse_max_speed := 180.0
@export var acceleration := 207.0        # base pull; launch_boost carries the low end
@export var brake_deceleration := 570.0  # S pedal: mid car stops from top in ~0.9s
@export var coast_deceleration := 260.0  # lift-off falloff; mass stretches/shrinks it
@export_range(0.0, 0.95) var accel_taper := 0.65  # pull lost as speed nears top
@export var launch_boost := 1.6          # extra shove below 30% of top speed
@export var launch_factor := 0.0         # authored torque (StatCurves LAUNCH): >0 scales
										 # launch_boost directly; 0 = derive from mass

@export_group("Steering")
@export var turn_rate_deg := 190.0
@export var turn_authority_speed := 150.0
@export_range(0.0, 1.0) var min_turn_authority := 0.12

@export_group("Grip")
@export var lateral_grip := 7.5

@export_group("Handbrake")
@export var handbrake_deceleration := 400.0        # gentler than the S pedal
@export_range(0.0, 1.0) var handbrake_grip_factor := 0.15  # rear end breaks loose
## The whip (handbrake 180): breaking loose at speed multiplies the steer rate
## — light cars whip quick, heavies swing slow. Entry gated on whip_min_speed;
## the latch keeps a started whip alive while the slide bleeds.
@export var whip_min_speed := 240.0
@export var whip_turn_light := 2.4  # steer-rate multiplier at mass 1
@export var whip_turn_heavy := 1.4  # steer-rate multiplier at mass 10

@export_group("Straighten")
## Post-corner recenter: the slip breathes for straighten_delay after steering
## ends, then lateral grip multiplies up (kills the crab) and heading eases onto
## the 16-step visual grid (sprite snaps to steps; a between-step heading LOOKS
## straight while tracking off — the "bad alignment" feel).
@export var straighten_delay := 0.35
@export var straighten_grip_factor := 3.0
@export var straighten_snap_rate_deg := 80.0

@export_group("Mass")
@export_range(1.0, 10.0) var mass := 5.0  # engine 1-10 knob (authored 1-20 mass folds
										  # down via StatCurves); shapes launch/coast/brake

@export_group("Boost")
@export var boost_top_factor := 1.5
@export var boost_accel_factor := 2.0
@export var boost_burn_rate := 5.0  # units per second held (full tank = 20s)

var boost_fuel := 100.0  # 0..100; no recharge — resets with the scene
var boosting := false    # state flags for cosmetic FX (drive_fx.gd) — set each apply()
var handbraking := false
var service_braking := false  # opposing pedal while still rolling; brake-light paint
var _no_steer_t := 0.0   # time since the last steer/handbrake input
var _whip_active := false  # latched per slide: a started whip finishes even
						   # as the slide bleeds below the entry gate

## Per-surface multipliers on acceleration, top speed, and grip. road = baseline.
## static var (not const): const dictionaries are deep-frozen in Godot 4, and
## the dev tuning deck mutates these values live. Same class-level access.
static var TERRAIN := {
	&"road": {"accel": 1.0, "top": 1.0, "grip": 1.0, "steer": 1.0},
	&"grass": {"accel": 0.9, "top": 0.9, "grip": 0.8, "steer": 1.0},
	&"snow": {"accel": 0.85, "top": 0.9, "grip": 0.45, "steer": 1.0},
	&"dirt": {"accel": 0.8, "top": 0.85, "grip": 0.6, "steer": 1.0},
	&"mud": {"accel": 0.55, "top": 0.60, "grip": 0.42, "steer": 0.90},
	&"ice": {"accel": 0.55, "top": 1.0, "grip": 0.08, "steer": 1.2},
	&"water": {"accel": 0.4, "top": 0.45, "grip": 0.7, "steer": 1.0},
	}

## The one composition seam for every driver and every ride. Vehicle-specific
## identity is data; the controller never branches on roster ids or factions.
static func effective_terrain(vehicle, surface: StringName) -> Dictionary:
	var base: Dictionary = TERRAIN.get(surface, TERRAIN[&"road"])
	var out := {
		"accel": float(base.get("accel", 1.0)),
		"top": float(base.get("top", 1.0)),
		"grip": float(base.get("grip", 1.0)),
		"steer": float(base.get("steer", 1.0)),
	}
	var stats: Variant = vehicle.get("stats") if vehicle != null and "stats" in vehicle else null
	if stats is VehicleStats:
		for property in [&"accel", &"top", &"grip", &"steer"]:
			out[property] *= stats.terrain_factor(surface, property)
	return out

func apply(vehicle, intent: Dictionary, delta: float) -> void:
	var throttle: float = clampf(intent.get("throttle", 0.0), -1.0, 1.0)
	var steer: float = clampf(intent.get("steer", 0.0), -1.0, 1.0)
	var handbrake: bool = intent.get("handbrake", false)

	var mod: Dictionary = effective_terrain(vehicle, vehicle.current_terrain)
	var accel: float = acceleration * mod["accel"]
	var top: float = max_speed * mod["top"]
	var grip: float = lateral_grip * mod["grip"]
	if handbrake:
		grip *= handbrake_grip_factor  # traction breaks loose — the drift tool
	var scale: float = vehicle.get_speed_scale() if vehicle.has_method(&"get_speed_scale") else 1.0
	accel *= scale
	top *= scale

	# Boost: hold to burn the tank (no recharge) for extra shove and headroom.
	boosting = intent.get("boost", false) and boost_fuel > 0.0
	handbraking = handbrake
	if boosting:
		boost_fuel = maxf(boost_fuel - boost_burn_rate * delta, 0.0)
		accel *= boost_accel_factor
		top *= boost_top_factor

	var forward := Vector2.RIGHT.rotated(vehicle.heading)
	var fwd_speed: float = vehicle.velocity.dot(forward)
	var speed: float = vehicle.velocity.length()
	# Service brakes speak in signed travel, not key names: S while rolling
	# forward, W while reversing. At the crawl threshold the pedal becomes drive
	# in the other direction, so the lamps go dark before acceleration crosses 0.
	service_braking = not handbrake and ((throttle < 0.0 and fwd_speed > 10.0)
		or (throttle > 0.0 and fwd_speed < -10.0))

	# Straighten assist: hands off the wheel long enough -> recenter. The slip
	# gets its grace period first (corner exits still breathe), then the crab
	# dies fast and the heading settles onto the visual grid.
	if absf(steer) > 0.05 or handbrake:
		_no_steer_t = 0.0
	else:
		_no_steer_t += delta
	var straightening: bool = _no_steer_t >= straighten_delay and absf(fwd_speed) > 30.0
	if straightening:
		grip *= straighten_grip_factor

	# Steering authority grows with speed (you must roll to turn).
	var authority := clampf(speed / turn_authority_speed, min_turn_authority, 1.0)
	var dir_sign := signf(fwd_speed) if absf(fwd_speed) > 5.0 else 1.0
	# Mass factor hoisted above steering — the whip scales by it; the mass
	# shaping block below is unchanged.
	var mf := clampf((mass - 1.0) / 9.0, 0.0, 1.0)
	# The whip (handbrake 180): latch on a fast handbrake, release on letting
	# go (or the slide dying outright). While the handbrake is out, dir_sign
	# pins to 1 — mid-slide the travel sign flips under the car, and without
	# the pin a held whip counter-steers itself back at ~90°. Steer means
	# "rotate the nose the way you push", travel be damned.
	if handbrake and speed >= whip_min_speed:
		_whip_active = true
	elif not handbrake or speed < whip_min_speed * 0.25:
		_whip_active = false
	var whip := 1.0
	if handbrake:
		dir_sign = 1.0
		if _whip_active:
			whip = lerpf(whip_turn_light, whip_turn_heavy, mf)
	vehicle.heading += deg_to_rad(turn_rate_deg) * float(mod["steer"]) * scale \
		* steer * authority * dir_sign * whip * delta
	if straightening and "HEADING_STEPS" in vehicle and vehicle.HEADING_STEPS > 0:
		var step: float = TAU / vehicle.HEADING_STEPS
		vehicle.heading = rotate_toward(vehicle.heading, snappedf(vehicle.heading, step),
			deg_to_rad(straighten_snap_rate_deg) * delta)
	forward = Vector2.RIGHT.rotated(vehicle.heading)

	# Mass (1-10) shapes the dynamics: heavy = weak launch, long coast, soft
	# brakes; light = jumps off the line, sheds speed on lift, bites when braking.
	var accel_mass := lerpf(1.3, 0.5, mf)
	# Standing-start shove: authored launch_factor wins (torque decoupled from
	# mass — a loaded HMMWV can still pull from a dead stop); 0 keeps the
	# mass-derived default.
	var boost_top := launch_factor * launch_boost if launch_factor > 0.0 \
		else lerpf(launch_boost * 1.4, launch_boost * 0.7, mf)
	var boost := lerpf(maxf(boost_top, 1.0), 1.0, clampf(fwd_speed / maxf(top * 0.3, 1.0), 0.0, 1.0))
	var taper := 1.0 - accel_taper * clampf(fwd_speed / maxf(top, 1.0), 0.0, 1.0)
	var accel_eff := accel * accel_mass * boost * taper
	var brake_eff := brake_deceleration * lerpf(1.2, 0.8, mf)
	var coast_eff := coast_deceleration * lerpf(1.35, 0.65, mf)

	# Throttle / brake / reverse along the nose. A held handbrake overrides
	# the pedals: gentle forward decel while the car slides on dead grip.
	if handbrake:
		var eased_hb := move_toward(fwd_speed, 0.0, handbrake_deceleration * delta)
		vehicle.velocity += forward * (eased_hb - fwd_speed)
	elif throttle > 0.0:
		vehicle.velocity += forward * accel_eff * throttle * delta
	elif throttle < 0.0:
		if fwd_speed > 10.0:
			vehicle.velocity -= forward * brake_eff * delta
		else:
			vehicle.velocity += forward * accel_eff * throttle * delta
	else:
		var eased := move_toward(fwd_speed, 0.0, coast_eff * delta)
		vehicle.velocity += forward * (eased - fwd_speed)

	# Lateral grip: bleed sideways velocity for predictable drift.
	var right := forward.orthogonal()
	var lat_speed: float = vehicle.velocity.dot(right)
	var lat_retain := clampf(1.0 - grip * delta, 0.0, 1.0)
	vehicle.velocity -= right * lat_speed * (1.0 - lat_retain)

	# Clamp forward speed. `top` is the hard physical ceiling BOTH ways;
	# reverse_max_speed prices POWERED reverse only (the S gear, and the AI's
	# unstick reverse-out). A backward-facing SLIDE — post-whip momentum,
	# shoves, flings — keeps its speed and decays through coast/handbrake
	# decel + lateral grip instead of a one-tick chop. (S alone during a
	# backward slide still engages reverse gear and its cap — unchanged.)
	fwd_speed = vehicle.velocity.dot(forward)
	var cap := top
	if fwd_speed < 0.0 and throttle < 0.0 and not handbrake:
		cap = reverse_max_speed
	if absf(fwd_speed) > cap:
		vehicle.velocity -= forward * (fwd_speed - signf(fwd_speed) * cap)
