extends Area2D
## Drive-over kit: a one-shot grant for the PLAYER only (station philosophy —
## no free patches for the mob). Two kinds: &"heal" (+HP via the Health child)
## and &"boost" (+nitro via the controller — the game's only boost refill,
## chase-course exclusive by authoring). Skips the grab at a full tank so it
## banks for the next pass. No cooldown machinery, no respawn: grab or lose it.

@export var kind: StringName = &"heal"
@export var amount := 25.0

func _ready() -> void:
	add_to_group(&"pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	if kind == &"boost":
		if not body.has_method(&"get_controller"):
			return
		var ctrl = body.get_controller()
		if ctrl == null or ctrl.boost_fuel >= 100.0:
			return
		ctrl.boost_fuel = minf(ctrl.boost_fuel + amount, 100.0)
		_cue()
		queue_free()
		return
	var health = body.get_node_or_null(^"Health")
	if health == null or health.hp <= 0.0 or health.hp >= health.max_hp:
		return
	health.hp = minf(health.hp + amount, health.max_hp)
	_cue()
	queue_free()

func _cue() -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio:
		audio.play(&"pickup")
