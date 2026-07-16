extends RefCounted
## Unified non-MG weapon lockout wiring: firing any non-MG weapon holds the whole
## bay for Vehicle.WEAPON_LOCK seconds. Players and AI share the clock; bosses
## (fixed_loadout) and weapon_lock_exempt cars (the Route 666 chase) opt out.
## The 2s TIMING itself is locked in test_specials_data (sustained cooldown);
## here we pin the vehicle-level constants and the mount-neutralization wiring
## that make WEAPON_LOCK the sole non-MG cadence for ordinary cars.

const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_constants_and_defaults() -> void:
	t.check(is_equal_approx(Vehicle.WEAPON_LOCK, 2.0), "lock: WEAPON_LOCK is the 2s bay clock")
	var car = VehicleScene.instantiate()
	t.root.add_child(car)
	t.check(not car.weapon_lock_exempt, "lock: ordinary car is not exempt by default")
	t.root.remove_child(car)
	car.free()

## Ordinary cars (player AND AI) let the vehicle lock be the sole non-MG cadence,
## so the secondary mount never self-gates; bosses keep their own rate.
func test_secondary_mount_neutralized_for_ordinary_cars() -> void:
	var player = VehicleScene.instantiate()
	player.faction = &"player"
	t.root.add_child(player)
	var p_mount := player.get_node(^"SecondaryMount") as WeaponMount
	t.check(is_equal_approx(p_mount.cooldown_scale, 0.0),
		"lock: player secondary mount does not self-gate")
	t.root.remove_child(player)
	player.free()

	var boss = VehicleScene.instantiate()
	boss.faction = &"enemies"
	boss.fixed_loadout = true
	t.root.add_child(boss)
	var b_mount := boss.get_node(^"SecondaryMount") as WeaponMount
	t.check(b_mount.cooldown_scale > 0.0,
		"lock: boss keeps its own secondary cadence (not neutralized)")
	t.root.remove_child(boss)
	boss.free()
