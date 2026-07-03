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

enum Mode { PURSUE, EVADE, UNSTICK }
const SCAN := 1200.0
const FIRE_RANGE := 1000.0

# Stuck escape: pinned against a wall/block -> reverse out, then re-engage.
const STUCK_SPEED := 40.0        # slower than this while trying to move = stuck
const STUCK_TRIP := 0.6          # seconds of stuckness before the escape kicks in
const UNSTICK_TIME := 1.0        # how long to back out
const UNSTICK_EXIT_SPEED := 140.0  # moving this fast again = free early

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

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var bearing := to_target.angle()

	_update_feelers(vehicle)

	if _mode == Mode.UNSTICK:
		_unstick_t -= delta
		if _unstick_t <= 0.0 or vehicle.get_speed() > UNSTICK_EXIT_SPEED:
			_mode = Mode.PURSUE
			_stuck_t = 0.0
		else:
			return _unstick_intent(vehicle.heading, bearing)

	if vehicle.get_hp_fraction() < _flee:
		_mode = Mode.EVADE
	elif dist > _far:
		_mode = Mode.PURSUE
	elif dist < _near:
		_mode = Mode.EVADE

	var intent: Dictionary
	if _mode == Mode.EVADE:
		var away := wrapf(bearing + PI - vehicle.heading, -PI, PI)
		intent = {
			"throttle": 1.0 if absf(away) < 1.2 else 0.3,
			"steer": clampf(away * 2.0 + _avoid_bias * AVOID_GAIN, -1.0, 1.0),
			"fire_mg": false,
			"fire_selected": false,
		}
	else:
		var approach := bearing
		if _flank > 0.0 and dist > _near * 1.5:
			approach += deg_to_rad(35.0 * _flank)
		var diff := wrapf(approach - vehicle.heading, -PI, PI)
		var aim := wrapf(bearing - vehicle.heading, -PI, PI)
		intent = {
			"throttle": 1.0 if absf(diff) < 1.2 else 0.35,
			"steer": clampf(diff * 2.0 + _avoid_bias * AVOID_GAIN, -1.0, 1.0),
			"fire_mg": absf(aim) < 0.35 and dist < FIRE_RANGE,
			"fire_selected": false,
		}

	if _update_stuck(vehicle.get_speed(), absf(intent["throttle"]) > 0.5, delta):
		_mode = Mode.UNSTICK
		_unstick_t = UNSTICK_TIME
		return _unstick_intent(vehicle.heading, bearing)
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

## Back out of the pin: full reverse, swinging the nose toward the escape
## direction (away from the blocked side, else toward the target). Steering is
## sign-inverted because the controller flips steer while reversing.
func _unstick_intent(heading: float, bearing: float) -> Dictionary:
	var desired := _avoid_bias
	if absf(desired) < 0.05:
		desired = clampf(wrapf(bearing - heading, -PI, PI), -1.0, 1.0)
	return {
		"throttle": -1.0,
		"steer": -clampf(desired, -1.0, 1.0),
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
