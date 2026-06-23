class_name EnemyDriver
extends Driver
## Simple free-for-all pursue/evade AI: chase the nearest other vehicle and fire
## while closing; peel off when too close or low on HP, then re-engage once
## distance opens. The hysteresis between NEAR and FAR keeps them jousting in and
## out instead of parking at one range. Distinct archetypes (weights, flanking,
## special usage) layer on top of this baseline later in Phase 3.

enum State { PURSUE, EVADE }

const NEAR := 180.0        # too close → peel off
const FAR := 460.0         # opened up → re-engage
const FIRE_RANGE := 1000.0
const LOW_HP := 0.3

var _state: State = State.PURSUE

func get_intent(vehicle, _delta: float) -> Dictionary:
	var target := _nearest_other(vehicle)
	if target == null:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_special": false}

	var to_target: Vector2 = target.global_position - vehicle.global_position
	var dist := to_target.length()
	var bearing := to_target.angle()

	# Hysteresis: commit to a state until distance crosses the far/near band.
	if vehicle.get_hp_fraction() < LOW_HP:
		_state = State.EVADE
	elif dist > FAR:
		_state = State.PURSUE
	elif dist < NEAR:
		_state = State.EVADE

	if _state == State.EVADE:
		var away := wrapf(bearing + PI - vehicle.heading, -PI, PI)
		return {
			"throttle": 1.0 if absf(away) < 1.2 else 0.3,
			"steer": clampf(away * 2.0, -1.0, 1.0),
			"fire_mg": false,
			"fire_special": false,
		}

	var diff := wrapf(bearing - vehicle.heading, -PI, PI)
	return {
		"throttle": 1.0 if absf(diff) < 1.2 else 0.2,
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
