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

class ProximityCar extends CharacterBody2D:
	var height := 0.0
	var heading := 0.0

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

func _proximity_fixture(mine_scene: PackedScene, separation: float) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var mine = mine_scene.instantiate()
	container.add_child(mine)
	var car := ProximityCar.new()
	car.collision_layer = 1
	car.position = Vector2(separation, 0)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1.0
	col.shape = shape
	car.add_child(col)
	container.add_child(car)
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

## Regression: persistent mines may outlive the car that dropped them. A freed
## dropper still occupies the typed property as an invalid Object reference;
## detonation must fall back to environmental damage instead of aborting after
## each repeated course deviation.
func test_land_mine_detonates_after_dropper_is_freed() -> void:
	var f := _fixture(LandScene)
	var former_dropper := Node2D.new()
	f.container.add_child(former_dropper)
	f.mine.dropper = former_dropper
	former_dropper.free()
	for i in ARM_FRAMES:
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check_approx(health.max_hp - health.hp, 22.0,
		"orphaned mine: damage lands at environmental scale")
	t.check(f.car.last_attacker == null,
		"orphaned mine: freed dropper is not retained for kill credit")
	t.check(not is_instance_valid(f.mine),
		"orphaned mine: detonates and is consumed")
	_done(f)

func test_jump_mine_pops_airborne_no_damage() -> void:
	var f := _fixture(JumpScene)
	for i in ARM_FRAMES:
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "jump mine: no damage")
	t.check(f.car.height > 0.0 or f.car.vz > 0.0, "jump mine: victim popped airborne")
	_done(f)

func test_land_proximity_is_wider_but_jump_stays_tight() -> void:
	var land = LandScene.instantiate()
	var jump = JumpScene.instantiate()
	t.root.add_child(land)
	t.root.add_child(jump)
	var land_shape := land.get_child(0) as CollisionShape2D
	var jump_shape := jump.get_child(0) as CollisionShape2D
	t.check_approx((land_shape.shape as CircleShape2D).radius, 52.0,
		"mine proximity: land fuse reaches 52px")
	t.check_approx((jump_shape.shape as CircleShape2D).radius, 26.0,
		"mine proximity: jump trap keeps its 26px contact range")
	t.check_approx(land.VISIBLE_RADIUS, 14.0,
		"mine proximity: painted mine stays at its 14px silhouette")
	t.root.remove_child(land)
	land.free()
	t.root.remove_child(jump)
	jump.free()

	# A 1px probe car at 48px exercises the added outer band: the 52px land
	# fuse overlaps, while the jump mine's 26px contact surface still misses.
	var near_land := _proximity_fixture(LandScene, 48.0)
	for i in ARM_FRAMES:
		await t.physics_frame
	t.check(not is_instance_valid(near_land.mine),
		"mine proximity: near pass beyond the old surface detonates land mine")
	_done(near_land)

	var near_jump := _proximity_fixture(JumpScene, 48.0)
	for i in ARM_FRAMES:
		await t.physics_frame
	t.check(is_instance_valid(near_jump.mine),
		"mine proximity: same near pass does not trigger the tighter jump mine")
	_done(near_jump)

	var outside := _proximity_fixture(LandScene, 56.0)
	for i in ARM_FRAMES:
		await t.physics_frame
	t.check(is_instance_valid(outside.mine),
		"mine proximity: pass beyond expanded land fuse remains safe")
	_done(outside)

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
