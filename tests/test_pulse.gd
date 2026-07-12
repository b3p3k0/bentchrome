extends RefCounted
## Pulse Wave (the PULSE Kind): the expanding front bills closer victims
## harder, shoves radially exactly once, pops the caster airborne, respects
## floors and launch_immune, and the AI holds the blast for point-blank.
## Fixture hygiene: stats before add_child, one physics frame to register
## bodies, then manual ticks with processing off. Driven by run_tests.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")
const SpecialScript := preload("res://vehicles/special_controller.gd")

var t

func _init(runner) -> void:
	t = runner

class StubRack:
	extends RefCounted
	var def: WeaponDef
	func selected_def() -> WeaponDef:
		return def

func _pulse_def() -> WeaponDef:
	var def := WeaponDef.new()
	def.display_name = "Pulse Wave"
	def.kind = WeaponDef.Kind.PULSE
	def.damage = 35.0
	def.projectile_speed = 600.0
	def.projectile_lifetime = 0.45  # range = 270px
	return def

func _car(at: Vector2) -> Node:
	var car = VehicleScene.instantiate()
	car.faction = &"enemies"
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	car.position = at
	t.root.add_child(car)
	return car

func _done(car: Node) -> void:
	t.root.remove_child(car)
	car.free()

func _settle(cars: Array) -> void:
	await t.physics_frame
	for car in cars:
		car.set_physics_process(false)
		car.get_node("SpecialController").set_physics_process(false)
		car.velocity = Vector2.ZERO
		car.vz = 0.0
		car.height = 0.0

func _cast(car: Node) -> Node:
	var sc = car.get_node("SpecialController")
	sc.set_weapon(_pulse_def())
	t.check(sc.activate(true, car.global_position, Vector2.RIGHT, car), "pulse: activation fires")
	return sc

func test_falloff_hits_near_harder_and_shoves_once() -> void:
	var caster = _car(Vector2.ZERO)
	var near = _car(Vector2(80, 0))
	var far = _car(Vector2(0, 240))
	await _settle([caster, near, far])
	var sc = _cast(caster)
	for i in 10:  # 0.5s of ticks — the front crosses the whole range
		sc._pulse_tick(0.05)
	var near_loss: float = near.get_node("Health").max_hp - near.get_node("Health").hp
	var far_loss: float = far.get_node("Health").max_hp - far.get_node("Health").hp
	t.check(near_loss > 0.0 and far_loss > 0.0, "pulse: both victims inside 270px take damage")
	t.check(near_loss > far_loss, "pulse: falloff bills near (%.1f) harder than far (%.1f)" % [near_loss, far_loss])
	t.check(near.velocity.x > 0.0 and absf(near.velocity.y) < 1.0, "pulse: shove points away from center")
	t.check(near.velocity.length() > far.velocity.length(), "pulse: shove also falls off")
	var vel_after: Vector2 = near.velocity
	sc._pulse_def = _pulse_def()  # fake a still-running wave; hit set must hold
	sc._pulse_tick(0.05)
	t.check(near.velocity == vel_after, "pulse: the front crosses each body once")
	sc._end_pulse()
	_done(caster)
	_done(near)
	_done(far)

func test_caster_hops_and_wave_detaches() -> void:
	var caster = _car(Vector2.ZERO)
	await _settle([caster])
	var sc = _cast(caster)
	t.check(caster.vz > 0.0, "pulse: caster pops airborne (vz %.0f)" % caster.vz)
	t.check(sc._pulse_origin == Vector2.ZERO, "pulse: wave anchored at cast position")
	sc._end_pulse()
	t.check(sc._pulse_ring == null, "pulse: ring cleaned up on end")
	_done(caster)

func test_launch_immune_takes_damage_holds_course() -> void:
	var caster = _car(Vector2.ZERO)
	var rig = _car(Vector2(80, 0))
	rig.launch_immune = true
	await _settle([caster, rig])
	var sc = _cast(caster)
	var hp_before: float = rig.get_node("Health").hp
	for i in 10:
		sc._pulse_tick(0.05)
	t.check(rig.get_node("Health").hp < hp_before, "pulse: immune rig still takes the blast")
	t.check(rig.velocity == Vector2.ZERO, "pulse: immune rig is never shoved")
	sc._end_pulse()
	_done(caster)
	_done(rig)

func test_expires_after_lifetime() -> void:
	var caster = _car(Vector2.ZERO)
	await _settle([caster])
	var sc = _cast(caster)
	for i in 12:  # 0.6s > 0.45s lifetime
		sc._pulse_tick(0.05)
	t.check(sc._pulse_def == null, "pulse: wave retires after its lifetime")
	t.check(sc.activate(true, caster.global_position, Vector2.RIGHT, caster),
		"pulse: refire works after the wave retires")
	sc._end_pulse()
	_done(caster)

func test_ai_holds_pulse_until_point_blank() -> void:
	var driver = EnemyDriverScript.new()
	var rack := StubRack.new()
	rack.def = _pulse_def()
	t.check(is_equal_approx(driver.special_fire_range(rack), EnemyDriverScript.TORNADO_FIRE_RANGE),
		"ai gate: pulse waits for point-blank range")
	driver.free()
