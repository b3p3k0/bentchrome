extends RefCounted
## Construction kit and living-site population remain readable, unscaled, and
## nonblocking while the porta surprise uses the normal soft-target contract.

const ArenaScene := preload("res://levels/construction/ground_floor_gore.tscn")
const MachineScene := preload("res://environment/construction_machine.tscn")
const PortaScene := preload("res://environment/porta_potty.tscn")
const ActorScene := preload("res://environment/ambient_actor.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_heavy_machine_footprints_are_permanent_floor_cover() -> void:
	var expected := {
		"bulldozer": Vector2(256, 128),
		"dump_truck": Vector2(320, 128),
		"cement_truck": Vector2(320, 128),
	}
	for kind in expected:
		var machine := MachineScene.instantiate() as ConstructionMachine
		machine.kind = kind
		machine.size = expected[kind]
		machine.floor_index = 1
		t.root.add_child(machine)
		var col := machine.get_node(^"Col") as CollisionShape2D
		t.check(machine.scale == Vector2.ONE and machine.collision_layer == (4 | 8),
			"site machine: %s is unscaled floor-1 cover" % kind)
		t.check((col.shape as RectangleShape2D).size == expected[kind],
			"site machine: %s collision matches authored silhouette" % kind)
		t.check(machine.get_node_or_null(^"Health") == null,
			"site machine: %s is permanent, not another destructible" % kind)
		t.root.remove_child(machine)
		machine.free()

func test_authored_worker_and_porta_budgets() -> void:
	var arena := ArenaScene.instantiate()
	var ambient := arena.get_node(^"AmbientLife")
	var floors := {1: 0, 2: 0, 3: 0}
	var total := 0
	for population in ambient.get_children():
		total += int(population.count)
		floors[int(population.floor_index)] += int(population.count)
	t.check(total == 16 and floors == {1: 10, 2: 4, 3: 2},
		"site life: workers distribute 10/4/2 across the three floors")
	var porta := arena.get_node(^"PortaRow").get_children()
	t.check(porta.size() == 8, "site life: west service row has eight cubicles")
	for cubicle in porta:
		var shape := (cubicle.get_node(^"Col") as CollisionShape2D).shape as RectangleShape2D
		t.check(shape.size == Vector2(64, 80),
			"site life: porta scene remains compact")
		t.check_approx(float(cubicle.max_hp), 20.0, "site life: porta is light 20HP cover")
	arena.free()

func test_worker_archetypes_and_public_panic() -> void:
	for kind in [&"construction_worker", &"wheelbarrow_worker", &"supply_worker"]:
		t.check(kind in AmbientActor.REGIONAL_KINDS,
			"site life: %s is registered ambient vocabulary" % kind)
	var actor := ActorScene.instantiate() as AmbientActor
	actor.kind = &"construction_worker"
	actor.actor_seed = 17
	t.root.add_child(actor)
	actor.global_position = Vector2(100, 0)
	actor.panic_from(Vector2.ZERO, 2.5)
	t.check_approx(actor._panic_t, 2.5, "site life: authored surprise sets requested panic time")
	t.check(actor._panic_dir.is_equal_approx(Vector2.RIGHT),
		"site life: public panic points away from the authored threat")
	t.root.remove_child(actor)
	actor.free()

func test_porta_roll_boundary_and_escape_spawn() -> void:
	t.check(PortaPotty.releases_worker(0.0) and PortaPotty.releases_worker(0.19999)
		and not PortaPotty.releases_worker(0.20),
		"site life: worker chance is exactly the lower 20 percent")
	var container := Node2D.new()
	t.root.add_child(container)
	var porta := PortaScene.instantiate() as PortaPotty
	porta.set_test_roll(0.1)
	container.add_child(porta)
	(porta.get_node(^"Health") as Health).take_damage(20.0)
	await t.process_frame
	await t.process_frame
	var escaped := 0
	for node in container.get_children():
		if node is AmbientActor and node.kind == &"construction_worker":
			escaped += 1
			t.check(node.collision_layer == AmbientActor.SOFT_TARGET_LAYER,
				"site life: escapee stays on the nonblocking soft-target layer")
	t.check(escaped == 1, "site life: successful roll releases exactly one worker")
	t.root.remove_child(container)
	container.free()
