extends Node

## Level controller for managing pickup spawning and respawn timers
## NO class_name declaration (regression prevention)

# Respawn configuration
const RESPAWN_COOLDOWN = 90.0  # 90 seconds as per requirements

# Pickup scene reference
const PICKUP_SCENE = preload("res://scenes/environment/Pickup.tscn")

# Spawner tracking
var pickup_spawners: Array = []
# Each element: {marker: Marker2D, type: String, timer: float, active_pickup: Node}

# Debug flag
var _debug_enabled: bool = OS.is_debug_build()

func _ready():
	_debug_log("LevelController initializing...")
	_discover_pickup_spawners()
	_spawn_initial_pickups()
	_debug_log("LevelController ready with %d spawners" % pickup_spawners.size())

## Discover all pickup spawn markers in the scene
func _discover_pickup_spawners() -> void:
	var markers = get_tree().get_nodes_in_group("pickup_spawner")
	_debug_log("Found %d pickup_spawner markers" % markers.size())

	for marker in markers:
		if not marker is Marker2D:
			push_warning("LevelController: pickup_spawner '%s' is not a Marker2D, skipping" % marker.name)
			continue

		var pickup_type = marker.get_meta("pickup_type", "health_minor")

		var spawner_data = {
			"marker": marker,
			"type": pickup_type,
			"timer": 0.0,
			"active_pickup": null
		}

		pickup_spawners.append(spawner_data)
		_debug_log("Registered spawner '%s' at %s for type '%s'" % [marker.name, marker.global_position, pickup_type])

## Spawn pickups at all markers on level start
func _spawn_initial_pickups() -> void:
	for spawner in pickup_spawners:
		_spawn_at_marker(spawner)

	_debug_log("Initial pickup spawn complete")

## Spawn a pickup at a specific marker
func _spawn_at_marker(spawner: Dictionary) -> void:
	if not is_instance_valid(spawner.marker):
		push_error("LevelController: Spawner marker is invalid")
		return

	if spawner.active_pickup != null and is_instance_valid(spawner.active_pickup):
		_debug_log("Spawner '%s' already has active pickup, skipping" % spawner.marker.name)
		return

	# Spawn pickup via GameManager
	var pickup = GameManager.spawn_pickup(
		PICKUP_SCENE,
		spawner.marker.global_position,
		spawner.type
	)

	if not pickup:
		push_error("LevelController: Failed to spawn pickup at '%s'" % spawner.marker.name)
		return

	# Track the pickup
	spawner.active_pickup = pickup

	# Connect to collected signal for respawn tracking
	if pickup.has_signal("collected"):
		pickup.collected.connect(_on_pickup_collected.bind(spawner))
		_debug_log("Spawned pickup at '%s' (%s)" % [spawner.marker.name, spawner.type])
	else:
		push_warning("LevelController: Pickup doesn't have 'collected' signal")

## Handle pickup collection - start respawn timer
func _on_pickup_collected(spawner: Dictionary) -> void:
	_debug_log("Pickup collected at '%s', starting %ds respawn timer" % [spawner.marker.name, RESPAWN_COOLDOWN])

	spawner.active_pickup = null
	spawner.timer = RESPAWN_COOLDOWN

## Process respawn timers each frame
func _process(delta: float) -> void:
	for spawner in pickup_spawners:
		# Skip if pickup is active
		if spawner.active_pickup != null and is_instance_valid(spawner.active_pickup):
			continue

		# Skip if no timer active
		if spawner.timer <= 0.0:
			continue

		# Countdown timer
		spawner.timer -= delta

		# Respawn when timer expires
		if spawner.timer <= 0.0:
			_debug_log("Respawn timer expired for '%s', spawning pickup" % spawner.marker.name)
			_spawn_at_marker(spawner)

## Debug logging
func _debug_log(message: String) -> void:
	if _debug_enabled:
		print("[LevelController] %s" % message)

## Get spawner stats for debugging
func get_spawner_stats() -> Dictionary:
	var stats = {
		"total_spawners": pickup_spawners.size(),
		"active_pickups": 0,
		"waiting_respawn": 0
	}

	for spawner in pickup_spawners:
		if spawner.active_pickup != null and is_instance_valid(spawner.active_pickup):
			stats.active_pickups += 1
		elif spawner.timer > 0.0:
			stats.waiting_respawn += 1

	return stats
