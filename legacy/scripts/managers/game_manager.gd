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
var active_missiles: Array[Node] = []

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
	if bullet.has_method("set_direction"):
		bullet.set_direction(direction)
	else:
		push_warning("GameManager: Bullet scene missing set_direction(), using default direction")

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

## Spawn missile with simple bullet-like interface
func spawn_missile_simple(scene: PackedScene, spawn_position: Vector2, direction: Vector2, source, missile_type: int = 1) -> Node:
	if not scene:
		push_error("GameManager: missile_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for missile spawning")
		return null

	var missile = scene.instantiate()
	missile.global_position = spawn_position
	missile.velocity = direction * 1400.0
	missile.rotation = direction.angle()
	missile.missile_type = missile_type
	missile.owner_node = source

	spawn_root.add_child(missile)
	active_missiles.append(missile)

	missile.tree_exiting.connect(_on_missile_freed.bind(missile))

	_debug_log("Spawned missile (simple) at " + str(spawn_position) + " from " + str(source.name if source else "unknown"))
	object_spawned.emit(missile, "missile")

	return missile

## Generic projectile spawn helper - instantiates a PackedScene and tracks it
func spawn_projectile(scene: PackedScene, spawn_position: Vector2, params: Dictionary = {}) -> Node:
	if not scene:
		push_error("GameManager: projectile scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for projectile spawning")
		return null

	var proj = scene.instantiate()
	proj.global_position = spawn_position

	if params.has("owner") and proj.has_method("set"):
		proj.set("owner_node", params.owner)

	spawn_root.add_child(proj)

	var track_as = params.get("track_as", "bullet")
	if track_as == "missile":
		active_missiles.append(proj)
		proj.tree_exiting.connect(_on_missile_freed.bind(proj))
	else:
		active_bullets.append(proj)
		proj.tree_exiting.connect(_on_bullet_freed.bind(proj))

	_debug_log("Spawned projectile at " + str(spawn_position) + " (as: " + track_as + ")")
	object_spawned.emit(proj, "projectile")
	return proj

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

## Debug logging helper for missile system
func _missile_debug_log(message: String):
	var timestamp = Time.get_ticks_msec() / 1000.0
	var log_entry = "[%.3f] %s\n" % [timestamp, message]
	var file = FileAccess.open("/tmp/missile_debug.log", FileAccess.WRITE_READ)
	if file:
		file.seek_end()  # Append to end of file
		file.store_string(log_entry)
		file.close()
	print("[%.3f] %s" % [timestamp, message])  # Fixed: removed strip() call

