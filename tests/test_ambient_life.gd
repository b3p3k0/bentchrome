extends RefCounted
## Soft-target lifecycle, authoring determinism, and projectile non-cover rules.

const ActorScene := preload("res://environment/ambient_actor.tscn")
const PopulationScript := preload("res://environment/ambient_population.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")
const SplatScene := preload("res://environment/ambient_splat.tscn")
const DriveFXScript := preload("res://vehicles/drive_fx.gd")

var t

class FloorCar extends CharacterBody2D:
	var floor_index := -1

class FxController:
	var boosting := false
	var handbraking := false

class FxCar extends CharacterBody2D:
	var floor_index := -1
	var current_terrain: StringName = &"road"
	var heading := 0.0
	var height := 0.0
	var one_track := false
	var ctrl := FxController.new()
	func get_controller():
		return ctrl
	func body_metrics() -> Dictionary:
		return {"skid_points": [Vector2(-8, 0)] if one_track
			else [Vector2(-8, -5), Vector2(-8, 5)]}

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
	t.check(actor._dead, "ambient projectile: one contact marks actor dead immediately")
	t.check(not shot._spent, "ambient projectile: target never consumes the shot")
	await t.process_frame
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

func test_nonliving_soft_prop_leaves_debris_not_blood() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var cart = ActorScene.instantiate()
	cart.kind = &"hotdog_cart"
	cart.leaves_splat = false
	container.add_child(cart)
	cart.get_node("Health").take_damage(1.0)
	await t.process_frame
	var debris := 0
	var splats := 0
	for child in container.get_children():
		if child is CPUParticles2D:
			debris += 1
		elif child is AmbientSplat:
			splats += 1
	t.check(debris == 1 and splats == 0,
		"ambient prop: cart leaves one debris puff and no blood")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

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
	t.check(fast._dead, "ambient runover: a moving car pops the target")
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
	var level: Node = load("res://levels/downtown/downtown.tscn").instantiate()
	var life: Node = level.get_node("AmbientLife")
	var figures := 0
	var carts := 0
	var business := 0
	var vagrants := 0
	var police := 0
	var vendors := 0
	var found := {}
	for pop in life.get_children():
		for kind in pop.kinds:
			found[kind] = true
		if pop.kinds.has(&"hotdog_cart"):
			carts += pop.count
		else:
			figures += pop.count
		if pop.kinds.has(&"business_suit") or pop.kinds.has(&"business_dress"):
			business += pop.count
		elif pop.kinds.has(&"vagrant"):
			vagrants += pop.count
		elif pop.kinds.has(&"police"):
			police += pop.count
		elif pop.kinds.has(&"vendor"):
			vendors += pop.count
	t.check(figures == 18, "downtown ambience: reduced 18 living figures authored")
	t.check(carts == 2, "downtown ambience: two separate carts authored")
	t.check(business == 12 and vagrants == 2 and police == 2 and vendors == 2,
		"downtown ambience: reduced mix stays 12/2/2/2")
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
		and shot.impact_style == Projectile.ImpactStyle.NONE
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
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		for child in node.get_children():
			stack.append(child)
		if node is AmbientPopulation:
			for kind in node.kinds:
				out[kind] = int(out.get(kind, 0)) + node.count
			floors[node.name] = node.floor_index
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
	t.check(snowy.get(&"skier", 0) == 2 and snowy.get(&"deer", 0) == 5,
		"regional ambience: Snowy reduced to two skiers and five deer")
	t.check(snowy[&"_floors"].Skiers == 2 and snowy[&"_floors"].DeerHerd == 3,
		"regional ambience: skiers stay low and deer herd owns plateau")
	var docks := _authored_kind_counts("res://levels/dock/dock.tscn")
	t.check(docks.get(&"dock_worker", 0) == 15 and docks.get(&"police", 0) == 3,
		"regional ambience: Docks reduced to 15 workers and three police")
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

func test_splat_transfers_only_to_same_floor_vehicle() -> void:
	var splat = SplatScene.instantiate()
	splat.floor_index = 2
	t.root.add_child(splat)
	var same := FxCar.new()
	same.floor_index = 2
	same.add_to_group(&"vehicles")
	var same_fx = DriveFXScript.new()
	same_fx.name = "DriveFX"
	same.add_child(same_fx)
	t.root.add_child(same)
	splat._on_body_entered(same)
	t.check_approx(same_fx._blood_t, AmbientSplat.TIRE_CARRY,
		"blood tracks: same-floor splat transfers carry time")
	var other := FxCar.new()
	other.floor_index = 3
	other.add_to_group(&"vehicles")
	var other_fx = DriveFXScript.new()
	other_fx.name = "DriveFX"
	other.add_child(other_fx)
	t.root.add_child(other)
	splat._on_body_entered(other)
	t.check_approx(other_fx._blood_t, 0.0, "blood tracks: cross-floor tires stay clean")
	t.root.remove_child(splat)
	t.root.remove_child(same)
	t.root.remove_child(other)
	splat.free()
	same.free()
	other.free()

func test_drive_fx_uses_authored_tire_contacts_and_fades() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var car := FxCar.new()
	container.add_child(car)
	var fx = DriveFXScript.new()
	fx.name = "DriveFX"
	car.add_child(fx)
	car.velocity = Vector2(80, 0)
	fx.carry_splat(0.2)
	t.check(fx._blood_tracks.size() == 2, "blood tracks: ordinary car lays rear pair")
	fx._physics_process(0.1)
	t.check((fx._blood_tracks[0] as Line2D).get_point_count() == 1,
		"blood tracks: moving wheel appends world-space point")
	for line in fx._blood_tracks:
		t.check((line as Line2D).default_color == DriveFXScript.BLOOD_COLOR,
			"blood tracks: transfer uses dried-red color")
	fx._physics_process(0.2)
	t.check(fx._blood_tracks.is_empty() and is_zero_approx(fx._blood_t),
		"blood tracks: carry expires into fade without persistent state")
	var bike := FxCar.new()
	bike.one_track = true
	container.add_child(bike)
	var bike_fx = DriveFXScript.new()
	bike_fx.name = "DriveFX"
	bike.add_child(bike_fx)
	bike_fx.carry_splat()
	t.check(bike_fx._blood_tracks.size() == 1, "blood tracks: bike lays one centered line")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_blood_tracks_respect_shared_global_cap() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	for i in DriveFXScript.MAX_SKID_NODES:
		var occupied := Line2D.new()
		occupied.add_to_group(&"skidmarks")
		container.add_child(occupied)
	var car := FxCar.new()
	container.add_child(car)
	var fx = DriveFXScript.new()
	fx.name = "DriveFX"
	car.add_child(fx)
	fx.carry_splat()
	t.check(fx._blood_tracks.is_empty(), "blood tracks: shared skidmark cap is strict")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()
