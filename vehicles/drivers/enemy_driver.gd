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
	"agg": {"near": 140.0, "far": 340.0, "flee": 0.15, "w_near": 1.0, "w_weak": 0.0, "flank": 0.0},
	"amb": {"near": 200.0, "far": 480.0, "flee": 0.30, "w_near": 1.0, "w_weak": 0.0, "flank": 1.0},
	"opp": {"near": 320.0, "far": 640.0, "flee": 0.45, "w_near": 0.3, "w_weak": 1.0, "flank": 0.0},
}

enum Mode { PURSUE, EVADE }
const SCAN := 1200.0
const FIRE_RANGE := 1000.0

var _near := 140.0
var _far := 340.0
var _flee := 0.15
var _w_near := 1.0
var _w_weak := 0.0
var _flank := 0.0
var _mode: Mode = Mode.PURSUE

func _ready() -> void:
	var w := mix
	var sum := w.x + w.y + w.z
	if sum <= 0.0:
		w = Vector3(1, 0, 0)
		sum = 1.0
	w /= sum
	var a: Dictionary = PURE["agg"]
	var b: Dictionary = PURE["amb"]
	var o: Dictionary = PURE["opp"]
	_near = w.x * a["near"] + w.y * b["near"] + w.z * o["near"]
	_far = w.x * a["far"] + w.y * b["far"] + w.z * o["far"]
	_flee = w.x * a["flee"] + w.y * b["flee"] + w.z * o["flee"]
	_w_near = w.x * a["w_near"] + w.y * b["w_near"] + w.z * o["w_near"]
	_w_weak = w.x * a["w_weak"] + w.y * b["w_weak"] + w.z * o["w_weak"]
	_flank = w.x * a["flank"] + w.y * b["flank"] + w.z * o["flank"]

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _select_target(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_selected": false}

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var bearing := to_target.angle()

	if vehicle.get_hp_fraction() < _flee:
		_mode = Mode.EVADE
	elif dist > _far:
		_mode = Mode.PURSUE
	elif dist < _near:
		_mode = Mode.EVADE

	if _mode == Mode.EVADE:
		var away := wrapf(bearing + PI - vehicle.heading, -PI, PI)
		return {
			"throttle": 1.0 if absf(away) < 1.2 else 0.3,
			"steer": clampf(away * 2.0, -1.0, 1.0),
			"fire_mg": false,
			"fire_selected": false,
		}

	var approach := bearing
	if _flank > 0.0 and dist > _near * 1.5:
		approach += deg_to_rad(35.0 * _flank)
	var diff := wrapf(approach - vehicle.heading, -PI, PI)
	var aim := wrapf(bearing - vehicle.heading, -PI, PI)
	return {
		"throttle": 1.0 if absf(diff) < 1.2 else 0.2,
		"steer": clampf(diff * 2.0, -1.0, 1.0),
		"fire_mg": absf(aim) < 0.25 and dist < FIRE_RANGE,
		"fire_selected": false,
	}

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
