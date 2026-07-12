extends RefCounted
## Chill Out, Man's disarm status: fire intent stripped (MG and secondary)
## while driving stays live, expiry restores the triggers, fixed_loadout
## bosses refuse the status entirely, burn_taken scales burn DoT per car,
## and the glitter impact style exists on both ends. Driven by run_tests.gd.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const SpecScript := preload("res://resources/status_effect.gd")
const ProjectileScript := preload("res://weapons/projectile.gd")
const ImpactScript := preload("res://weapons/impact_fx.gd")

var t

func _init(runner) -> void:
	t = runner

class FireDriver:
	extends Driver
	func get_intent(_vehicle, _delta: float) -> Dictionary:
		return {"throttle": 0.0, "steer": 0.0, "fire_mg": true, "fire_selected": false,
			"weapon_prev": false, "weapon_next": false, "handbrake": false}

func _spec(kind: StringName, duration: float, magnitude := 1.0) -> StatusEffectSpec:
	var s: StatusEffectSpec = SpecScript.new()
	s.kind = kind
	s.duration = duration
	s.magnitude = magnitude
	return s

## Stats are authored BEFORE add_child (the level_loader pattern) — the bare
## scene ships stats = null, and a mid-test crash would strand cars in the
## tree for every later suite to count.
func _car(burn_mult := 1.0) -> Node:
	var car = VehicleScene.instantiate()
	car.faction = &"enemies"  # never shadow player-group lookups in fixtures
	var stats: VehicleStats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
	stats.burn_taken = burn_mult
	car.stats = stats
	t.root.add_child(car)
	return car

func _done(car: Node) -> void:
	t.root.remove_child(car)
	car.free()

## Live MG rounds spawn into current_scene and would fly through later
## suites' fixtures once those pump frames — sweep every shot before leaving.
func _sweep_projectiles() -> void:
	for host in [t.root.get_tree().current_scene, t.root]:
		if host == null:
			continue
		for child in host.get_children():
			if child is ProjectileScript:
				child.free()

func test_disarm_gates_mg_and_expires() -> void:
	var car = _car()
	var driver := FireDriver.new()
	car.set_driver(driver)  # set_driver parents it — pre-adding double-parents
	var mg = car.get_node("MachineGunMount")
	car.apply_effect(_spec(&"disarm", 1.0))
	t.check(car.is_disarmed(), "disarm: status lands on a regular car")
	for i in 10:
		car._physics_process(1.0 / 60.0)
	t.check(mg.heat == 0.0, "disarm: MG never fires while chilled (heat %s)" % mg.heat)
	var status = car.get_node("Status")
	status.tick(2.0)  # burn the remaining duration
	t.check(not car.is_disarmed(), "disarm: expires on schedule")
	for i in 10:
		car._physics_process(1.0 / 60.0)
	t.check(mg.heat > 0.0, "disarm: triggers come back after expiry")
	_sweep_projectiles()
	_done(car)

func test_disarm_strips_only_fire_intent() -> void:
	var car = _car()
	car.apply_effect(_spec(&"disarm", 5.0))
	car.velocity = Vector2(300, 0)
	car._physics_process(1.0 / 60.0)
	t.check(car.velocity.length() > 0.0, "disarm: physics still carries the car")
	t.check(not car.get_node("Status").is_stunned(), "disarm: is not a stun")
	_done(car)

func test_bosses_refuse_disarm() -> void:
	var car = _car()
	car.fixed_loadout = true
	car.apply_effect(_spec(&"disarm", 5.0))
	t.check(not car.is_disarmed(), "disarm: fixed_loadout rigs keep their trigger fingers")
	car.apply_effect(_spec(&"burn", 1.0, 4.0))
	t.check(car.is_burning(), "disarm immunity never blocks other statuses")
	_done(car)

func test_burn_taken_scales_dot() -> void:
	var stock = _car()
	var fragile = _car(1.5)
	stock.apply_effect(_spec(&"burn", 10.0, 10.0))
	fragile.apply_effect(_spec(&"burn", 10.0, 10.0))
	var stock_hp: float = stock.get_node("Health").hp
	var fragile_hp: float = fragile.get_node("Health").hp
	stock.get_node("Status").tick(1.0)
	fragile.get_node("Status").tick(1.0)
	var stock_loss: float = stock_hp - stock.get_node("Health").hp
	var fragile_loss: float = fragile_hp - fragile.get_node("Health").hp
	t.check(is_equal_approx(stock_loss, 10.0), "burn_taken: stock car takes authored dps")
	t.check(is_equal_approx(fragile_loss, 15.0), "burn_taken: 1.5x car burns half again as hard")
	_done(stock)
	_done(fragile)

func test_glitter_style_exists_both_ends() -> void:
	t.check(int(ProjectileScript.ImpactStyle.GLITTER) == ImpactScript.GLITTER,
		"glitter: projectile enum and impact renderer agree")
