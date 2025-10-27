extends Node

## GameManager - Centralized dynamic object spawning and scene management
## Autoloaded singleton that handles all spawning in viewport-aware manner
## Provides foundation for bullets, pickups, explosions, enemies, and effects

## Debug flag for spawn event logging
const DEBUG_SPAWNING: bool = true

## Scene tree references
var game_root: Node2D
var active_bullets: Array[Node] = []
var active_pickups: Array[Node] = []
var active_effects: Array[Node] = []
var active_enemies: Array[Node] = []

## Signals for event system integration
signal object_spawned(object: Node, type: String)
signal object_destroyed(object: Node, type: String)

func _ready():
	_debug_log("GameManager initialized")

## Register the main game root for spawning operations
func register_scene_root(root: Node2D) -> void:
	game_root = root
	_debug_log("GameRoot registered: " + str(root.get_path()))

## Find the correct game root for spawning, with fallbacks
func get_game_root() -> Node2D:
	# Primary: Use registered reference
	if game_root and is_instance_valid(game_root):
		return game_root

	# Fallback 1: Search for SubViewport structure
	var current_scene = get_tree().current_scene
	if current_scene:
		var subviewport = _find_subviewport(current_scene)
		if subviewport:
			for child in subviewport.get_children():
				if child is Node2D:
					_debug_log("Found GameRoot via SubViewport search: " + str(child.get_path()))
					game_root = child
					return child

	# Fallback 2: Use current scene (with warning)
	if current_scene is Node2D:
		_debug_log("Warning: Using current_scene as GameRoot fallback")
		return current_scene

	# Emergency: Return null and log error
	push_error("GameManager: Could not find suitable GameRoot for spawning")
	return null

## Recursive search for SubViewport in scene tree
func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node

	for child in node.get_children():
		var result = _find_subviewport(child)
		if result:
			return result

	return null

## Spawn bullet with proper scene tree placement
func spawn_bullet(scene: PackedScene, spawn_position: Vector2, direction: Vector2, source) -> Node:
	if not scene:
		push_error("GameManager: bullet_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for bullet spawning")
		return null

	var bullet = scene.instantiate()
	bullet.global_position = spawn_position
	bullet.direction = direction.normalized()

	spawn_root.add_child(bullet)
	active_bullets.append(bullet)

	# Connect cleanup signal
	if bullet.has_signal("tree_exiting"):
		bullet.tree_exiting.connect(_on_bullet_freed.bind(bullet))
	elif bullet.has_method("queue_free"):
		# Monitor for bullet cleanup via polling (less efficient but works)
		bullet.tree_exiting.connect(_on_bullet_freed.bind(bullet))

	_debug_log("Spawned bullet at " + str(spawn_position) + " from " + str(source.name if source else "unknown"))
	object_spawned.emit(bullet, "bullet")

	return bullet

## Spawn pickup item at specified location
func spawn_pickup(scene: PackedScene, spawn_position: Vector2, pickup_type: String) -> Node:
	if not scene:
		push_error("GameManager: pickup_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for pickup spawning")
		return null

	var pickup = scene.instantiate()
	pickup.global_position = spawn_position

	if pickup.has_method("set_pickup_type"):
		pickup.set_pickup_type(pickup_type)

	spawn_root.add_child(pickup)
	active_pickups.append(pickup)

	pickup.tree_exiting.connect(_on_pickup_freed.bind(pickup))

	_debug_log("Spawned pickup (" + pickup_type + ") at " + str(spawn_position))
	object_spawned.emit(pickup, "pickup")

	return pickup

## Spawn explosion effect at specified location
func spawn_explosion(scene: PackedScene, spawn_position: Vector2, scale_factor: float = 1.0) -> Node:
	if not scene:
		push_error("GameManager: explosion_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for explosion spawning")
		return null

	var explosion = scene.instantiate()
	explosion.global_position = spawn_position
	explosion.scale = Vector2(scale_factor, scale_factor)

	spawn_root.add_child(explosion)
	active_effects.append(explosion)

	explosion.tree_exiting.connect(_on_effect_freed.bind(explosion))

	_debug_log("Spawned explosion at " + str(spawn_position) + " (scale: " + str(scale_factor) + ")")
	object_spawned.emit(explosion, "explosion")

	return explosion

## Spawn enemy vehicle at specified location
func spawn_enemy(scene: PackedScene, spawn_position: Vector2, ai_type: String) -> Node:
	if not scene:
		push_error("GameManager: enemy_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for enemy spawning")
		return null

	var enemy = scene.instantiate()
	enemy.global_position = spawn_position

	if enemy.has_method("set_ai_type"):
		enemy.set_ai_type(ai_type)

	spawn_root.add_child(enemy)
	active_enemies.append(enemy)

	enemy.tree_exiting.connect(_on_enemy_freed.bind(enemy))

	_debug_log("Spawned enemy (" + ai_type + ") at " + str(spawn_position))
	object_spawned.emit(enemy, "enemy")

	return enemy

## Generic spawning interface for future expansion
func spawn_object(scene: PackedScene, spawn_data: Dictionary) -> Node:
	var spawn_position = spawn_data.get("position", Vector2.ZERO)
	var object_type = spawn_data.get("type", "unknown")

	match object_type:
		"bullet":
			var direction = spawn_data.get("direction", Vector2.UP)
			var source = spawn_data.get("source", null)
			return spawn_bullet(scene, spawn_position, direction, source)
		"pickup":
			var pickup_type = spawn_data.get("pickup_type", "generic")
			return spawn_pickup(scene, spawn_position, pickup_type)
		"explosion":
			var scale_factor = spawn_data.get("scale", 1.0)
			return spawn_explosion(scene, spawn_position, scale_factor)
		"enemy":
			var ai_type = spawn_data.get("ai_type", "basic")
			return spawn_enemy(scene, spawn_position, ai_type)
		_:
			push_warning("GameManager: Unknown object type for spawning: " + object_type)
			return null

## Cleanup handlers for object tracking
func _on_bullet_freed(bullet: Node):
	active_bullets.erase(bullet)
	object_destroyed.emit(bullet, "bullet")
	_debug_log("Bullet destroyed, remaining: " + str(active_bullets.size()))

func _on_pickup_freed(pickup: Node):
	active_pickups.erase(pickup)
	object_destroyed.emit(pickup, "pickup")
	_debug_log("Pickup destroyed, remaining: " + str(active_pickups.size()))

func _on_effect_freed(effect: Node):
	active_effects.erase(effect)
	object_destroyed.emit(effect, "effect")
	_debug_log("Effect destroyed, remaining: " + str(active_effects.size()))

func _on_enemy_freed(enemy: Node):
	active_enemies.erase(enemy)
	object_destroyed.emit(enemy, "enemy")
	_debug_log("Enemy destroyed, remaining: " + str(active_enemies.size()))

## Cleanup all dynamic objects (for scene transitions)
func cleanup_all_dynamic_objects():
	var total_cleaned = 0

	for bullet in active_bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
			total_cleaned += 1
	active_bullets.clear()

	for pickup in active_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
			total_cleaned += 1
	active_pickups.clear()

	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
			total_cleaned += 1
	active_effects.clear()

	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
			total_cleaned += 1
	active_enemies.clear()

	_debug_log("Cleaned up " + str(total_cleaned) + " dynamic objects")

## Get counts for debugging/UI
func get_active_object_counts() -> Dictionary:
	return {
		"bullets": active_bullets.size(),
		"pickups": active_pickups.size(),
		"effects": active_effects.size(),
		"enemies": active_enemies.size()
	}

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_SPAWNING:
		print("[GameManager] ", msg)