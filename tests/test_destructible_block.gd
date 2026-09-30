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

func test_barrel_blast_keeps_authored_radius_and_damage() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var barrel = _blast_block(container, &"barrel", Vector2.ZERO, 30.0)
	var near = _blast_block(container, &"", Vector2(120, 0), 100.0)
	var far = _blast_block(container, &"", Vector2(140, 0), 100.0)
	await t.physics_frame
	barrel.get_node("Health").take_damage(999.0)
	await t.physics_frame
	t.check_approx(near.get_node("Health").hp, 75.0,
		"barrel: 120px target still takes exactly 25")
	t.check_approx(far.get_node("Health").hp, 100.0,
		"barrel: 140px target stays outside the 130px blast")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_tanker_blast_radius_damage_floor_and_self_exclusion() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var tanker = _blast_block(container, &"tanker", Vector2.ZERO, 100.0, 2)
	var near = _blast_block(container, &"", Vector2(190, 0), 100.0, 2)
	var far = _blast_block(container, &"", Vector2(210, 0), 100.0, 2)
	var upstairs = _blast_block(container, &"", Vector2(100, 0), 100.0, 3)
	var self_probe = _blast_block(container, &"tanker", Vector2(600, 0), 100.0, 2)
	await t.physics_frame
	self_probe._blast(200.0, 40.0)
	t.check_approx(self_probe.get_node("Health").hp, 100.0,
		"tanker: blast query excludes its own body")
	tanker.get_node("Health").take_damage(999.0)
	await t.physics_frame
	t.check_approx(near.get_node("Health").hp, 60.0,
		"tanker: 190px target takes exactly 40")
	t.check_approx(far.get_node("Health").hp, 100.0,
		"tanker: 210px target stays outside the 200px blast")
	t.check_approx(upstairs.get_node("Health").hp, 100.0,
		"tanker: same XY on another floor takes no damage")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_tanker_chains_through_barrel() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var tanker = _blast_block(container, &"tanker", Vector2.ZERO, 100.0)
	var barrel = _blast_block(container, &"barrel", Vector2(150, 0), 10.0)
	var beyond = _blast_block(container, &"", Vector2(250, 0), 100.0)
	await t.physics_frame
	tanker.get_node("Health").take_damage(999.0)
	await t.physics_frame
	await t.physics_frame
	t.check_approx(barrel.get_node("Health").hp, 0.0,
		"tanker chain: 40 damage kills the 10 HP barrel at 150px")
	t.check_approx(beyond.get_node("Health").hp, 75.0,
		"tanker chain: barrel blast reaches the body 100px beyond it")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_long_tanker_blast_follows_the_hull() -> void:
	# A 320x72 tank's fireball is a capsule along its spine (the hull length
	# minus its width): 200px from the axis all the way round, so the reach
	# past the ends is ~164px instead of the 40px a centred circle would leave.
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var tanker = BlockScene.instantiate()
	tanker.deco = &"tanker"
	tanker.size = Vector2(320, 72)
	tanker.max_hp = 100.0
	container.add_child(tanker)
	var off_the_end = _blast_block(container, &"", Vector2(300, 0), 100.0)
	var past_the_end = _blast_block(container, &"", Vector2(340, 0), 100.0)
	var beside = _blast_block(container, &"", Vector2(0, 190), 100.0)
	var wide = _blast_block(container, &"", Vector2(0, 210), 100.0)
	await t.physics_frame
	tanker.get_node("Health").take_damage(999.0)
	await t.physics_frame
	t.check_approx(off_the_end.get_node("Health").hp, 60.0,
		"long tanker: 300px along the spine is 176px off the hull and takes 40")
	t.check_approx(past_the_end.get_node("Health").hp, 100.0,
		"long tanker: 340px along the spine is past the 200px reach")
	t.check_approx(beside.get_node("Health").hp, 60.0,
		"long tanker: 190px beside the hull takes 40")
	t.check_approx(wide.get_node("Health").hp, 100.0,
		"long tanker: 210px beside the hull stays outside the blast")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_road_styles_draw_alive_dead_and_report_remains() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var flavors := {
		&"semi": &"crumple",
		&"tanker": &"scorch",
		&"hay": &"splinter",
		&"storefront": &"debris",
	}
	var sizes := {
		&"semi": Vector2(180, 72),
		&"tanker": Vector2(180, 72),
		&"hay": Vector2(72, 72),
		&"storefront": Vector2(140, 100),
	}
	var blocks: Array = []
	var x := 0.0
	for style: StringName in flavors:
		var block = BlockScene.instantiate()
		block.deco = style
		block.size = sizes[style]
		block.position = Vector2(x, 0)
		holder.add_child(block)
		blocks.append(block)
		x += 400.0
	await t.process_frame
	var block_src = load("res://environment/destructible_block.gd")
	for block in blocks:
		t.check(block_src.REMAINS[block.deco][0] == flavors[block.deco],
			"%s: reports its authored remains flavor" % block.deco)
		block.get_node("Health").take_damage(999.0)
	await t.process_frame
	for block in blocks:
		t.check(block.is_inside_tree() and block.collision_layer == 0,
			"%s: draws for one dead frame as drive-over remains" % block.deco)
	t.root.remove_child(holder)
	holder.free()

func test_storefront_front_defaults_and_all_sides_draw() -> void:
	var holder := Node2D.new()
	t.root.add_child(holder)
	var first = BlockScene.instantiate()
	first.deco = &"storefront"
	t.check(first.front == "south", "storefront: front defaults south")
	first.free()
	var x := 0.0
	for side in ["south", "north", "west", "east"]:
		var shop = BlockScene.instantiate()
		shop.deco = &"storefront"
		shop.front = side
		shop.position = Vector2(x, 0)
		holder.add_child(shop)
		x += 180.0
	await t.process_frame
	t.check(holder.get_child_count() == 4,
		"storefront: every authored front draws for a frame")
	for shop in holder.get_children():
		shop.get_node("Health").take_damage(999.0)
	await t.process_frame
	for shop in holder.get_children():
		t.check(shop.is_inside_tree() and shop.collision_layer == 0,
			"storefront: %s front draws alive and dead" % shop.front)
	t.root.remove_child(holder)
	holder.free()

func test_storefront_hvac_count_tracks_footprint() -> void:
	var shop = BlockScene.instantiate()
	shop.size = Vector2(384, 256)
	var broad_count: int = shop.storefront_hvac_count()
	shop.size = Vector2(192, 192)
	var compact_count: int = shop.storefront_hvac_count()
	t.check(broad_count == 2 and compact_count == 1,
		"storefront: 384x256 gets two HVAC units and 192x192 gets one")
	shop.free()

func _blast_block(parent: Node, style: StringName, at: Vector2,
		hp: float, floor_index: int = -1):
	var block = BlockScene.instantiate()
	block.deco = style
	block.position = at
	block.size = Vector2(2, 2) if style == &"" else Vector2(44, 44)
	block.max_hp = hp
	block.floor_index = floor_index
	parent.add_child(block)
	return block
