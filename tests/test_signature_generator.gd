extends RefCounted
## Signature generator: shared bolt paint, threshold cadence, impartial floor-
## gated damage, blast language, and repeated LAN state.

const GeneratorScene := preload("res://environment/power_generator.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const ArenaScene := preload("res://levels/construction/ground_floor_gore.tscn")
const ArcScene := preload("res://environment/electric_arc_fx.tscn")
const GeneratorScript := preload("res://environment/power_generator.gd")
const State := preload("res://game/net/arena_state.gd")

var t

func _init(runner) -> void:
	t = runner

func _vehicle(parent: Node, pos: Vector2, floor_index: int) -> Vehicle:
	var car := VehicleScene.instantiate() as Vehicle
	car.position = pos
	car.start_floor = floor_index
	parent.add_child(car)
	return car

func test_shared_electric_arc_layers_and_geometry() -> void:
	var fx: Node = ArcScene.instantiate()
	t.root.add_child(fx)
	fx.set_arc(Vector2.ZERO, Vector2(180, 0), 42)
	t.check(fx.glow != null and fx.core != null and fx.sparks != null,
		"electric arc: glow/core/sparks are one reusable presentation")
	t.check_approx(fx.glow.width, 7.0, "electric arc: Taser glow width preserved")
	t.check_approx(fx.core.width, 2.5, "electric arc: Taser core width preserved")
	t.check(fx.core.points.size() >= 4 and fx.core.points == fx.glow.points,
		"electric arc: both layers share one jagged endpoint path")
	t.root.remove_child(fx)
	fx.free()

func test_warning_active_cooldown_and_floor_gate() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var gen: Node = GeneratorScene.instantiate()
	gen.authority_override = "authority"
	container.add_child(gen)
	var near := _vehicle(container, Vector2(260, 0), 1)
	var overhead := _vehicle(container, Vector2(0, 260), 3)
	await t.physics_frame
	var gen_health := gen.get_node(^"Health") as Health
	gen_health.take_damage(GeneratorScript.MAX_HP - GeneratorScript.ARM_HP)
	t.check(gen.phase == GeneratorScript.Phase.WARNING
		and is_equal_approx(gen.phase_timer, GeneratorScript.WARNING_SECONDS),
		"generator: crossing 25 percent begins immediate warning")
	gen.tick(GeneratorScript.WARNING_SECONDS)
	t.check(gen.phase == GeneratorScript.Phase.ACTIVE,
		"generator: warning resolves into the two-second burst")
	var near_health := near.get_node(^"Health") as Health
	var overhead_health := overhead.get_node(^"Health") as Health
	var before := near_health.hp
	gen.tick(1.0)
	t.check_approx(near_health.hp, before - GeneratorScript.ARC_DPS,
		"generator: active arc deals flat 8 dps")
	t.check_approx(overhead_health.hp, overhead_health.max_hp,
		"generator: floor-3 car above the cabinet is untouched")
	t.check(near.get_speed_scale() <= GeneratorScript.INTERFERENCE + 0.001,
		"generator: active latch refreshes Smoky's brief interference")
	gen.tick(1.0)
	t.check(gen.phase == GeneratorScript.Phase.COOLDOWN
		and is_equal_approx(gen.phase_timer, GeneratorScript.COOLDOWN_SECONDS),
		"generator: full burst starts an exact sixty-second cooldown")
	gen.tick(GeneratorScript.COOLDOWN_SECONDS)
	t.check(gen.phase == GeneratorScript.Phase.WARNING,
		"generator: cooldown returns through the same readable warning")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_cover_blocks_arc() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var gen: Node = GeneratorScene.instantiate()
	gen.authority_override = "authority"
	container.add_child(gen)
	var car := _vehicle(container, Vector2(320, 0), 1)
	var cover := StaticBody2D.new()
	cover.position = Vector2(190, -20)
	cover.collision_layer = 8
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 180)
	col.shape = shape
	cover.add_child(col)
	container.add_child(cover)
	await t.physics_frame
	var health := car.get_node(^"Health") as Health
	gen._set_phase(GeneratorScript.Phase.ACTIVE, 2.0)
	gen.tick(1.0)
	t.check_approx(health.hp, health.max_hp, "generator: floor-correct cover breaks the latch")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_death_blast_falloff_shove_and_wasteland_attribution() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var gen: Node = GeneratorScene.instantiate()
	gen.authority_override = "authority"
	container.add_child(gen)
	var car := _vehicle(container, Vector2(210, 0), 1)
	car.last_attacker = car
	await t.physics_frame
	var health := car.get_node(^"Health") as Health
	(gen.get_node(^"Health") as Health).take_damage(GeneratorScript.MAX_HP)
	await t.physics_frame
	await t.physics_frame
	t.check(health.hp < health.max_hp and health.hp > health.max_hp - GeneratorScript.BLAST_DAMAGE_NEAR,
		"generator: radial damage falls between authored near/edge values")
	t.check(car.velocity.x > 0.0, "generator: death blast shoves outward without scaling bodies")
	t.check(car.last_attacker == null, "generator: environmental kill attribution clears to wasteland")
	t.check(gen.phase == GeneratorScript.Phase.DEAD and gen.collision_layer == 0,
		"generator: charred tombstone is persistent and nonblocking")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_state_capture_and_client_application() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var host: Node = GeneratorScene.instantiate()
	host.authority_override = "authority"
	container.add_child(host)
	var target := _vehicle(container, Vector2(260, 0), 1)
	await t.physics_frame
	(host.get_node(^"Health") as Health).take_damage(GeneratorScript.MAX_HP - GeneratorScript.ARM_HP)
	host.tick(GeneratorScript.WARNING_SECONDS)
	host.tick(0.1)
	var row: Dictionary = host.capture_arena_state([target])
	t.check((int(row.flags) & State.ACTIVE) != 0 and int(row.targets) == 1,
		"generator net: host row carries active target bit")
	var client: Node = GeneratorScene.instantiate()
	client.position = Vector2(800, 0)
	client.authority_override = "client"
	container.add_child(client)
	row["_actors"] = [target]
	client.apply_arena_state(row, false)
	t.check(client.phase == GeneratorScript.Phase.ACTIVE
		and absf((client.get_node(^"Health") as Health).hp - GeneratorScript.ARM_HP) < 2.0,
		"generator net: client mirrors phase and quantized HP")
	t.check(client._targets == [target], "generator net: actor mask resolves onto client target")
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_ground_floor_ids_are_unique_and_complete() -> void:
	var arena := ArenaScene.instantiate()
	var ids := {}
	for node in arena.find_children("*", "Node", true, false):
		var id_v: Variant = node.get("arena_net_id")
		if id_v is int and int(id_v) > 0:
			ids[int(id_v)] = true
	t.check(ids.size() == 30,
		"generator net: generator, portas, and every synced breakable have unique IDs")
	var required: Array[int] = [1]
	for id in range(10, 18):
		required.append(id)
	for id in range(20, 41):
		required.append(id)
	for id in required:
		t.check(ids.has(id), "generator net: stable arena id %d exists" % id)
	arena.free()
