extends RefCounted
## LevelLoader tests: build the fixture level into a throwaway tree and assert
## node counts, collision layers, per-entity properties, and deterministic
## enemy randomization. Driven by tests/run_tests.gd.

const Schema := preload("res://levels/level_schema.gd")
const Loader := preload("res://levels/level_loader.gd")
const FIXTURE := "res://tests/fixtures/sample_level.json"

var t  # the runner: check()/check_approx() helpers + root access

func _init(runner) -> void:
	t = runner

## Parses the fixture and builds it under a container inside the test tree
## (so _ready fires). Caller must _done() the result.
func _build(rng_seed := 7) -> Dictionary:
	var level := Schema.parse(FileAccess.get_file_as_string(FIXTURE))
	var container := Node2D.new()
	t.root.add_child(container)
	Loader.build(level, container, rng_seed)
	return {"level": level, "container": container}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func _children_where(parent: Node, predicate: Callable) -> Array:
	var found := []
	for child in parent.get_children():
		if predicate.call(child):
			found.append(child)
	return found

func test_walls_enclose_bounds() -> void:
	var f := _build()
	var boundary: StaticBody2D = f.container.get_node("Boundary")
	t.check(boundary.collision_layer == 2, "boundary on wall layer")
	t.check(boundary.collision_mask == 0, "boundary masks nothing")
	var cols := _children_where(boundary, func(c: Node) -> bool: return c is CollisionShape2D)
	t.check(cols.size() == 4, "four wall collision shapes")
	var half := Vector2(f.level.bounds.width, f.level.bounds.height) * 0.5
	var min_x := 0.0
	var max_x := 0.0
	var min_y := 0.0
	var max_y := 0.0
	for col in cols:
		var ext: Vector2 = col.position + col.shape.size * 0.5
		max_x = maxf(max_x, ext.x)
		max_y = maxf(max_y, ext.y)
		min_x = minf(min_x, col.position.x - col.shape.size.x * 0.5)
		min_y = minf(min_y, col.position.y - col.shape.size.y * 0.5)
	t.check_approx(max_x, half.x, "walls reach right bound")
	t.check_approx(min_x, -half.x, "walls reach left bound")
	t.check_approx(max_y, half.y, "walls reach bottom bound")
	t.check_approx(min_y, -half.y, "walls reach top bound")
	_done(f)

func test_blocks_built() -> void:
	var f := _build()
	var blocks := _children_where(f.container, func(c: Node) -> bool:
		return c is StaticBody2D and c.collision_layer == 4)
	t.check(blocks.size() == 2, "two obstacle blocks")
	t.check_approx(blocks[0].position.x, -448.0, "block 1 position")
	var col: CollisionShape2D = blocks[1].get_node("Col")
	t.check_approx(col.shape.size.x, 256.0, "block 2 width from JSON")
	_done(f)

func test_terrain_zones_built() -> void:
	var f := _build()
	var zones := _children_where(f.container, func(c: Node) -> bool:
		return c is Area2D and c.collision_layer == 128)
	t.check(zones.size() == 3, "three terrain zones")
	var types := []
	for zone in zones:
		types.append(String(zone.terrain_type))
		t.check(zone.collision_mask == 0, "zone masks nothing")
	types.sort()
	t.check(types == ["dirt", "ice", "water"], "terrain types from JSON (got %s)" % [types])
	# dirt rect [-1152, -768, 640, 512] -> center (-832, -512)
	var dirt: Area2D = zones.filter(func(z) -> bool: return String(z.terrain_type) == "dirt")[0]
	t.check_approx(dirt.position.x, -832.0, "terrain rect converted to center x")
	t.check_approx(dirt.position.y, -512.0, "terrain rect converted to center y")
	_done(f)

