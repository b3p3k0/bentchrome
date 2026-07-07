class_name Health
extends Node
## Hit points for any entity. Emits on damage and death; armor→HP scaling and
## status effects layer on later.

signal damaged(amount: float, hp: float)
signal died

@export var max_hp := 100.0
var hp: float
var invulnerable := false  # set by StatusReceiver (invuln effect)

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if invulnerable or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		died.emit()

## Unconditional death (pit falls) — cliffs don't care about invulnerability.
func kill() -> void:
	if hp <= 0.0:
		return
	hp = 0.0
	died.emit()
