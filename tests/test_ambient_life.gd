extends RefCounted
## Soft-target lifecycle, authoring determinism, and projectile non-cover rules.

const ActorScene := preload("res://environment/ambient_actor.tscn")
const PopulationScript := preload("res://environment/ambient_population.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")

var t

class FloorCar extends CharacterBody2D:
	var floor_index := -1

func _init(runner) -> void:
	t = runner

func test_actor_is_one_hp_nonblocking_soft_target() -> void:
	var actor = ActorScene.instantiate()
	t.root.add_child(actor)
	t.check(actor is Area2D, "ambient: actor is a nonblocking area")
	t.check(actor.collision_layer == (1 << 9), "ambient: actor owns soft-target layer")
	t.check(actor.collision_mask == 1, "ambient: actor only observes vehicle bodies")
	t.check_approx(actor.get_node("Health").hp, 1.0, "ambient: actor has one HP")
	t.check(not actor.is_in_group(&"vehicles") and not actor.is_in_group(&"enemies"),
		"ambient: actor never joins combat targeting groups")
	t.root.remove_child(actor)
	actor.free()

func test_population_is_deterministic_and_staggers_route() -> void:
	var curve := Curve2D.new()
	curve.add_point(Vector2(-100, 0))
	curve.add_point(Vector2(100, 0))
	var a = PopulationScript.new()
	a.count = 4
	var route_kinds: Array[StringName] = [&"civilian", &"deer"]
	a.kinds = route_kinds
	a.movement = AmbientActor.Movement.ROUTE
	a.route = curve
	a.seed_offset = 7
	var b = PopulationScript.new()
	b.count = 4
	b.kinds = a.kinds
	b.movement = a.movement
	b.route = curve
	b.seed_offset = 7
	t.root.add_child(a)
	t.root.add_child(b)
	t.check(a.get_child_count() == 4 and b.get_child_count() == 4,
		"ambient population: exact authored counts spawn")
	for i in 4:
		var aa: AmbientActor = a.get_child(i)
		var bb: AmbientActor = b.get_child(i)
		t.check_approx(aa.route_progress, curve.get_baked_length() * float(i) / 4.0,
			"ambient population: route progress is staggered %d" % i)
		t.check(aa.actor_seed == bb.actor_seed and is_equal_approx(aa.move_speed, bb.move_speed),
			"ambient population: seed reproduces actor %d" % i)
	t.root.remove_child(a)
	t.root.remove_child(b)
	a.free()
	b.free()

func test_projectile_kills_soft_target_without_becoming_spent() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var actor = ActorScene.instantiate()
	container.add_child(actor)
	var shot = ProjectileScene.instantiate()
	container.add_child(shot)
	var shooter := Node2D.new()
	shot.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 2.0, 1.0, shooter)
	shot._on_area_entered(actor)
	t.check(actor.is_queued_for_deletion(), "ambient projectile: one contact pops actor")
	t.check(not shot._spent, "ambient projectile: target never consumes the shot")
	var splat_found := false
	for child in container.get_children():
		if child is AmbientSplat:
			splat_found = true
	t.check(splat_found, "ambient death: living target leaves splat")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()
	shooter.free()

func test_harmless_projectile_opts_out() -> void:
	var actor = ActorScene.instantiate()
	var shot = ProjectileScene.instantiate()
	t.root.add_child(actor)
	t.root.add_child(shot)
	shot.harms_ambient = false
	var shooter := Node2D.new()
	shot.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 0.0, 1.0, shooter)
	shot._on_area_entered(actor)
	t.check_approx(actor.get_node("Health").hp, 1.0,
		"ambient projectile: harmless cosmetic round cannot pop actors")
	t.root.remove_child(actor)
	t.root.remove_child(shot)
	actor.free()
	shot.free()
	shooter.free()

func test_vehicle_contact_requires_runover_speed_and_same_floor() -> void:
	var slow = ActorScene.instantiate()
	var fast = ActorScene.instantiate()
	fast.leaves_splat = false
	var other_floor = ActorScene.instantiate()
	slow.floor_index = 2
	fast.floor_index = 2
	other_floor.floor_index = 3
	t.root.add_child(slow)
	t.root.add_child(fast)
	t.root.add_child(other_floor)
	var car := FloorCar.new()
	car.add_to_group(&"vehicles")
	car.floor_index = 2
	car.velocity = Vector2(50, 0)
	slow._on_body_entered(car)
	t.check_approx(slow.get_node("Health").hp, 1.0,
		"ambient runover: a crawling car cannot kill")
	car.velocity = Vector2(120, 0)
	fast._on_body_entered(car)
	t.check(fast.is_queued_for_deletion(), "ambient runover: a moving car pops the target")
	other_floor._on_body_entered(car)
	t.check_approx(other_floor.get_node("Health").hp, 1.0,
		"ambient runover: cross-floor wheels cannot touch the target")
	t.root.remove_child(slow)
	t.root.remove_child(fast)
	t.root.remove_child(other_floor)
	slow.free()
	fast.free()
	other_floor.free()
	car.free()

