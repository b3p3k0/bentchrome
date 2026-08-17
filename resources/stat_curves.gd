class_name StatCurves
extends RefCounted
## 1-20 design scale -> engine units through 20-slot per-axis tables — the
## single place to retune global feel. Odd slots 1..19 sit exactly on the
## legacy 1-10 line (old v <-> new 2v-1, bit-exact; tests/test_stat_rebase.gd
## holds the proof), even slots are new in-between values, and slot 20
## extrapolates one half-step of headroom. A mid car (slot 9) lands on the
## hand-tuned baseline; cars scale around it. handling drives both turn rate
## and grip; armor drives HP.
##
## MPH is the tuning vocabulary (ui/hud.gd MPH_PER_PXS 0.15): TOP_SPEED
## slot 1 = 54.0 mph, +2.33 mph per slot, slot 19 = 96.0 mph, slot 20 = 98.3.
## special_power has no table yet — display-only today, reserved as the
## future special-effectiveness axis (tuning pass). Specials break the rules
## by design; these tables are the envelope, not a leash.

const SCALE_MAX := 20

static var TOP_SPEED := _build(360.0, 640.0)    # px/s
# Base pull is deliberately low: launch_boost carries the standing start and
# accel_taper thins the pull near top (mid car ~3.5s to top, not the old 0.6s).
static var ACCELERATION := _build(80.0, 365.0)  # px/s^2
static var TURN_RATE := _build(130.0, 250.0)    # deg/s
static var GRIP := _build(4.5, 10.0)            # lateral bleed 1/s
static var HP := _build(70.0, 180.0)
static var LAUNCH := _build(0.7, 1.4)           # x launch_boost; mass-derived
												# default = slot 21 - 2*engine_mass

## Legacy-anchored generator: lerp over (s-1)/18 puts every odd slot exactly
## on the old (v-1)/9 ramp ((2x)/(2y) divides bit-identically), so the
## migrated fleet's engine values cannot move. The tuning pass may replace a
## generated table with hand-authored MPH-round literals; consumers only ever
## see the table.
static func _build(lo: float, hi: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(SCALE_MAX + 1)  # slot 0 unused; the author scale is 1-based
	for s in range(1, SCALE_MAX + 1):
		out[s] = lerpf(lo, hi, (float(s) - 1.0) / 18.0)
	return out

static func _slot(table: PackedFloat64Array, v: int) -> float:
	return table[clampi(v, 1, SCALE_MAX)]

static func apply(stats: VehicleStats, controller, health) -> void:
	controller.max_speed = _slot(TOP_SPEED, stats.top_speed)
	controller.acceleration = _slot(ACCELERATION, stats.acceleration)
	controller.turn_rate_deg = _slot(TURN_RATE, stats.handling)
	controller.lateral_grip = _slot(GRIP, stats.handling)
	# The controller's mass knob keeps its native 1-10 scale (F1 slider and
	# direct-constructed tests speak it); authored 1-20 folds down, odd exact.
	controller.mass = (float(stats.mass) + 1.0) / 2.0
	# launch 0 = "derive from mass" sentinel (driving_controller keeps the
	# legacy shove); authored torque decouples dead-stop pull from mass.
	controller.launch_factor = _slot(LAUNCH, stats.launch) if stats.launch >= 1 else 0.0
	# Slide-move identity: the per-car trim on the handbrake-180 rate rides the
	# same seam as every other stats->controller knob (Goliath curve swaps and
	# the F1 bench inherit it for free).
	controller.whip_scale = stats.whip_scale
	if health:
		var hp := _slot(HP, stats.armor)
		health.max_hp = hp
		health.hp = hp
