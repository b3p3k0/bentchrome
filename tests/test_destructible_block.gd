extends RefCounted
## Destructible block: block-layer semantics, exported size applied to visuals
## and collision, damage tint, and death -> freed. Driven by tests/run_tests.gd.

const BlockScene := preload("res://environment/destructible_block.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_block_layer_and_size() -> void:
	var block = BlockScene.instantiate()
	block.size = Vector2(192, 64)
	t.root.add_child(block)
	t.check(block.collision_layer == 4, "block sits on obstacle layer")
	t.check(block.collision_mask == 0, "block collides into nothing")
	var shape: RectangleShape2D = block.get_node("Col").shape
	t.check(shape.size == Vector2(192, 64), "exported size reaches collision shape")
	var vis: Polygon2D = block.get_node("Vis")
	t.check(vis.polygon[2] == Vector2(96, 32), "exported size reaches visual polygon")
	t.root.remove_child(block)
	block.free()

func test_block_hp_override_and_tint() -> void:
	var block = BlockScene.instantiate()
	block.max_hp = 40.0
	t.root.add_child(block)
	var health = block.get_node("Health")
	t.check_approx(health.hp, 40.0, "hp follows exported max_hp despite child-first ready")
	var base: Color = block.get_node("Vis").color
	health.take_damage(20.0)
	t.check_approx(health.hp, 20.0, "damage lands")
	t.check(block.get_node("Vis").color != base, "damage tints toward rubble")
	t.root.remove_child(block)
	block.free()

func test_block_dies_and_frees() -> void:
	var block = BlockScene.instantiate()
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(block.is_queued_for_deletion(), "lethal damage frees the block")
	t.root.remove_child(block)
	block.free()

func test_container_deco_and_floor_bit() -> void:
	var block = BlockScene.instantiate()
	block.deco = &"container"
	block.size = Vector2(160, 64)
	block.floor_index = 3
	t.root.add_child(block)
	t.check(block.collision_layer == (4 | 32), "container: terrace bit joins the obstacle bit")
	block.get_node("Health").take_damage(999.0)
	t.check(block.is_queued_for_deletion(), "container: breaks open like any block")
	t.root.remove_child(block)
	block.free()

func test_opt_in_network_block_persists_as_tombstone() -> void:
	var block = BlockScene.instantiate()
	block.arena_net_id = 77
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(not block.is_queued_for_deletion() and not block.visible
		and block.collision_layer == 0,
		"arena block: networked death persists hidden and noncolliding")
	var row: Dictionary = block.capture_arena_state([])
	t.check(int(row.flags) == 0 and float(row.hp) == 0.0,
		"arena block: tombstone repeats terminal state")
	t.root.remove_child(block)
	block.free()

func test_chainlink_crumples_and_livery_overrides() -> void:
	var fence = BlockScene.instantiate()
	fence.deco = &"chainlink"
	fence.size = Vector2(150, 12)
	fence.max_hp = 12.0
	t.root.add_child(fence)
	t.check_approx(fence.get_node("Health").hp, 12.0, "chainlink: fender-tap HP class")
	fence.get_node("Health").take_damage(12.0)
	t.check(fence.is_queued_for_deletion(), "chainlink: crumples like any block")
	t.root.remove_child(fence)
	fence.free()
	var block_src = load("res://environment/destructible_block.gd")
	var palettes: Array = block_src.CONTAINER_PALETTES
	var box = BlockScene.instantiate()
	box.deco = &"container"
	box.livery = 2
	t.root.add_child(box)
	t.check(box.livery >= 0 and box.livery < palettes.size(), "container: livery override in range")
	t.root.remove_child(box)
	box.free()

func test_cross_floor_blast_is_gated() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var barrel = BlockScene.instantiate()
	barrel.deco = &"barrel"
	barrel.size = Vector2(44, 44)
	barrel.max_hp = 30.0
	barrel.floor_index = 2  # dock-level drum
	container.add_child(barrel)
	var crate = BlockScene.instantiate()
	crate.position = Vector2(80, 0)  # inside the 130px blast, but a roof up
	crate.floor_index = 3
	container.add_child(crate)
	await t.physics_frame
	var crate_health = crate.get_node("Health")
	var before: float = crate_health.hp
	barrel.get_node("Health").take_damage(999.0)
	await t.physics_frame
	t.check(crate_health.hp >= before, "barrel: dock blast doesn't cook the roof")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_barrel_blast_damages_neighbors() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container  # the death explosion spawns here
	var barrel = BlockScene.instantiate()
	barrel.deco = &"barrel"
	barrel.size = Vector2(44, 44)
	barrel.max_hp = 30.0
	container.add_child(barrel)
	var crate = BlockScene.instantiate()
	crate.position = Vector2(80, 0)  # inside the 130px blast
	container.add_child(crate)
	await t.physics_frame  # physics server needs a step to see the bodies
	var crate_health = crate.get_node("Health")
	var before: float = crate_health.hp
	barrel.get_node("Health").take_damage(999.0)
	await t.physics_frame  # deferred blast flushes
	t.check(crate_health.hp < before, "barrel: blast damages neighbors (%.0f -> %.0f)" % [before, crate_health.hp])
	t.current_scene = null
	t.root.remove_child(container)
	container.free()
