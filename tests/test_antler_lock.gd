extends RefCounted
## Antler-lock integration: two aggressor AI charge head-on, wedge, and must
## BREAK APART (shun + reverse-out) instead of pushing forever. A third car
## gives the freed elk somewhere else to hunt (in a two-car world the no-camping
## fallback re-targets the shunned elk by design). Also unit-checks the
## escape-hop primitive on a real vehicle. Pumps real physics frames.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")
const SpecScript := preload("res://resources/status_effect.gd")

const LOCK_FRAMES := 360      # 6s window to charge, lock, and break apart
const SEPARATION := 300.0     # elk must get at least this far apart

var t

func _init(runner) -> void:
	t = runner

func _immunize(car: Node) -> void:
	car.get_node("Health").invulnerable = true
	var forever: StatusEffectSpec = SpecScript.new()
	forever.kind = &"invuln"
	forever.duration = 9999.0
	car.apply_effect(forever)

func _elk(container: Node, pos: Vector2, facing: float, car_id: String) -> Node:
	var e = EnemyScene.instantiate()
	e.position = pos
	e.rotation = facing  # transfers into heading at ready
	e.get_node("Driver").mix = Vector3(1, 0, 0)  # pure aggressor: charge the nearest
	container.add_child(e)
	e.set_stats(load("res://data/vehicles/%s.tres" % car_id))
	_immunize(e)
	return e

func test_head_on_elk_break_apart() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container  # armed AI spawn projectiles here
	var a := _elk(container, Vector2(0, 0), 0.0, "ghost")
	var b := _elk(container, Vector2(70, 0), PI, "smoky")
	var c := _elk(container, Vector2(1600, 0), PI, "splatkat")  # the other fight

	var max_sep := 0.0
	for i in LOCK_FRAMES:
		await t.physics_frame
		max_sep = maxf(max_sep, a.global_position.distance_to(b.global_position))
	t.check(max_sep > SEPARATION,
		"antler lock: elk broke apart (max separation %.0fpx)" % max_sep)

	t.current_scene = null
	t.root.remove_child(container)
	container.free()
	if is_instance_valid(c):
		pass  # freed with container

func test_escape_hop_pops_airborne() -> void:
	var car = VehicleScene.instantiate()
	t.root.add_child(car)
	car.escape_hop(Vector2.RIGHT)
	t.check(car.vz > 0.0, "hop: vertical launch")
	t.check(car.velocity.x > 300.0 and absf(car.velocity.y) < 1.0, "hop: launched along the direction")
	t.check_approx(car.heading, 0.0, "hop: re-aimed at the escape direction")
	await t.physics_frame
	await t.physics_frame
	t.check(car.height > 0.0, "hop: genuinely airborne")
	t.root.remove_child(car)
	car.free()
