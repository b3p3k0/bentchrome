extends RefCounted
## Mines: arm delay, land-mine damage + course deviation, jump-mine airborne
## pop with a hard re-vector and zero damage. Pumps real physics frames.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const LandScene := preload("res://environment/mine_land.tscn")
const JumpScene := preload("res://environment/mine_jump.tscn")
const StubDriver := preload("res://tests/stub_driver.gd")
const STANDARD_DEF := preload("res://data/weapons/missile_standard.tres")

const ARM_FRAMES := 70  # past the 1s arm delay

var t

func _init(runner) -> void:
	t = runner

func _fixture(mine_scene: PackedScene) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var mine = mine_scene.instantiate()
	mine.damage = 22.0
	container.add_child(mine)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # parked right on it
	return {"container": container, "car": car, "mine": mine}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_land_mine_damages_and_deviates() -> void:
	var f := _fixture(LandScene)
	var heading_before: float = f.car.heading
	for i in ARM_FRAMES:
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check(health.hp < health.max_hp, "land mine: damage landed (hp %.0f)" % health.hp)
	t.check(absf(f.car.heading - heading_before) > deg_to_rad(4.0), "land mine: course deviated")
	t.check(not is_instance_valid(f.mine), "land mine: single use")
	_done(f)

func test_jump_mine_pops_airborne_no_damage() -> void:
	var f := _fixture(JumpScene)
	for i in ARM_FRAMES:
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "jump mine: no damage")
	t.check(f.car.height > 0.0 or f.car.vz > 0.0, "jump mine: victim popped airborne")
	_done(f)

## Launch-immune rigs (Goliath) crush mines: a jump mine is consumed for no
## pop and no spin; a land mine still bills its damage but can't deviate.
func test_launch_immune_rig_crushes_mines() -> void:
	var f := _fixture(JumpScene)
	f.car.launch_immune = true
	var heading_before: float = f.car.heading
	for i in ARM_FRAMES:
		await t.physics_frame
	t.check(not is_instance_valid(f.mine), "immune rig: jump mine consumed")
	t.check(f.car.height == 0.0 and f.car.vz == 0.0, "immune rig: no airborne pop")
	t.check(is_equal_approx(f.car.heading, heading_before), "immune rig: no re-vector")
	_done(f)

	var g := _fixture(LandScene)
	g.car.launch_immune = true
	g.car.mine_weakness = 3.0  # the soft underbelly: land mines bite deep
	var heading_land: float = g.car.heading
	for i in ARM_FRAMES:
		await t.physics_frame
	var health = g.car.get_node("Health")
	t.check(is_equal_approx(health.max_hp - health.hp, 22.0 * 3.0),
		"immune rig: the soft belly takes the scaled bill (%.0f)" % (health.max_hp - health.hp))
	t.check(is_equal_approx(g.car.heading, heading_land), "immune rig: land mine can't spin it")
	_done(g)

## Regression: dropping the LAST mine auto-cycles the rack; the still-held
## click must NOT fire the newly selected slot (release re-arms the trigger).
func test_dry_slot_does_not_chain_fire_next_weapon() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container  # mine drops + missiles spawn here
	var car = VehicleScene.instantiate()
	var old_driver = car.get_node("Driver")
	car.remove_child(old_driver)
	old_driver.free()
	var stub = StubDriver.new()
	stub.name = "Driver"
	car.add_child(stub)
	container.add_child(car)

	var rack = car.get_node("WeaponRack")
	rack.configure(STANDARD_DEF, 3, 0.0)  # guaranteed PROJECTILE "special"
	rack.add_ammo(WeaponRack.Slot.MINE, 1)
	while rack.selected_index() != WeaponRack.Slot.MINE:
		rack.select_next()
	var special_before: int = rack.ammo(WeaponRack.Slot.SPECIAL)
	stub.intent = {}  # one un-pressed frame clears the configure/select lock
	await t.physics_frame

	stub.intent = {"fire_selected": true}
	for i in 5:
		await t.physics_frame
	var mines := 0
	for c in container.get_children():
		if "dropper" in c:
			mines += 1
	t.check(mines == 1, "held fire: exactly one mine dropped")
	t.check(rack.selected_index() != WeaponRack.Slot.MINE, "dry mine slot auto-cycled")
	t.check(rack.ammo(WeaponRack.Slot.SPECIAL) == special_before,
		"fire lock: held click did NOT fire the next slot")

	stub.intent = {}  # release...
	await t.physics_frame
	stub.intent = {"fire_selected": true}  # ...and a fresh press fires it
	for i in 3:
		await t.physics_frame
	t.check(rack.ammo(WeaponRack.Slot.SPECIAL) == special_before - 1,
		"fresh press fires the newly selected slot")

	stub.intent = {}
	t.current_scene = null
	t.root.remove_child(container)
	container.free()
