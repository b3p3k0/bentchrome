class_name LevelLoader
extends RefCounted
## Builds a playable level from a validated LevelSchema dictionary. Only
## EntityCatalog-listed types are ever instantiated — level JSON can name no
## scene paths and runs no code, which is what makes fan levels safe to share.
## Callers must validate first; build() assumes schema-clean data.

const Schema := preload("res://levels/level_schema.gd")
const Catalog := preload("res://levels/entity_catalog.gd")
const GridFloorScript := preload("res://levels/grid_floor.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")

const ROSTER_PATH := "res://assets/data/roster.json"
const AI_PROFILES_PATH := "res://assets/data/ai_profiles.json"
const FLOOR_OVERSCAN := 512.0  # grid drawn past the walls, like the arena
# heading_deg 0 = nose up, clockwise; vehicle heading 0 = +X, so shift a quarter turn.
const HEADING_UP_OFFSET := -PI / 2

## INTERIM SHIM — ai_profiles.json archetypes -> EnemyDriver.mix weights
## (aggressor, ambusher, opportunist). The JSON's vocabulary predates the mix
## system ("defender" doesn't exist in-game; opportunist is the nearest fit).
## When a real AIProfileLoader lands, replace mix_for_car() and delete this.
const ARCHETYPE_MIX := {
	"aggressor": Vector3(1, 0, 0),
	"ambusher": Vector3(0, 1, 0),
	"opportunist": Vector3(0, 0, 1),
	"defender": Vector3(0, 0, 1),
	"mini_boss": Vector3(1, 1, 1),
}

static var _car_ids: Array = []
static var _archetype_by_id: Dictionary = {}

## Builds the level under `parent` (which must already be inside the tree so
## _ready fires per node). rng_seed >= 0 makes enemy picks deterministic (tests).
static func build(level: Dictionary, parent: Node2D, rng_seed := -1) -> void:
	var half: Vector2 = Vector2(level.bounds.width, level.bounds.height) * 0.5
	_add_floor(parent, half)
	_add_walls(parent, half)
	_add_blocks(level, parent)
	_add_terrain(level, parent)
	_add_pickups(level, parent)
	_add_dummies(level, parent)
	_add_player(level, parent)
	_add_enemies(level, parent, rng_seed)

static func _add_floor(parent: Node2D, half: Vector2) -> void:
	var floor: Node2D = GridFloorScript.new()
	floor.name = "GridFloor"
	floor.extent = half + Vector2(FLOOR_OVERSCAN, FLOOR_OVERSCAN)
	parent.add_child(floor)

static func _add_walls(parent: Node2D, half: Vector2) -> void:
	var boundary := StaticBody2D.new()
	boundary.name = "Boundary"
	boundary.collision_layer = 2
	boundary.collision_mask = 0
	parent.add_child(boundary)
	var t := Schema.WALL_THICKNESS
	# Horizontal walls span the full width; vertical walls the full height.
	# The corner overlap is harmless and leaves no gaps.
	_add_wall(boundary, "Top", Vector2(0, -half.y + t * 0.5), Vector2(half.x * 2, t))
	_add_wall(boundary, "Bottom", Vector2(0, half.y - t * 0.5), Vector2(half.x * 2, t))
	_add_wall(boundary, "Left", Vector2(-half.x + t * 0.5, 0), Vector2(t, half.y * 2))
	_add_wall(boundary, "Right", Vector2(half.x - t * 0.5, 0), Vector2(t, half.y * 2))

static func _add_wall(boundary: StaticBody2D, wall_name: String, pos: Vector2, size: Vector2) -> void:
	var vis := Polygon2D.new()
	vis.name = wall_name + "Vis"
	vis.position = pos
	vis.color = Catalog.WALL_COLOR
	vis.polygon = _rect_points(size * 0.5)
	boundary.add_child(vis)
	var col := CollisionShape2D.new()
	col.name = wall_name + "Col"
	col.position = pos
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	boundary.add_child(col)

static func _add_blocks(level: Dictionary, parent: Node2D) -> void:
	for i in level.blocks.size():
		var e: Dictionary = level.blocks[i]
		var size := Vector2(e.size[0], e.size[1])
		var block := StaticBody2D.new()
		block.name = "Block%d" % (i + 1)
		block.collision_layer = 4
		block.position = Vector2(e.pos[0], e.pos[1])
		var vis := Polygon2D.new()
		vis.name = "Vis"
		vis.color = Catalog.BLOCK_COLOR
		vis.polygon = _rect_points(size * 0.5)
		block.add_child(vis)
		var col := CollisionShape2D.new()
		col.name = "Col"
		var shape := RectangleShape2D.new()
		shape.size = size
		col.shape = shape
		block.add_child(col)
		parent.add_child(block)

