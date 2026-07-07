extends RefCounted
## Pit hazard: grounded cars fall in (shrink, then die — shields don't help);
## airborne cars sail straight over. Pumps real physics frames (the runner
## awaits test methods).

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const PitScene := preload("res://environment/pit_zone.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var pit = PitScene.instantiate()
	pit.size = Vector2(400, 400)
	container.add_child(pit)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0) = pit center
	return {"container": container, "car": car}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_grounded_car_falls_and_dies() -> void:
	var f := _fixture()
	f.car.get_node("Health").invulnerable = true  # cliffs don't care
	for i in 70:  # 0.7s shrink + margin
		await t.physics_frame
	t.check(f.car.get_node("Health").hp <= 0.0, "pit: grounded car dies, invulnerability ignored")
	_done(f)

func test_airborne_car_sails_over() -> void:
	var f := _fixture()
	f.car.height = 500.0  # mid ramp-jump
	for i in 20:  # still airborne this whole window
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "pit: airborne car passes over untouched")
	_done(f)
