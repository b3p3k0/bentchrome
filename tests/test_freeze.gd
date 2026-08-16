extends RefCounted
## Chilblain's freeze status: all intent stripped (pedals AND triggers) while
## momentum damps to a dead stop, expiry restores control, fixed_loadout
## bosses refuse the ice entirely, Coldfront's roster contract holds, and the
## ICE impact style exists on both ends. Driven by run_tests.gd.

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
		return {"throttle": 1.0, "steer": 0.0, "fire_mg": true, "fire_selected": false,
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
func _car() -> Node:
	var car = VehicleScene.instantiate()
	car.faction = &"enemies"  # never shadow player-group lookups in fixtures
	car.stats = (load("res://data/vehicles/ghost.tres") as VehicleStats).duplicate()
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

func test_freeze_strips_intent_and_damps_velocity() -> void:
	var car = _car()
	var driver := FireDriver.new()
	car.set_driver(driver)  # set_driver parents it — pre-adding double-parents
	var mg = car.get_node("MachineGunMount")
	car.apply_effect(_spec(&"freeze", 5.0))
	t.check(car.is_frozen(), "freeze: status lands on a regular car")
	car.velocity = Vector2(400, 0)
	car._physics_process(1.0 / 60.0)
	var after_one: float = car.velocity.length()
	t.check(after_one < 400.0, "freeze: velocity damps, not holds (%s)" % after_one)
	t.check(after_one > 0.0, "freeze: slide-to-stop, never an instant pin")
	for i in 60:
		car._physics_process(1.0 / 60.0)
	t.check(car.velocity.length() < 1.0,
		"freeze: skates to a dead stop inside a second (%s)" % car.velocity.length())
	t.check(mg.heat == 0.0, "freeze: MG never fires while iced (heat %s)" % mg.heat)
	_sweep_projectiles()
	_done(car)

func test_freeze_expires_and_control_returns() -> void:
	var car = _car()
	var driver := FireDriver.new()
	car.set_driver(driver)
	var mg = car.get_node("MachineGunMount")
	car.apply_effect(_spec(&"freeze", 1.0))
	car.get_node("Status").tick(2.0)  # burn the remaining duration
	t.check(not car.is_frozen(), "freeze: thaws on schedule")
	for i in 10:
		car._physics_process(1.0 / 60.0)
	t.check(mg.heat > 0.0, "freeze: triggers come back after the thaw")
	t.check(car.velocity.length() > 0.0, "freeze: pedals come back after the thaw")
	_sweep_projectiles()
	_done(car)

func test_bosses_refuse_freeze() -> void:
	var car = _car()
	car.fixed_loadout = true
	car.apply_effect(_spec(&"freeze", 5.0))
	t.check(not car.is_frozen(), "freeze: fixed_loadout rigs never sit in an ice block")
	car.apply_effect(_spec(&"burn", 1.0, 4.0))
	t.check(car.is_burning(), "freeze immunity never blocks other statuses")
	_done(car)

func test_coldfront_contract() -> void:
	var stats := load("res://data/vehicles/coldfront.tres") as VehicleStats
	t.check(stats != null and stats.id == &"coldfront", "coldfront: .tres imported")
	var def: WeaponDef = stats.special
	t.check(def != null and def.display_name == "Chilblain", "coldfront: Chilblain bound")
	t.check(def.turn_rate_deg > 0.0 and def.acquisition_radius > 0.0,
		"chilblain: tracks like a missile")
	var found := false
	for fx in def.on_hit_effects:
		if fx.kind == &"freeze":
			found = true
			t.check(is_equal_approx(fx.duration, 3.0), "chilblain: 3s in the ice")
			t.check(fx.refresh == false, "chilblain: re-hits while frozen never extend")
	t.check(found, "chilblain: carries the freeze status")
	t.check(is_equal_approx(stats.terrain_factor(&"snow", &"grip"), 2.2222222222),
		"coldfront: snow grip factored back to asphalt")
	t.check(is_equal_approx(stats.terrain_factor(&"ice", &"grip"), 12.5),
		"coldfront: ice grip factored back to asphalt")

## The anti-chaining rule, end to end with the REAL authored effect: a second
## Chilblain hit mid-freeze changes nothing, but a hit after the thaw lands.
func test_freeze_reapply_ignored_while_active() -> void:
	var car = _car()
	var def := (load("res://data/vehicles/coldfront.tres") as VehicleStats).special
	var fx: StatusEffectSpec = def.on_hit_effects[0]
	var status = car.get_node("Status")
	car.apply_effect(fx)
	status.tick(2.9)  # almost thawed...
	car.apply_effect(fx)  # ...re-hit is IGNORED, no fresh 3s
	status.tick(0.2)
	t.check(not car.is_frozen(), "freeze: mid-effect re-hit never extends the ice")
	car.apply_effect(fx)
	t.check(car.is_frozen(), "freeze: a hit after the thaw lands normally")
	_done(car)

func test_ice_style_exists_both_ends() -> void:
	t.check(int(ProjectileScript.ImpactStyle.ICE) == ImpactScript.ICE,
		"ice: projectile enum and impact renderer agree")
