extends RefCounted
## Clutter: 1-HP pop-through set dressing. Layer semantics, one-hit death with
## the scatter puff spawned into current_scene, house-deco damage redraw, and
## the radar min-size gate math. Driven by tests/run_tests.gd.

const ClutterScene := preload("res://environment/clutter.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_clutter_layer_and_footprint() -> void:
	var c = ClutterScene.instantiate()
	c.footprint = 40.0
	t.root.add_child(c)
	t.check(c.collision_layer == 4, "clutter sits on obstacle layer")
	t.check(c.collision_mask == 0, "clutter collides into nothing")
	var shape: RectangleShape2D = c.get_node("Col").shape
	t.check(shape.size == Vector2(40, 40), "footprint reaches collision shape")
	var health = c.get_node("Health")
	t.check_approx(health.hp, 1.0, "clutter readies with 1 HP")
	t.root.remove_child(c)
	c.free()

func test_clutter_pops_on_one_hit() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container  # the pop spawns its puff here
	var c = ClutterScene.instantiate()
	c.kind = &"drift"
	container.add_child(c)
	c.get_node("Health").take_damage(1.0)
	t.check(c.is_queued_for_deletion(), "one hit frees the clutter")
	var puff_found := false
	for child in container.get_children():
		if child is CPUParticles2D:
			puff_found = true
	t.check(puff_found, "pop leaves a scatter puff in the scene")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_street_kinds_and_hydrant_spout() -> void:
	var kinds: Dictionary = load("res://environment/clutter.gd").KINDS
	for k in [&"pine", &"mailbox", &"sign", &"cone", &"bike", &"hydrant", &"bollard", &"pallet"]:
		t.check(kinds.has(k), "clutter: %s kind exists" % k)
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var hydrant = ClutterScene.instantiate()
	hydrant.kind = &"hydrant"
	container.add_child(hydrant)
	hydrant.get_node("Health").take_damage(1.0)
	var emitters := 0
	for c in container.get_children():
		if c is CPUParticles2D:
			emitters += 1
	t.check(emitters == 2, "hydrant: pop leaves puff + water spout (got %d)" % emitters)
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_pine_is_pop_through_snow_clutter() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var pine = ClutterScene.instantiate()
	pine.kind = &"pine"
	pine.footprint = 36.0
	pine.floor_index = 2
	container.add_child(pine)
	var shape := pine.get_node(^"Col").shape as RectangleShape2D
	var health := pine.get_node(^"Health") as Health
	t.check(shape.size == Vector2(36, 36) and pine.collision_layer == (4 | 16),
		"pine: small floor-2 hitbox stays below the radar and off other terraces")
	t.check(is_equal_approx(health.hp, 1.0),
		"pine: one-hit clutter health keeps dense groves momentum-light")
	health.take_damage(1.0)
	t.check(pine.is_queued_for_deletion(), "pine: one committed hit clears the lane")
	var puff_found := false
	for child in container.get_children():
		if child is CPUParticles2D:
			puff_found = true
	t.check(puff_found, "pine: destruction leaves the shared quiet scatter puff")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_floor_index_folds_layer_bit() -> void:
	var c = ClutterScene.instantiate()
	c.kind = &"bollard"
	c.floor_index = 2
	t.root.add_child(c)
	t.check(c.collision_layer == (4 | 16), "clutter: terrace bit joins the obstacle bit")
	t.root.remove_child(c)
	c.free()

func test_radar_gate_math() -> void:
	# Mirrors ui/radar.gd's MIN_BLIP skip: clutter-sized rects drop, houses stay.
	var radar_src = load("res://ui/radar.gd")
	var min_blip: float = radar_src.MIN_BLIP
	var clutter_rect := Rect2(Vector2.ZERO, Vector2(40, 40))
	var house_rect := Rect2(Vector2.ZERO, Vector2(176, 160))
	var pump_rect := Rect2(Vector2.ZERO, Vector2(64, 64))
	t.check(clutter_rect.size.x < min_blip and clutter_rect.size.y < min_blip,
		"40px clutter falls under the radar gate")
	t.check(not (house_rect.size.x < min_blip and house_rect.size.y < min_blip),
		"houses stay on the radar")
	t.check(not (pump_rect.size.x < min_blip and pump_rect.size.y < min_blip),
		"gas pumps stay on the radar")
