extends RefCounted
## Tornado Alley (the TORNADO Kind): activation spins for active_duration, the
## circular AoE cooks same-floor Health and spin-outs each caught car exactly
## once (deviation + shove, launch_immune rigs exempt), steer authority drops
## to TORNADO_STEER while spinning, the exit heading is randomized, and the AI
## holds the special until point-blank. Driven by run_tests.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

var t

func _init(runner) -> void:
	t = runner

class SteerDriver:
	extends Driver
	func get_intent(_vehicle, _delta: float) -> Dictionary:
		return {"throttle": 1.0, "steer": 1.0, "fire_mg": false, "fire_selected": false,
			"weapon_prev": false, "weapon_next": false, "handbrake": false}

class StubRack:
	extends RefCounted
	var def: WeaponDef
	func selected_def() -> WeaponDef:
		return def

func _tornado_def() -> WeaponDef:
	var def := WeaponDef.new()
	def.display_name = "Tornado Alley"
	def.kind = WeaponDef.Kind.TORNADO
	def.damage = 20.0  # dps
	def.active_duration = 3.0
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

## One real physics frame registers the bodies with the space (shape queries
## see nothing before that), then processing goes manual so velocities and
## tick counts stay exact — friction never runs behind the assertions.
func _settle(cars: Array) -> void:
	await t.physics_frame
	for car in cars:
		car.set_physics_process(false)
		car.get_node("SpecialController").set_physics_process(false)
		car.velocity = Vector2.ZERO

func _spin_up(car: Node) -> Node:
	var sc = car.get_node("SpecialController")
	sc.set_weapon(_tornado_def())
	t.check(sc.activate(true, car.global_position, Vector2.RIGHT, car), "tornado: activation fires")
	return sc

func test_spin_lifecycle_and_random_exit() -> void:
	var car = _car(Vector2.ZERO)
	var sc = _spin_up(car)
	t.check(sc.is_spinning(), "tornado: spinning after activation")
	var angle_before: float = sc.tornado_visual_angle()
	sc._tornado_tick(0.1)
	t.check(sc.tornado_visual_angle() > angle_before, "tornado: visual whirl accumulates")
	car.heading = 0.0
	for i in 40:  # 4s of ticks > 3s duration
		sc._tornado_tick(0.1)
	t.check(not sc.is_spinning(), "tornado: stops after active_duration")
	t.check(car.heading != 0.0 and car.heading >= 0.0 and car.heading < TAU,
		"tornado: exit heading randomized in range")
	_done(car)

func test_aoe_bills_and_spins_out_once() -> void:
	var caster = _car(Vector2.ZERO)
	var victim = _car(Vector2(40, 0))  # inside 1.5x ghost footprint (~49px)
	await _settle([caster, victim])  # sync the physics space; tests own the ticks
	var sc = _spin_up(caster)
	var hp_before: float = victim.get_node("Health").hp
	sc._tornado_tick(0.5)
	t.check(victim.get_node("Health").hp < hp_before, "tornado: AoE bills Health-bearing cars")
	t.check(victim.velocity.length() > 0.0, "tornado: caught car takes the shove")
	var vel_after_first: Vector2 = victim.velocity
	var hp_mid: float = victim.get_node("Health").hp
	sc._tornado_tick(0.5)
	t.check(victim.velocity == vel_after_first, "tornado: spin-out lands once per activation")
	t.check(victim.get_node("Health").hp < hp_mid, "tornado: damage keeps ticking while inside")
	_done(caster)
	_done(victim)

func test_launch_immune_rig_holds_course() -> void:
	var caster = _car(Vector2.ZERO)
	var rig = _car(Vector2(40, 0))
	rig.launch_immune = true
	await _settle([caster, rig])
	var sc = _spin_up(caster)
	var hp_before: float = rig.get_node("Health").hp
	sc._tornado_tick(0.5)
	t.check(rig.get_node("Health").hp < hp_before, "tornado: immune rig still takes the dps")
	t.check(rig.velocity == Vector2.ZERO, "tornado: immune rig is never deviated or shoved")
	_done(caster)
	_done(rig)

func test_steer_authority_cut_while_spinning() -> void:
	var straight = _car(Vector2(0, 0))
	var spinner = _car(Vector2(4000, 0))
	for car in [straight, spinner]:
		var driver := SteerDriver.new()
		car.add_child(driver)
		car.set_driver(driver)
	var sc = _spin_up(spinner)
	sc._tornado_t = 99.0  # hold the spin for the whole comparison window
	for i in 60:
		straight._physics_process(1.0 / 60.0)
		spinner._physics_process(1.0 / 60.0)
	var full_turn: float = absf(straight.heading)
	var cut_turn: float = absf(spinner.heading)  # real heading, not the visual whirl
	t.check(full_turn > 0.05, "tornado steer: control car actually turned (%.3f rad)" % full_turn)
	t.check(cut_turn < full_turn * 0.5,
		"tornado steer: spinning car turns under half rate (%.3f vs %.3f)" % [cut_turn, full_turn])
	sc._end_tornado(false)
	_done(straight)
	_done(spinner)

func test_ai_holds_tornado_until_point_blank() -> void:
	var driver = EnemyDriverScript.new()
	var rack := StubRack.new()
	rack.def = _tornado_def()
	t.check(is_equal_approx(driver.special_fire_range(rack), EnemyDriverScript.TORNADO_FIRE_RANGE),
		"ai gate: tornado waits for point-blank range")
	rack.def = WeaponDef.new()  # plain PROJECTILE
	t.check(is_equal_approx(driver.special_fire_range(rack), 700.0),
		"ai gate: ordinary specials keep the standard envelope")
	driver.free()
