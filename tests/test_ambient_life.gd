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
