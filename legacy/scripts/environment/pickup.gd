extends Area2D

## Pickup item script for health and ammo collection
## NO class_name declaration (regression prevention)

# Pickup type constants (string-based, no enums)
const TYPE_HEALTH_MINOR = "health_minor"
const TYPE_AMMO_MISSILE = "ammo_missile"

# Configuration per pickup type
const PICKUP_CONFIGS = {
	"health_minor": {
		"heal_percent": 0.20,  # 20% of max HP
		"color": Color(0.2, 1.0, 0.2),  # Green
		"label": "Health +20%"
	},
	"ammo_missile": {
		"ammo_amount": 2,
		"color": Color(1.0, 0.8, 0.2),  # Yellow/Orange
		"label": "Missiles +2"
	}
}

# Signals
signal collected  # Emitted when pickup is collected (for respawn tracking)

# Current pickup configuration
var current_pickup_type: String = TYPE_HEALTH_MINOR
var _config: Dictionary = {}
var _visual_rect: ColorRect = null
var _is_collected: bool = false

func _ready():
	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Get visual rect reference
	_visual_rect = $Visual/ColorRect

	# Apply default type if not set
	if current_pickup_type.is_empty():
		set_pickup_type(TYPE_HEALTH_MINOR)

## Called by GameManager.spawn_pickup() to set pickup type
func set_pickup_type(type: String) -> void:
	if not type in PICKUP_CONFIGS:
		push_error("Pickup: Unknown pickup type '%s', defaulting to health_minor" % type)
		type = TYPE_HEALTH_MINOR

	current_pickup_type = type
	_config = PICKUP_CONFIGS[type]

	# Update visual color
	if _visual_rect:
		_visual_rect.color = _config["color"]

	_debug_log("Pickup configured as '%s' (%s)" % [type, _config["label"]])

## Detect when vehicle enters collection area
func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return

	# Only collect from player or enemies
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return

	_debug_log("Collision detected with %s" % body.name)

	# Try to apply effect
	if _apply_pickup_effect(body):
		_collect()

## Apply pickup effect to collector (player or enemy)
func _apply_pickup_effect(collector: Node) -> bool:
	match current_pickup_type:
		TYPE_HEALTH_MINOR:
			return _apply_health_effect(collector)

		TYPE_AMMO_MISSILE:
			return _apply_ammo_effect(collector)

		_:
			push_error("Pickup: Unhandled pickup type '%s'" % current_pickup_type)
			return false

## Apply health restoration
func _apply_health_effect(collector: Node) -> bool:
	if not collector.has_method("get_vehicle_health"):
		_debug_log("Collector %s has no get_vehicle_health() method" % collector.name)
		return false

	var health = collector.get_vehicle_health()
	if not health:
		_debug_log("Collector %s returned null vehicle_health" % collector.name)
		return false

	var heal_percent = _config.get("heal_percent", 0.20)
	var heal_amount = health.max_hp * heal_percent

	_debug_log("Healing %s for %.1f HP (%.0f%%)" % [collector.name, heal_amount, heal_percent * 100])
	health.apply_heal(heal_amount)

	return true

## Apply ammo replenishment
func _apply_ammo_effect(collector: Node) -> bool:
	var ammo_amount = _config.get("ammo_amount", 2)

	# Try add_missiles method first
	if collector.has_method("add_missiles"):
		_debug_log("Adding %d missiles to %s via add_missiles()" % [ammo_amount, collector.name])
		collector.add_missiles(ammo_amount)
		return true

	# Fallback: Try direct property access
	if "missile_count" in collector:
		_debug_log("Adding %d missiles to %s via missile_count property" % [ammo_amount, collector.name])
		collector.missile_count += ammo_amount
		return true

	_debug_log("Collector %s has no ammo system" % collector.name)
	return false

## Collect this pickup (destroy and notify)
func _collect() -> void:
	if _is_collected:
		return

	_is_collected = true
	_debug_log("Pickup collected (%s)" % _config.get("label", current_pickup_type))

	# Emit signal for respawn tracking
	collected.emit()

	# Destroy pickup
	queue_free()

## Debug logging
func _debug_log(message: String) -> void:
	if OS.is_debug_build():
		print("[Pickup:%s] %s" % [get_instance_id(), message])
