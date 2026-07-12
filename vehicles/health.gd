class_name Health
extends Node
## Hit points for any entity. Emits on damage and death; armor→HP scaling and
## status effects layer on later.

signal damaged(amount: float, hp: float)
signal died

@export var max_hp := 100.0
var hp: float
var invulnerable := false  # set by StatusReceiver (invuln effect) — it re-syncs
						    # this every tick, so permanent immunity lives in `god`
var god := false           # DEVGOD: immune to damage; kill() still works (pits)
var _immunity_sources: Dictionary = {}  # interaction-owned holds compose with status

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if is_damage_immune() or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		died.emit()

## Named immunity holds let independent systems overlap without clearing each
## other. StatusReceiver keeps ownership of the legacy `invulnerable` flag;
## repair bays use a source entry and therefore cannot cancel a spawn shield.
func set_immunity(source: StringName, enabled: bool) -> void:
	if enabled:
		_immunity_sources[source] = true
	else:
		_immunity_sources.erase(source)

func is_damage_immune() -> bool:
	return god or invulnerable or not _immunity_sources.is_empty()

## Positive healing only, clamped, and never a resurrection seam.
func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = minf(hp + amount, max_hp)

## Unconditional death (pit falls) — cliffs don't care about invulnerability.
func kill() -> void:
	if hp <= 0.0:
		return
	hp = 0.0
	died.emit()
