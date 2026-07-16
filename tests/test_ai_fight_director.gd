extends RefCounted
## Scene-local spotlight coordinator: field-size slots, lease rotation, death
## replacement, boss exclusion, and fair distribution across human players.

const DirectorScript := preload("res://ai/fight_director.gd")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

var t

class FakeCar extends Node2D:
	var hp := 100.0
	var fixed_loadout := false
	var driver: Node = null
	func get_hp() -> float:
		return hp
	func get_driver() -> Node:
		return driver

func _init(runner) -> void:
	t = runner

func _rig(enemy_count: int, player_count := 1) -> Dictionary:
	var arena := Node2D.new()
	t.root.add_child(arena)
	var players: Array[Node2D] = []
	for i in player_count:
		var player := FakeCar.new()
		player.position = Vector2(i * 2000.0, 0)
		player.add_to_group(&"vehicles")
		player.add_to_group(&"player")
		arena.add_child(player)
		players.append(player)
	var enemies: Array[Node2D] = []
	for i in enemy_count:
		var car := FakeCar.new()
		car.position = Vector2(100.0 + i * 150.0, 0)
		car.add_to_group(&"vehicles")
		var driver = EnemyDriverScript.new()
		car.driver = driver
		car.add_child(driver)
		arena.add_child(car)
		enemies.append(car)
	var director = DirectorScript.new()
	director.setup(arena)
	arena.add_child(director)
	return {"arena": arena, "players": players, "enemies": enemies, "director": director}

func _done(rig: Dictionary) -> void:
	t.root.remove_child(rig.arena)
	rig.arena.free()

func _holders(rig: Dictionary) -> Array:
	return rig.enemies.filter(func(car: Node2D): return car.driver.get_focus_target() != null)

func test_small_and_large_fields_get_one_then_two_slots() -> void:
	var small := _rig(4)
	t.check(small.director.focus_count() == 1, "focus: four rivals reserve one player slot")
	_done(small)
	var large := _rig(5)
	t.check(large.director.focus_count() == 2, "focus: five rivals reserve two player slots")
	_done(large)

func test_expired_lease_rotates_to_an_idle_rival() -> void:
	var rig := _rig(3)
	var first: Node = _holders(rig)[0]
	rig.director._clock = DirectorScript.FOCUS_LEASE_TIME + 0.1
	rig.director.refresh_now()
	var second: Node = _holders(rig)[0]
	t.check(second != first, "focus: expired spotlight rotates to a rival who has waited")
	_done(rig)

func test_dead_holder_is_replaced_immediately() -> void:
	var rig := _rig(3)
	var first: Node = _holders(rig)[0]
	first.hp = 0.0
	rig.director.refresh_now()
	t.check(rig.director.focus_count() == 1 and _holders(rig)[0] != first,
		"focus: a dead holder hands off without waiting for lease expiry")
	_done(rig)

func test_relentless_and_fixed_loadout_cars_are_excluded() -> void:
	var rig := _rig(3)
	rig.enemies[0].driver.relentless = true
	rig.enemies[1].fixed_loadout = true
	rig.director.refresh_now()
	t.check(rig.director.focus_count() == 1, "focus: one ordinary rival still takes the card")
	t.check(rig.enemies[0].driver.get_focus_target() == null,
		"focus: relentless Lackey-style driver is protected")
	t.check(rig.enemies[1].driver.get_focus_target() == null,
		"focus: fixed-loadout boss is protected")
	_done(rig)

func test_two_slots_cover_two_humans() -> void:
	var rig := _rig(5, 2)
	var targets: Array = _holders(rig).map(func(car: Node2D): return car.driver.get_focus_target())
	t.check(targets.size() == 2 and targets[0] != targets[1],
		"focus: two slots cover separate humans before doubling up")
	_done(rig)