func test_pickups_and_dummies_built() -> void:
	var f := _build()
	var pickups := _children_where(f.container, func(c: Node) -> bool:
		return c is Area2D and "kind" in c)
	t.check(pickups.size() == 2, "two pickups")
	var kinds := [pickups[0].kind, pickups[1].kind]
	kinds.sort()
	t.check(kinds == ["homing", "standard"], "pickup kinds from JSON")
	var dummies := _children_where(f.container, func(c: Node) -> bool:
		return c.is_in_group(&"dummies"))
	t.check(dummies.size() == 1, "one dummy")
	t.check_approx(dummies[0].get_node("Health").max_hp, 60.0, "dummy hp from JSON")
	_done(f)

func test_player_and_enemies_spawned() -> void:
	var f := _build()
	var players := _children_where(f.container, func(c: Node) -> bool:
		return c.is_in_group(&"player"))
	t.check(players.size() == 1, "exactly one player")
	t.check_approx(players[0].heading, -PI / 2, "heading_deg 0 -> nose up")
	var enemies := _children_where(f.container, func(c: Node) -> bool:
		return c.is_in_group(&"enemies"))
	t.check(enemies.size() == 2, "two enemies for two spawn markers")
	var ids := []
	for enemy in enemies:
		t.check(enemy.stats != null, "enemy has stats assigned")
		ids.append(enemy.stats.resource_path)
		t.check(enemy.get_node("Driver").mix.length() > 0.0, "enemy has an AI mix")
	t.check(ids[0] != ids[1], "enemy cars are distinct")
	_done(f)

func test_enemy_pick_is_seed_deterministic() -> void:
	var f1 := _build(42)
	var f2 := _build(42)
	var f3 := _build(43)
	var pick := func(f: Dictionary) -> Array:
		var ids := []
		for c in f.container.get_children():
			if c.is_in_group(&"enemies"):
				ids.append(c.stats.resource_path)
		return ids
	t.check(pick.call(f1) == pick.call(f2), "same seed -> same cars")
	# Different seeds usually differ; not asserted (both draws can collide).
	t.check(pick.call(f3).size() == 2, "other seed still fills both spawns")
	_done(f1)
	_done(f2)
	_done(f3)

func test_archetype_mix_shim() -> void:
	t.check(Loader.mix_for_car("cricket") == Vector3(1, 0, 0), "aggressor -> pure aggressor mix")
	t.check(Loader.mix_for_car("hammertoe") == Vector3(0, 1, 0), "ambusher -> pure ambusher mix")
	t.check(Loader.mix_for_car("bumper") == Vector3(0, 0, 1), "defender -> opportunist mix (shim)")
	t.check(Loader.mix_for_car("kandykane") == Vector3(1, 1, 1), "mini_boss -> full blend")
	t.check(Loader.mix_for_car("not_a_car") == Vector3(1, 0, 0), "unknown car -> aggressor fallback")

func test_pick_cars_distinct_and_excludes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# The roster minus the excluded car = the full pool, exactly the ask —
	# derived from roster.json so new cars never re-break this.
	var full := _roster_size() - 1
	var picks: Array = Loader.pick_cars(full, "kandykane", rng)
	t.check(picks.size() == full, "full pool ask returns %d picks" % full)
	t.check(not picks.has("kandykane"), "excluded car never picked")
	var unique := {}
	for id in picks:
		unique[id] = true
	t.check(unique.size() == picks.size(), "all picks distinct")

func test_pick_cars_clamps_over_ask() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Asking past the pool clamps — never wraps into duplicates or the
	# excluded car. (Warns; expected here.)
	var full := _roster_size() - 1
	var picks: Array = Loader.pick_cars(full + 12, "kandykane", rng)
	t.check(picks.size() == full, "over-ask clamps to pool size")
	t.check(not picks.has("kandykane"), "excluded car stays out on over-ask")
	var unique := {}
	for id in picks:
		unique[id] = true
	t.check(unique.size() == picks.size(), "clamped picks still distinct")

func _roster_size() -> int:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/roster.json"))
	return (data.characters as Array).size()
