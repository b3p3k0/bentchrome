extends Node
class_name VehicleHealth

## Centralized vehicle health system with armor-based HP scaling
## Maps 1-10 armor rating to 600-1200 HP linearly
## Provides mass scaling for collision damage calculations

## Debug flag for health system logging
const DEBUG_HEALTH: bool = false

## Base armor rating (1-10 scale) - set via configure_from_stats()
@export var base_armor_rating: int = 5

## Health values computed from armor rating
@export var max_hp: float = 900.0
@export var current_hp: float = 900.0

## Signals for health events
signal took_damage(amount: float, source)
signal died()
signal healed(amount: float)

## Internal state
var _is_dead: bool = false

func _ready():
	# Ensure HP is properly initialized
	_recompute_hp_from_armor()

## Configure health from character stats dictionary
func configure_from_stats(stats_dict: Dictionary):
	var armor_stat = stats_dict.get("armor", 5)
	base_armor_rating = clamp(armor_stat, 1, 10)
	_recompute_hp_from_armor()
	_debug_log("Configured from stats - Armor: %d, HP: %.0f" % [base_armor_rating, max_hp])

## Recompute HP values from armor rating using linear mapping
func _recompute_hp_from_armor():
	# Map armor rating 1-10 to HP 600-1200 linearly
	max_hp = round(lerp(600.0, 1200.0, (base_armor_rating - 1) / 9.0))
	current_hp = max_hp
	_is_dead = false
	_debug_log("HP recomputed - Armor: %d -> HP: %.0f" % [base_armor_rating, max_hp])

## Apply damage to this vehicle
func apply_damage(amount: float, source = null) -> void:
	if _is_dead or amount <= 0:
		return

	var old_hp = current_hp
	current_hp = max(0.0, current_hp - amount)

	_debug_log("Damage applied: %.1f (%.0f -> %.0f)" % [amount, old_hp, current_hp])
	took_damage.emit(amount, source)

	# Check for death
	if current_hp <= 0 and not _is_dead:
		_is_dead = true
		_debug_log("Vehicle died!")
		died.emit()

## Apply healing to this vehicle
func apply_heal(amount: float) -> void:
	if _is_dead or amount <= 0:
		return

	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)

	if current_hp > old_hp:
		_debug_log("Healed: %.1f (%.0f -> %.0f)" % [amount, old_hp, current_hp])
		healed.emit(amount)

## Check if vehicle is dead
func is_dead() -> bool:
	return _is_dead

## Get mass scalar for collision calculations based on armor rating
func get_mass_scalar() -> float:
	# Map armor rating 1-10 to mass scalar 0.8-1.4 linearly
	return lerp(0.8, 1.4, (base_armor_rating - 1) / 9.0)

## Reset vehicle to full health
func reset() -> void:
	current_hp = max_hp
	_is_dead = false
	_debug_log("Health reset to %.0f" % max_hp)

## Get current HP percentage (0.0 to 1.0)
func get_hp_percentage() -> float:
	if max_hp <= 0:
		return 0.0
	return current_hp / max_hp

## Set armor rating and recompute HP (useful for editor/testing)
func set_armor_rating(new_rating: int) -> void:
	base_armor_rating = clamp(new_rating, 1, 10)
	_recompute_hp_from_armor()

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_HEALTH:
		print("[VehicleHealth] ", msg)