static func _add_terrain(level: Dictionary, parent: Node2D) -> void:
	for i in level.terrain.size():
		var e: Dictionary = level.terrain[i]
		var size := Vector2(e.rect[2], e.rect[3])
		var zone := Area2D.new()
		zone.set_script(TerrainZoneScript)
		zone.name = "%sZone%d" % [str(e.type).capitalize(), i + 1]
		zone.collision_layer = 128
		zone.collision_mask = 0
		zone.terrain_type = StringName(e.type)
		zone.position = Vector2(e.rect[0], e.rect[1]) + size * 0.5
		var vis := Polygon2D.new()
		vis.name = "Vis"
		vis.color = Catalog.TERRAIN_COLORS[e.type]
		vis.polygon = _rect_points(size * 0.5)
		zone.add_child(vis)
		var col := CollisionShape2D.new()
		col.name = "Col"
		var shape := RectangleShape2D.new()
		shape.size = size
		col.shape = shape
		zone.add_child(col)
		parent.add_child(zone)

static func _add_pickups(level: Dictionary, parent: Node2D) -> void:
	var scene: PackedScene = load(Catalog.by_id("pickup_standard").scene)
	for i in level.pickups.size():
		var e: Dictionary = level.pickups[i]
		var pickup := scene.instantiate()
		pickup.name = "Ammo%d" % (i + 1)
		pickup.position = Vector2(e.pos[0], e.pos[1])
		pickup.kind = e.kind
		pickup.amount = int(e.amount)
		pickup.respawn_seconds = float(e.respawn_seconds)
		parent.add_child(pickup)

static func _add_dummies(level: Dictionary, parent: Node2D) -> void:
	var scene: PackedScene = load(Catalog.by_id("dummy").scene)
	for i in level.dummies.size():
		var e: Dictionary = level.dummies[i]
		var dummy := scene.instantiate()
		dummy.name = "Dummy%d" % (i + 1)
		dummy.position = Vector2(e.pos[0], e.pos[1])
		dummy.get_node("Health").max_hp = float(e.max_hp)
		parent.add_child(dummy)

static func _add_player(level: Dictionary, parent: Node2D) -> void:
	var scene: PackedScene = load(Catalog.by_id("player_spawn").scene)
	var player := scene.instantiate()
	player.name = "Vehicle"
	player.position = Vector2(level.player_spawn.pos[0], level.player_spawn.pos[1])
	# Vehicle._ready() adopts node rotation as heading, then zeroes rotation.
	player.rotation = deg_to_rad(float(level.player_spawn.heading_deg)) + HEADING_UP_OFFSET
	parent.add_child(player)

static func _add_enemies(level: Dictionary, parent: Node2D, rng_seed: int) -> void:
	if level.enemy_spawns.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var scene: PackedScene = load(Catalog.by_id("enemy_spawn").scene)
	var player_id := ""
	var gs := parent.get_node_or_null(^"/root/GameState")
	if gs:
		player_id = String(gs.selected_vehicle_id)
	var picks := pick_cars(level.enemy_spawns.size(), player_id, rng)
	for i in mini(picks.size(), level.enemy_spawns.size()):
		var enemy := scene.instantiate()
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = Vector2(level.enemy_spawns[i].pos[0], level.enemy_spawns[i].pos[1])
		enemy.stats = load("res://data/vehicles/%s.tres" % picks[i])
		enemy.get_node("Driver").mix = mix_for_car(picks[i])
		parent.add_child(enemy)

## Up to `count` roster ids — always distinct, never `exclude_id` (the player's
## car). If the roster can't cover the ask, returns fewer picks and warns;
## callers spawn that many enemies.
static func pick_cars(count: int, exclude_id: String, rng: RandomNumberGenerator) -> Array:
	_load_car_data()
	var pool := _car_ids.filter(func(id: String) -> bool: return id != exclude_id)
	if pool.size() < count:
		push_warning("pick_cars: %d enemies asked, only %d distinct cars — spawning fewer" % [count, pool.size()])
	# Fisher-Yates with the caller's RNG — Array.shuffle() isn't seedable.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, count)

static func mix_for_car(car_id: String) -> Vector3:
	_load_car_data()
	var archetype: String = _archetype_by_id.get(car_id, "aggressor")
	return ARCHETYPE_MIX.get(archetype, Vector3(1, 0, 0))

static func _load_car_data() -> void:
	if not _car_ids.is_empty():
		return
	var roster: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	for entry in roster.characters:
		_car_ids.append(String(entry.id))
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(AI_PROFILES_PATH))
	if typeof(profiles) == TYPE_DICTIONARY:
		for profile in profiles.get("profiles", []):
			_archetype_by_id[String(profile.get("id", ""))] = String(profile.get("archetype", "aggressor"))

static func _rect_points(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
