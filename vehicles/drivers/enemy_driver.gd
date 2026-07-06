class_name EnemyDriver
extends Driver
## Free-for-all combat AI on a pursue/evade skeleton. Behavior is a BLEND of three
## pure archetypes via `mix` = Vector3(aggressor, ambusher, opportunist). Pure
## types are (1,0,0)/(0,1,0)/(0,0,1); any hybrid is a weighted blend of their
## traits — engagement band, flee threshold, flank bias, and target-scoring
## weights all interpolate. So one system covers pure types and every combination.
##
## Pure archetypes:
##   AGGRESSOR   — charges the nearest car, tight band, fights to near-death.
##   AMBUSHER    — nearest car but approaches at a flank angle; hit-and-run.
##   OPPORTUNIST — scores the weakest car highest, hangs back, pounces, flees early.

@export var mix := Vector3(1, 0, 0)  # weights: x=aggressor, y=ambusher, z=opportunist

# Named blends (assign to `mix`). 3 pure + 3 pairs + 1 triple.
const PRESET_BRAWLER := Vector3(1, 0, 0)
const PRESET_FLANKER := Vector3(0, 1, 0)
const PRESET_JACKAL := Vector3(0, 0, 1)
const PRESET_MARAUDER := Vector3(1, 1, 0)   # aggressive flanker
const PRESET_STALKER := Vector3(1, 0, 1)    # brawls, but hunts the weak
const PRESET_PHANTOM := Vector3(0, 1, 1)    # sneaky flanking jackal
const PRESET_WILDCARD := Vector3(1, 1, 1)   # all-rounder

# Pure trait sets, blended by `mix`. [near, far, flee_hp, w_near, w_weak, flank]
const PURE := {
	"agg": {"near": 110.0, "far": 300.0, "flee": 0.10, "w_near": 1.0, "w_weak": 0.0, "flank": 0.0},
	"amb": {"near": 160.0, "far": 420.0, "flee": 0.22, "w_near": 1.0, "w_weak": 0.0, "flank": 1.0},
	"opp": {"near": 260.0, "far": 560.0, "flee": 0.35, "w_near": 0.3, "w_weak": 1.0, "flank": 0.0},
}

enum Mode { PURSUE, EVADE, UNSTICK, CLEAR }
const SCAN := 1200.0
const FIRE_RANGE := 1000.0

# Stuck escape: pinned against a wall/block -> reverse out, then re-engage.
const STUCK_SPEED := 40.0        # slower than this while trying to move = stuck
const STUCK_TRIP := 0.45         # seconds of stuckness before the escape kicks in
const UNSTICK_MIN := 0.5         # always back out at least this long
const UNSTICK_TIME := 1.8        # max back-out (slow heavies need the room)
const UNSTICK_EXIT_SPEED := 140.0  # moving this fast again = free early
const CLEAR_TIME := 2.2          # post-unstick commit: drive to open space
								 # before target logic can steer back in
const CLEAR_DIST := 450.0        # ...or until this far from the pin

# Obstacle feelers: walls + blocks only (mask 2|4) — car contact is gameplay.
const FEELER_MASK := 6
const FEELER_BASE := 200.0        # feeler length at standstill
const FEELER_SPEED_FACTOR := 0.25 # extra length per px/s of speed
const FEELER_ANGLE := deg_to_rad(35.0)
const AVOID_GAIN := 1.5           # steering bias weight

var _near := 140.0
var _far := 340.0
var _flee := 0.15
var _w_near := 1.0
var _w_weak := 0.0
var _flank := 0.0
var _mode: Mode = Mode.PURSUE
var _avoid_bias := 0.0   # last feeler steering bias (also unstick escape hint)
var _blocked := false    # center feeler hit close ahead
var _stuck_t := 0.0
var _unstick_t := 0.0
var _unstick_steer := 0.0  # committed at UNSTICK entry so the swing can't flip sides
var _clear_t := 0.0
var _last_pin := Vector2.INF   # where this escape episode started
var _escape_dir := Vector2.RIGHT  # committed world-space CLEAR direction

## Normalizes a mix and blends the pure trait sets (zero mix = pure aggressor).
static func blend_params(m: Vector3) -> Dictionary:
	var w := m
	var sum := w.x + w.y + w.z
	if sum <= 0.0:
		w = Vector3(1, 0, 0)
		sum = 1.0
	w /= sum
	var out := {}
	for key in ["near", "far", "flee", "w_near", "w_weak", "flank"]:
		out[key] = w.x * PURE["agg"][key] + w.y * PURE["amb"][key] + w.z * PURE["opp"][key]
	return out