## Spawn missile projectile and track it
func spawn_missile(scene: PackedScene, spawn_position: Vector2, owner: Node = null, rotation: float = 0.0, initial_velocity = null, missile_type = null) -> Node:
	_missile_debug_log("GM_SPAWN: Called with pos=%s, owner=%s, rot=%.2f, vel=%s, type=%s" % [spawn_position, owner.name if owner else "null", rotation, initial_velocity, missile_type])

	if not scene:
		_missile_debug_log("GM_SPAWN: ERROR - missile scene is null")
		push_error("GameManager: missile scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		_missile_debug_log("GM_SPAWN: ERROR - No valid GameRoot found")
		push_error("GameManager: No valid GameRoot found for missile spawning")
		return null

	_missile_debug_log("GM_SPAWN: Instantiating missile scene...")
	var missile = scene.instantiate()
	missile.global_position = spawn_position
	# Apply rotation/velocity when provided so missiles start in correct direction
	if missile.has_method("set_rotation") or true:
		missile.rotation = rotation
	if initial_velocity != null and missile.has_method("set"):
		missile.set("velocity", initial_velocity)
	if owner != null and missile.has_method("set"):
		missile.set("owner_node", owner)
	# Set missile type if provided (supports BaseMissile.MissileType enum)
	if missile_type != null and missile.has_method("set"):
		missile.set("missile_type", missile_type)

	_missile_debug_log("GM_SPAWN: Adding missile to scene tree at %s" % spawn_root.get_path())
	_missile_debug_log("GM_SPAWN: Scene tree debug - spawn_root children: %d" % spawn_root.get_child_count())
	spawn_root.add_child(missile)
	active_missiles.append(missile)
	_missile_debug_log("GM_SPAWN: Missile added to tree - visible=%s, z_index=%d, modulate=%s" % [missile.visible, missile.z_index, missile.modulate])

	missile.tree_exiting.connect(_on_missile_freed.bind(missile))

	# If owner provided, nudge missile forward out of owner's collision if needed.
	if owner != null:
		var forward = Vector2.UP.rotated(rotation)
		var offset = 36.0
		# If owner defines a recommended forward offset, prefer that
		if owner.has_method("get") and owner.has("MISSILE_FORWARD_OFFSET"):
			offset = owner.get("MISSILE_FORWARD_OFFSET")
		# Simple heuristic: if missile is very close to owner, move it forward
		if missile.global_position.distance_to(owner.global_position) < offset:
			missile.global_position += forward * offset

	_missile_debug_log("GM_SPAWN: SUCCESS - Missile spawned at %s, final_pos=%s, active_count=%d" % [spawn_position, missile.global_position, active_missiles.size()])
	_debug_log("Spawned missile at " + str(spawn_position) + " from " + str(owner.name if owner else "unknown"))
	object_spawned.emit(missile, "missile")

	return missile

## Spawn enemy vehicle at specified location with roster ID
func spawn_enemy(scene: PackedScene, spawn_position: Vector2, roster_id: String) -> Node:
	if not scene:
		push_error("GameManager: enemy_scene is null")
		return null

	var spawn_root = get_game_root()
	if not spawn_root:
		push_error("GameManager: No valid GameRoot found for enemy spawning")
		return null

	var enemy = scene.instantiate()
	enemy.global_position = spawn_position

	# Set roster ID for AI and stats configuration
	if enemy.has_method("set_roster_id"):
		enemy.set_roster_id(roster_id)
	elif enemy.has_method("set_ai_type"):
		# Fallback for older AI systems
		enemy.set_ai_type(roster_id)

	spawn_root.add_child(enemy)
	active_enemies.append(enemy)

	enemy.tree_exiting.connect(_on_enemy_freed.bind(enemy))

	_debug_log("Spawned enemy with roster ID '" + roster_id + "' at " + str(spawn_position))
	object_spawned.emit(enemy, "enemy")

	return enemy

## Spawn enemy by archetype - selects random roster ID with matching archetype
func spawn_enemy_by_archetype(scene: PackedScene, spawn_position: Vector2, archetype: String) -> Node:
	if not AIProfileLoader:
		push_error("GameManager: AIProfileLoader not available for archetype spawning")
		return spawn_enemy(scene, spawn_position, "bumper")  # Fallback

	var matching_profiles = AIProfileLoader.get_profiles_by_archetype(archetype)
	if matching_profiles.is_empty():
		push_warning("GameManager: No profiles found for archetype '" + archetype + "', using bumper")
		return spawn_enemy(scene, spawn_position, "bumper")

	# Select random profile from matching archetype
	var random_profile = matching_profiles[randi() % matching_profiles.size()]
	var roster_id = random_profile.get("id", "bumper")

	_debug_log("Spawning enemy by archetype '" + archetype + "' - selected: " + roster_id)
	return spawn_enemy(scene, spawn_position, roster_id)

## Get all available archetypes for level design
func get_available_archetypes() -> Array:
	if not AIProfileLoader:
		return ["aggressor", "defender", "ambusher", "mini_boss"]

	var archetypes = []
	var loaded_ids = AIProfileLoader.get_loaded_roster_ids()
	for roster_id in loaded_ids:
		var profile = AIProfileLoader.get_profile(roster_id)
		var archetype = profile.get("archetype", "")
		if archetype != "" and archetype not in archetypes:
			archetypes.append(archetype)

	return archetypes

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
			var roster_id = spawn_data.get("roster_id", spawn_data.get("ai_type", "bumper"))
			return spawn_enemy(scene, spawn_position, roster_id)
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

func _on_missile_freed(missile: Node):
	active_missiles.erase(missile)
	object_destroyed.emit(missile, "missile")
	_debug_log("Missile destroyed, remaining: " + str(active_missiles.size()))

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
		"enemies": active_enemies.size(),
		"missiles": active_missiles.size()
	}

## Debug logging helper
func _debug_log(msg: String):
	if DEBUG_SPAWNING:
		print("[GameManager] ", msg)
