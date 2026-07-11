extends RefCounted
## Rear Missile is the Fire Missile's blue, tail-launched twin: combat numbers
## stay identical while the vehicle hands the mount the opposite bumper/bearing.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const FireDef := preload("res://data/weapons/missile_standard.tres")
const RearDef := preload("res://data/weapons/missile_rear.tres")

var t

func _init(runner) -> void:
	t = runner

func test_stats_match_fire_missile() -> void:
	for prop in ["cooldown", "damage", "projectile_speed", "projectile_lifetime",
			"turn_rate_deg", "acquisition_radius"]:
		t.check(is_equal_approx(float(RearDef.get(prop)), float(FireDef.get(prop))),
			"rear: %s matches fire missile" % prop)
	t.check(RearDef.projectile_scene == FireDef.projectile_scene,
		"rear: projectile scene matches fire missile")
	t.check(RearDef.launch_side == WeaponDef.LaunchSide.REAR,
		"rear: launch side is authored rear")

func test_vehicle_uses_tail_and_opposite_bearing() -> void:
	var car = VehicleScene.instantiate()
	t.root.add_child(car)
	car.heading = PI * 0.5
	await t.physics_frame  # vehicle rotates its Visual/markers on the physics tail
	var front: Dictionary = car.secondary_launch(FireDef)
	var rear: Dictionary = car.secondary_launch(RearDef)
	var expected := Vector2.DOWN
	t.check((front.direction as Vector2).is_equal_approx(expected),
		"rear: front missile follows the nose")
	t.check((rear.direction as Vector2).is_equal_approx(-expected),
		"rear: missile bearing opposes the nose")
	var along: float = ((rear.origin as Vector2) - car.global_position).dot(expected)
	t.check(along < 0.0, "rear: origin sits behind car center")
	t.root.remove_child(car)
	car.free()
