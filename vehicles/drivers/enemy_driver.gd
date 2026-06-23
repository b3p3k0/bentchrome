class_name EnemyDriver
extends Driver
## Placeholder free-for-all behavior: turn toward the nearest OTHER vehicle
## (player or another enemy) and fire the MG when roughly aimed. Stationary for
## now — real archetypes (movement, threat scoring) arrive in Phase 3.

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _nearest_other(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_special": false}
	var to_target: Vector2 = target.global_position - vehicle.global_position
	var diff := wrapf(to_target.angle() - vehicle.heading, -PI, PI)
	return {
		"throttle": 0.0,
		"steer": clampf(diff * 2.0, -1.0, 1.0),
		"fire_mg": absf(diff) < 0.22,
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
