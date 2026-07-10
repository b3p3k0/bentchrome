extends Area2D
## Drive-over medkit: a one-shot partial heal for the PLAYER only (station
## philosophy — no free patches for the mob). No cooldown machinery, no
## respawn: grab it or lose it. Skips the grab entirely at full health so a
## topped-up player can bank it for the next lap past.

@export var amount := 25.0

func _ready() -> void:
	add_to_group(&"pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	var health = body.get_node_or_null(^"Health")
	if health == null or health.hp <= 0.0 or health.hp >= health.max_hp:
		return
	health.hp = minf(health.hp + amount, health.max_hp)
	queue_free()
