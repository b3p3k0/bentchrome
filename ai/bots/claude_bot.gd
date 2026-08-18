extends Driver
## BOTLAB LEAGUE ENTRY — Claude's bot. Never shipped in a game scene; mounted
## by tools/botlab/botlab_probe.gd via Vehicle.set_driver.
##
## Contract (docs/botlab.md): a bot is a PURE Driver. Return an intent dict
## from get_intent(); read ONLY the EnemyDriver surface — the vehicle's own
## duck-typed API (global_position, heading, get_speed(), get_real_velocity(),
## get_hp_fraction(), current_terrain, get_rack()), group scans
## (get_nodes_in_group(&"vehicles")), and direct_space_state raycasts.
## Never mutate the scene, other cars, autoloads, or globals.

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _nearest_foe(vehicle)
	var throttle := 0.0
	var steer := 0.0
	var fire := false
	if target:
		var to_target: Vector2 = target.global_position - vehicle.global_position
		var aim_err: float = wrapf(to_target.angle() - vehicle.heading, -PI, PI)
		steer = clampf(aim_err * 2.0, -1.0, 1.0)
		throttle = 1.0 if to_target.length() > 260.0 else 0.35
		fire = absf(aim_err) < 0.35 and to_target.length() < 900.0
	return {
		"throttle": throttle,
		"steer": steer,
		"fire_mg": fire,
		"fire_selected": false,
		"weapon_prev": false,
		"weapon_next": false,
		"handbrake": false,
		"boost": false,
	}

func _nearest_foe(vehicle) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for car in vehicle.get_tree().get_nodes_in_group(&"vehicles"):
		if car == vehicle or not is_instance_valid(car):
			continue
		if car.has_method("get_hp_fraction") and car.get_hp_fraction() <= 0.0:
			continue
		var d: float = vehicle.global_position.distance_squared_to(car.global_position)
		if d < best_d:
			best_d = d
			best = car
	return best
