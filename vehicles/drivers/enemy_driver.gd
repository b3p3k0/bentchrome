class_name EnemyDriver
extends Driver
## Free-for-all combat AI. Three archetypes built on the same pursue/evade
## jousting skeleton, differing mainly by TARGET SELECTION and engagement tuning:
##   AGGRESSOR   — charges the NEAREST car, tight band, fights to near-death.
##   AMBUSHER    — nearest car but approaches at a flank angle; hit-and-run.
##   OPPORTUNIST — stalks the WEAKEST car in range, hangs back, pounces, flees early.
## Mini-boss/boss will be tougher variants; a data-driven version comes later.

enum Archetype { AGGRESSOR, AMBUSHER, OPPORTUNIST }
@export var archetype: Archetype = Archetype.AGGRESSOR

enum Mode { PURSUE, EVADE }

const FIRE_RANGE := 1000.0
const OPPORTUNIST_SCAN := 900.0

var _mode: Mode = Mode.PURSUE

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _select_target(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_special": false}

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var bearing := to_target.angle()

	# Pursue/evade hysteresis, tuned per archetype.
	if vehicle.get_hp_fraction() < _flee_hp():
		_mode = Mode.EVADE
	elif dist > _far_range():
		_mode = Mode.PURSUE
	elif dist < _near_range():
		_mode = Mode.EVADE

	if _mode == Mode.EVADE:
		var away := wrapf(bearing + PI - vehicle.heading, -PI, PI)
		return {
			"throttle": 1.0 if absf(away) < 1.2 else 0.3,
			"steer": clampf(away * 2.0, -1.0, 1.0),
			"fire_mg": false,
			"fire_special": false,
		}

	# PURSUE — ambushers bias their approach to a flank angle until they close.
	var approach := bearing
	if archetype == Archetype.AMBUSHER and dist > _near_range() * 1.5:
		approach += deg_to_rad(35.0)
	var diff := wrapf(approach - vehicle.heading, -PI, PI)
	var aim := wrapf(bearing - vehicle.heading, -PI, PI)
	return {
		"throttle": 1.0 if absf(diff) < 1.2 else 0.2,
		"steer": clampf(diff * 2.0, -1.0, 1.0),
		"fire_mg": absf(aim) < 0.25 and dist < FIRE_RANGE,
		"fire_special": false,
	}

func _near_range() -> float:
	match archetype:
		Archetype.AGGRESSOR: return 140.0
		Archetype.AMBUSHER: return 200.0
		_: return 320.0

func _far_range() -> float:
	match archetype:
		Archetype.AGGRESSOR: return 340.0
		Archetype.AMBUSHER: return 480.0
		_: return 640.0

func _flee_hp() -> float:
	match archetype:
		Archetype.AGGRESSOR: return 0.15
		Archetype.AMBUSHER: return 0.3
		_: return 0.45

func _select_target(vehicle) -> Node2D:
	if archetype == Archetype.OPPORTUNIST:
		return _weakest_other(vehicle)
	return _nearest_other(vehicle)

func _nearest_other(vehicle) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for v in vehicle.get_tree().get_nodes_in_group(&"vehicles"):
		if v == vehicle:
			continue
		var d: float = vehicle.global_position.distance_to(v.global_position)
		if d < best_dist:
			best_dist = d
			best = v
	return best

func _weakest_other(vehicle) -> Node2D:
	var best: Node2D = null
	var best_hp := INF
	for v in vehicle.get_tree().get_nodes_in_group(&"vehicles"):
		if v == vehicle:
			continue
		if vehicle.global_position.distance_to(v.global_position) > OPPORTUNIST_SCAN:
			continue
		var hpf: float = v.get_hp_fraction() if v.has_method(&"get_hp_fraction") else 1.0
		if hpf < best_hp:
			best_hp = hpf
			best = v
	return best if best != null else _nearest_other(vehicle)
