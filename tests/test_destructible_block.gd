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

func test_block_dies_into_remains() -> void:
	var block = BlockScene.instantiate()
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(not block.is_queued_for_deletion() and block.is_inside_tree(),
		"remains: lethal damage flattens in place, never frees")
	t.check(block.visible, "remains: the rubble stays visible")
	t.check(block.collision_layer == 0 and block.collision_mask == 0,
		"remains: drive over it, shoot through it")
	t.check(not block.get_node("Vis").visible,
		"remains: the intact slab polygon stands down")
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
	t.check(not block.is_queued_for_deletion() and block.collision_layer == 0,
		"container: crumples into drive-over remains like any block")
	t.root.remove_child(block)
	block.free()

func test_opt_in_network_block_persists_as_tombstone() -> void:
	var block = BlockScene.instantiate()
	block.arena_net_id = 77
	t.root.add_child(block)
	block.get_node("Health").take_damage(999.0)
	t.check(not block.is_queued_for_deletion() and block.visible
		and block.collision_layer == 0,
		"arena block: networked death persists as visible noncolliding remains")
	var row: Dictionary = block.capture_arena_state([])
	t.check(int(row.flags) == 0 and float(row.hp) == 0.0,
		"arena block: tombstone repeats terminal state")
	t.root.remove_child(block)
	block.free()

func test_capital_styles_have_full_language() -> void:
	var block_src = load("res://environment/destructible_block.gd")
	var remains: Dictionary = block_src.REMAINS
	t.check(remains.has(&"iron_fence") and remains.has(&"food_truck"),
		"capital styles: iron_fence and food_truck speak the remains language")
	t.check(remains[&"iron_fence"][0] == &"crumple",
		"capital styles: black iron crumples (metal, never splinters)")
	var trucks: Array = block_src.TRUCK_PALETTES
	t.check(trucks.size() == 4, "capital styles: food trucks carry a four-color livery fleet")
	var gate = BlockScene.instantiate()
	gate.deco = &"iron_fence"
	gate.size = Vector2(160, 12)
	gate.max_hp = 30.0
	t.root.add_child(gate)
	t.check_approx(gate.get_node("Health").hp, 30.0,
		"iron fence: containment HP class, twice the picket")
	gate.get_node("Health").take_damage(30.0)
	t.check(not gate.is_queued_for_deletion() and gate.collision_layer == 0,
		"iron fence: crumples into flattened remains, never freed")
	t.root.remove_child(gate)
	gate.free()
	var truck = BlockScene.instantiate()
	truck.deco = &"food_truck"
	truck.size = Vector2(180, 84)
	truck.max_hp = 90.0
	truck.livery = 1
	t.root.add_child(truck)
	t.check(truck.livery >= 0 and truck.livery < trucks.size(),
		"food truck: livery override in range")
	truck.get_node("Health").take_damage(90.0)
	t.check(not truck.is_queued_for_deletion() and truck.collision_layer == 0,
		"food truck: dies into remains like every block")
	t.root.remove_child(truck)
	truck.free()

func test_chainlink_crumples_and_livery_overrides() -> void:
	var fence = BlockScene.instantiate()
	fence.deco = &"chainlink"
	fence.size = Vector2(150, 12)
	fence.max_hp = 12.0
	t.root.add_child(fence)
	t.check_approx(fence.get_node("Health").hp, 12.0, "chainlink: fender-tap HP class")
	fence.get_node("Health").take_damage(12.0)
	t.check(not fence.is_queued_for_deletion() and fence.collision_layer == 0,
		"chainlink: crumples into flattened mesh remains")
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
