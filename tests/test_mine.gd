extends RefCounted
## Mines: arm delay, land-mine damage + course deviation, jump-mine airborne
## pop with a hard re-vector and zero damage. Pumps real physics frames.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const LandScene := preload("res://environment/mine_land.tscn")
const JumpScene := preload("res://environment/mine_jump.tscn")

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
