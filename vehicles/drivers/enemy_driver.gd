class_name EnemyDriver
extends Driver
## Basic free-for-all pursuit: chase the nearest OTHER vehicle (player or another
## enemy), hold a rough engagement range, and fire the MG while facing it. This
## is the movement baseline — distinct archetypes (flank, retreat, ambush, boss)
## layer weights and behaviors on top in the rest of Phase 3.

const ENGAGE_RANGE := 240.0   # px the enemy tries to keep from its target
const FIRE_RANGE := 1000.0

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _nearest_other(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_special": false}

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var diff := wrapf(to_target.angle() - vehicle.heading, -PI, PI)

	# Drive toward the target when roughly facing it; ease off (or back up) when
	# inside the engagement range so it circles instead of ramming.
	var throttle := 0.0
	if absf(diff) < 1.2:
		throttle = clampf((dist - ENGAGE_RANGE) / 300.0, -0.3, 1.0)

	return {
		"throttle": throttle,
		"steer": clampf(diff * 2.0, -1.0, 1.0),
		"fire_mg": absf(diff) < 0.25 and dist < FIRE_RANGE,
		"fire_special": false,
	}

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