func _ready() -> void:
	var p := blend_params(mix)
	_near = p["near"]
	_far = p["far"]
	_flee = p["flee"]
	_w_near = p["w_near"]
	_w_weak = p["w_weak"]
	_flank = p["flank"]

func get_intent(vehicle, delta: float) -> Dictionary:
	var target := _select_target(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_selected": false}

	# Re-arm after running a slot dry (the special recharges back in).
	var rack = vehicle.get_rack() if vehicle.has_method(&"get_rack") else null
	if rack and not rack.can_consume():
		rack.select_first_armed()

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var bearing := to_target.angle()

	_update_feelers(vehicle)

	# Stuck sensing must use ACTUAL displacement, not vehicle.velocity — wedged
	# in a corner, move_and_slide is fully blocked while velocity stays high
	# (400+), so get_speed() lies. get_real_velocity() reports what happened.
	var real_vel: Vector2 = vehicle.get_real_velocity()

	if _mode == Mode.UNSTICK:
		_unstick_t -= delta
		# Early exit only on real FORWARD speed — raw speed would trip on our
		# own reversing (cap 180) and abort the escape almost immediately.
		var fwd_speed: float = real_vel.dot(Vector2.RIGHT.rotated(vehicle.heading))
		# Once the swing has the nose pointing at open space, stop reversing —
		# a fixed timer wastes escape time (or cuts the swing short) depending
		# on how deep the pin was.
		var nose_clear: bool = (UNSTICK_TIME - _unstick_t) >= UNSTICK_MIN and not _blocked
		if _unstick_t <= 0.0 or fwd_speed > UNSTICK_EXIT_SPEED or nose_clear:
			# Don't hand control straight back to pursue/evade — in a corner the
			# flee direction points right back in. Commit to a WORLD direction:
			# from the pin toward us (for a corner pin that's open arena by
			# construction), and drive it until genuinely clear.
			_mode = Mode.CLEAR
			_clear_t = CLEAR_TIME
			_stuck_t = 0.0
			if _last_pin != Vector2.INF:
				_escape_dir = (vehicle.global_position - _last_pin).normalized()
			else:
				_escape_dir = Vector2.RIGHT.rotated(vehicle.heading)
		else:
			return _unstick_intent()

	if _mode == Mode.CLEAR:
		_clear_t -= delta
		var clear_of_pin: bool = _last_pin == Vector2.INF \
			or vehicle.global_position.distance_to(_last_pin) > CLEAR_DIST
		if _clear_t <= 0.0 or clear_of_pin:
			_mode = Mode.PURSUE
		else:
			if _update_stuck(real_vel.length(), true, delta):
				_enter_unstick(vehicle.heading, bearing, vehicle.global_position)
				return _unstick_intent()
			var esc_diff := wrapf(_escape_dir.angle() - vehicle.heading, -PI, PI)
			return {
				"throttle": 1.0,
				"steer": clampf(esc_diff * 2.0 + _avoid_bias * AVOID_GAIN, -1.0, 1.0),
				"fire_mg": false,
				"fire_selected": false,
			}

	if vehicle.get_hp_fraction() < _flee:
		_mode = Mode.EVADE
	elif dist > _far:
		_mode = Mode.PURSUE
	elif dist < _near:
		_mode = Mode.EVADE

	var intent: Dictionary
	if _mode == Mode.EVADE:
		var away := wrapf(bearing + PI - vehicle.heading, -PI, PI)
		# A wall dead ahead outranks "directly away from the threat" — slide
		# along it instead of pinning yourself (the corner trap). While wall-
		# sliding the nose can't point away, so don't throttle down for that.
		var away_gain := 0.6 if _blocked else 2.0
		intent = {
			"throttle": 1.0 if (_blocked or absf(away) < 1.2) else 0.3,
			"steer": clampf(away * away_gain + _avoid_bias * AVOID_GAIN, -1.0, 1.0),
			"fire_mg": false,
			"fire_selected": false,
		}
	else:
		var approach := bearing
		if _flank > 0.0 and dist > _near * 1.5:
			approach += deg_to_rad(35.0 * _flank)
		var diff := wrapf(approach - vehicle.heading, -PI, PI)
		var aim := wrapf(bearing - vehicle.heading, -PI, PI)
		# Don't chew on buildings: hold fire without line of sight. The mounts'
		# 3x AI cooldown_scale gates the rate; ammo/recharge gate the specials.
		var los := _los_clear(vehicle, target)
		intent = {
			"throttle": 1.0 if absf(diff) < 1.2 else 0.35,
			"steer": clampf(diff * 2.0 + _avoid_bias * AVOID_GAIN, -1.0, 1.0),
			"fire_mg": absf(aim) < 0.35 and dist < FIRE_RANGE and los,
			"fire_selected": absf(aim) < 0.2 and dist < FIRE_RANGE * 0.7 and los,
		}

	if _update_stuck(real_vel.length(), absf(intent["throttle"]) > 0.5, delta):
		_enter_unstick(vehicle.heading, bearing, vehicle.global_position)
		return _unstick_intent()
	return intent

## Accumulates stuckness (trying to move but barely moving); trips once per
## STUCK_TRIP seconds of it.
func _update_stuck(speed: float, wants_move: bool, delta: float) -> bool:
	if wants_move and speed < STUCK_SPEED:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _stuck_t >= STUCK_TRIP:
		_stuck_t = 0.0
		return true
	return false

## Commits the escape swing once at entry (away from the blocked side, else
## toward the target) so the feelers can't flip it side-to-side mid-reverse.
func _enter_unstick(heading: float, bearing: float, pin := Vector2.INF) -> void:
	_mode = Mode.UNSTICK
	_unstick_t = UNSTICK_TIME
	# First pin of an episode wins: re-sticking nearby mid-escape must keep
	# escaping from the ORIGINAL corner, not from wherever we stalled last.
	if pin != Vector2.INF and _last_pin.distance_to(pin) > CLEAR_DIST:
		_last_pin = pin
	var desired := _avoid_bias
	if absf(desired) < 0.05:
		desired = clampf(wrapf(bearing - heading, -PI, PI), -1.0, 1.0)
	_unstick_steer = clampf(desired, -1.0, 1.0)

## Back out of the pin: full reverse, swinging the nose toward the committed
## escape direction. Steering is sign-inverted because the controller flips
## steer while reversing.
func _unstick_intent() -> Dictionary:
	return {
		"throttle": -1.0,
		"steer": -_unstick_steer,
		"fire_mg": false,
		"fire_selected": false,
	}

## Casts three feelers (nose, ±35°) against walls/blocks and derives a steering
## bias away from the obstruction; sets _blocked when the nose ray hits close.
func _update_feelers(vehicle) -> void:
	_avoid_bias = 0.0
	_blocked = false
	if not (vehicle is CollisionObject2D):
		return
	var length: float = FEELER_BASE + vehicle.get_speed() * FEELER_SPEED_FACTOR
	var origin: Vector2 = vehicle.global_position
	var space := (vehicle as CollisionObject2D).get_world_2d().direct_space_state
	var frac := []  # hit fraction per feeler [left, center, right]; 1.0 = clear
	for offset in [-FEELER_ANGLE, 0.0, FEELER_ANGLE]:
		var dir := Vector2.RIGHT.rotated(vehicle.heading + offset)
		var query := PhysicsRayQueryParameters2D.create(origin, origin + dir * length, FEELER_MASK)
		query.exclude = [(vehicle as CollisionObject2D).get_rid()]
		var hit := space.intersect_ray(query)
		frac.append(origin.distance_to(hit["position"]) / length if not hit.is_empty() else 1.0)
	# Side hits push away, closer = stronger; positive steer turns right.
	_avoid_bias = (1.0 - frac[0]) - (1.0 - frac[2])
	if frac[1] < 1.0:
		_blocked = frac[1] < 0.6
		# Nose blocked: commit toward whichever side reads clearer.
		_avoid_bias += (1.0 - frac[1]) * (1.0 if frac[2] >= frac[0] else -1.0)

## True when no wall/block sits between the nose and the target (mask 6 —
## other cars don't block; collateral fire is free-for-all gameplay).
func _los_clear(vehicle, target: Node2D) -> bool:
	if not (vehicle is CollisionObject2D and target is CollisionObject2D):
		return false
	var space := (vehicle as CollisionObject2D).get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		vehicle.global_position, target.global_position, FEELER_MASK)
	query.exclude = [(vehicle as CollisionObject2D).get_rid(), (target as CollisionObject2D).get_rid()]
	return space.intersect_ray(query).is_empty()

## Target = highest blended score of "nearby" (w_near) and "wounded" (w_weak).
func _select_target(vehicle) -> Node2D:
	var best: Node2D = null
	var best_score := -INF
	for v in vehicle.get_tree().get_nodes_in_group(&"vehicles"):
		if v == vehicle:
			continue
		var d: float = vehicle.global_position.distance_to(v.global_position)
		if d > SCAN:
			continue
		var near_term := 1.0 - d / SCAN
		var hpf: float = v.get_hp_fraction() if v.has_method(&"get_hp_fraction") else 1.0
		var score := _w_near * near_term + _w_weak * (1.0 - hpf)
		if score > best_score:
			best_score = score
			best = v
	return best
