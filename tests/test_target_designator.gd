extends RefCounted
## Durable per-vehicle designation: stable nearest for ordinary drivers and the
## existing committed target for AI, with immediate invalid-target replacement.

const DesignatorScript := preload("res://game/target_designator.gd")
const DriverScript := preload("res://vehicles/drivers/driver.gd")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

class FakeCar extends Node2D:
	var hp := 100.0
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

func _rig() -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var owner := FakeCar.new()
	owner.name = "Owner"
	owner.add_to_group(&"vehicles")
	container.add_child(owner)
	var driver = DriverScript.new()
	driver.name = "Driver"
	owner.add_child(driver)
	var designator = DesignatorScript.new()
	designator.name = "TargetDesignator"
	owner.add_child(designator)
	return [container, owner, designator]

func _opponent(container: Node, pos: Vector2, hp := 100.0) -> FakeCar:
	var car := FakeCar.new()
	car.position = pos
	car.hp = hp
	car.add_to_group(&"vehicles")
	container.add_child(car)
	return car

func _free_rig(container: Node) -> void:
	t.root.remove_child(container)
	container.free()

func test_base_vehicle_owns_designator() -> void:
	var car = VehicleScene.instantiate()
	var designator := car.get_node_or_null(^"TargetDesignator")
	t.check(designator != null and designator.get_script() == DesignatorScript,
		"designation: every base vehicle owns the component")
	car.free()

func test_empty_roster_has_no_designation() -> void:
	var rig := _rig()
	t.check(rig[2].get_target() == null, "designation: empty opponent roster returns null")
	_free_rig(rig[0])

func test_initial_target_is_nearest_live_opponent() -> void:
	var rig := _rig()
	var near := _opponent(rig[0], Vector2(220, 0))
	var _far := _opponent(rig[0], Vector2(600, 0))
	var _dead := _opponent(rig[0], Vector2(40, 0), 0.0)
	t.check(rig[2].get_target() == near,
		"designation: initial choice is nearest living opponent")
	_free_rig(rig[0])

func test_near_tie_holds_and_meaningful_lead_switches() -> void:
	var rig := _rig()
	var first := _opponent(rig[0], Vector2(500, 0))
	var challenger := _opponent(rig[0], Vector2(700, 0))
	t.check(rig[2].get_target() == first, "designation: first nearest is adopted")
	challenger.position = Vector2(450, 0)
	t.check(rig[2].get_target() == first,
		"designation: lead inside distance margin does not chatter")
	challenger.position = Vector2(300, 0)
	t.check(rig[2].get_target() == challenger,
		"designation: meaningfully closer challenger takes ownership")
	_free_rig(rig[0])

func test_dead_target_is_replaced_immediately() -> void:
	var rig := _rig()
	var first := _opponent(rig[0], Vector2(100, 0))
	var live := _opponent(rig[0], Vector2(800, 0))
	t.check(rig[2].get_target() == first, "designation death: nearest is adopted")
	first.hp = 0.0
	t.check(rig[2].get_target() == live,
		"designation death: dead target bypasses switch margin")
	_free_rig(rig[0])

func test_freed_target_is_replaced_immediately() -> void:
	var rig := _rig()
	var first := _opponent(rig[0], Vector2(100, 0))
	var live := _opponent(rig[0], Vector2(800, 0))
	t.check(rig[2].get_target() == first, "designation free: nearest is adopted")
	rig[0].remove_child(first)
	first.free()
	t.check(rig[2].get_target() == live,
		"designation free: freed target is replaced on the next read")
	_free_rig(rig[0])

func test_enemy_driver_preference_overrides_nearest() -> void:
	var rig := _rig()
	var old_driver: Node = rig[1].get_node(^"Driver")
	rig[1].remove_child(old_driver)
	old_driver.free()
	var enemy = EnemyDriverScript.new()
	enemy.name = "Driver"
	rig[1].add_child(enemy)
	var _near := _opponent(rig[0], Vector2(100, 0))
	var committed := _opponent(rig[0], Vector2(700, 0))
	enemy._adopt_target(committed)
	t.check(enemy.get_target_preference(rig[1]) == committed,
		"designation AI: base driver seam exposes committed target")
	t.check(rig[2].get_target() == committed,
		"designation AI: committed driver target overrides nearest")
	committed.hp = 0.0
	t.check(rig[2].get_target() == _near,
		"designation AI: invalid preference falls back to nearest live opponent")
	_free_rig(rig[0])
