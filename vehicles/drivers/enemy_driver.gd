class_name EnemyDriver
extends Driver
## Placeholder enemy behavior for Phase 2 faction testing: turn toward the
## player and fire the machine gun when roughly aimed. It does not drive yet —
## real archetypes (movement, flanking, retreat) arrive in Phase 3.

var _player: Node2D = null

func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player") as Node2D

func get_intent(vehicle, _delta: float) -> Dictionary:
	if _player == null or not is_instance_valid(_player):
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": false, "fire_special": false}
	var to_player: Vector2 = _player.global_position - vehicle.global_position
	var diff := wrapf(to_player.angle() - vehicle.heading, -PI, PI)
	return {
		"throttle": 0.0,
		"steer": clampf(diff * 2.0, -1.0, 1.0),
		"fire_mg": absf(diff) < 0.22,
		"fire_special": false,
	}