func test_splat_lifetime_is_five_seconds() -> void:
	var splat := AmbientSplat.new()
	t.root.add_child(splat)
	splat._process(AmbientSplat.LIFETIME - 0.1)
	t.check(not splat.is_queued_for_deletion(), "ambient splat: lives until five seconds")
	splat._process(0.2)
	t.check(splat.is_queued_for_deletion(), "ambient splat: cleans up after five seconds")
	t.root.remove_child(splat)
	splat.free()

func test_downtown_population_budget_and_kinds() -> void:
	var level: Node = load("res://levels/arena/arena.tscn").instantiate()
	var life: Node = level.get_node("AmbientLife")
	var figures := 0
	var carts := 0
	var found := {}
	for pop in life.get_children():
		for kind in pop.kinds:
			found[kind] = true
		if pop.kinds.has(&"hotdog_cart"):
			carts += pop.count
		else:
			figures += pop.count
	t.check(figures == 22, "downtown ambience: exact 22 living figures authored")
	t.check(carts == 3, "downtown ambience: three separate carts authored")
	for kind in AmbientActor.DOWNTOWN_KINDS:
		t.check(found.has(kind), "downtown ambience: kind present %s" % kind)
	level.free()

func test_police_round_is_harmless_and_ignores_ambient() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var officer = ActorScene.instantiate()
	officer.kind = &"police"
	container.add_child(officer)
	officer._fire_police(Vector2.RIGHT)
	var shot: Projectile = null
	for child in container.get_children():
		if child is Projectile:
			shot = child
	t.check(shot != null and is_zero_approx(shot.damage),
		"downtown police: single tracer carries zero damage")
	t.check(shot != null and not shot.harms_ambient
		and (shot.collision_mask & AmbientActor.SOFT_TARGET_LAYER) == 0,
		"downtown police: tracer cannot kill ambient figures")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_police_range_and_line_of_sight_gate() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var officer = ActorScene.instantiate()
	officer.kind = &"police"
	container.add_child(officer)
	var car := FloorCar.new()
	car.add_to_group(&"player")
	car.add_to_group(&"vehicles")
	car.position = Vector2(600, 0)
	container.add_child(car)
	t.check(officer.police_target() == null, "downtown police: ignores players beyond range")
	car.position = Vector2(300, 0)
	await t.physics_frame
	t.check(officer.police_target() == car, "downtown police: acquires in-range same-floor player")
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 120)
	col.shape = shape
	wall.add_child(col)
	wall.position = Vector2(150, 0)
	container.add_child(wall)
	await t.physics_frame
	t.check(not officer._police_los(car), "downtown police: wall blocks harmless fire")
	t.root.remove_child(container)
	container.free()

func _authored_kind_counts(scene_path: String) -> Dictionary:
	var level: Node = load(scene_path).instantiate()
	var out := {}
	var floors := {}
	var life: Node = level.get_node("AmbientLife")
	for pop in life.get_children():
		for kind in pop.kinds:
			out[kind] = int(out.get(kind, 0)) + pop.count
		floors[pop.name] = pop.floor_index
	out[&"_floors"] = floors
	level.free()
	return out

func test_regional_population_budgets_and_floor_authorship() -> void:
	var suburbs := _authored_kind_counts("res://levels/suburbs/suburbs.tscn")
	t.check(suburbs.get(&"jogger", 0) == 5 and suburbs.get(&"cyclist", 0) == 4,
		"regional ambience: Suburbs runners and cyclists hit budget")
	t.check(suburbs.get(&"dog", 0) == 2 and suburbs.get(&"skateboarder", 0) == 2
		and suburbs.get(&"mower", 0) == 3 and suburbs.get(&"police", 0) == 2,
		"regional ambience: Suburbs exact 18 actors authored")
	var snowy := _authored_kind_counts("res://levels/snowy/snowy.tscn")
	t.check(snowy.get(&"skier", 0) == 3 and snowy.get(&"deer", 0) == 6,
		"regional ambience: Snowy exact three skiers and six deer")
	t.check(snowy[&"_floors"].Skiers == 2 and snowy[&"_floors"].DeerHerd == 3,
		"regional ambience: skiers stay low and deer herd owns plateau")
	var docks := _authored_kind_counts("res://levels/dock/dock.tscn")
	t.check(docks.get(&"dock_worker", 0) == 19 and docks.get(&"police", 0) == 3,
		"regional ambience: Docks exact 22 actors authored")
	t.check(docks[&"_floors"].LowlandWorkers == 1 and docks[&"_floors"].QuayWorkers == 2
		and docks[&"_floors"].DeckWorkers == 3,
		"regional ambience: Docks workers explicitly span all terraces")

func test_mowers_are_route_locked_and_actor_scale_stays_below_bike() -> void:
	var level: Node = load("res://levels/suburbs/suburbs.tscn").instantiate()
	var life: Node = level.get_node("AmbientLife")
	for name in [&"MowerA", &"MowerB", &"MowerC"]:
		var mower = life.get_node(String(name))
		t.check(mower.movement == AmbientActor.Movement.ROUTE and not mower.reacts_to_cars,
			"regional ambience: %s stays on its yard loop" % name)
	level.free()
	var actor = ActorScene.instantiate()
	var radius: float = actor.get_node("CollisionShape2D").shape.radius
	t.check(radius < 12.0, "regional ambience: soft target is smaller than Mr Ghastly's bike")
	actor.free()
