extends RefCounted
## Deep water hazard: grounded cars sink and die (invulnerability ignored —
## the sea doesn't care), airborne cars sail over, and a ledge-hopped car
## survives exactly until touchdown. Mirrors test_pit_zone.

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const WaterScene := preload("res://environment/deep_water_zone.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var water = WaterScene.instantiate()
	water.size = Vector2(400, 400)
	container.add_child(water)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0) = mid-water
	return {"container": container, "car": car}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_grounded_car_sinks_and_dies() -> void:
	var f := _fixture()
	f.car.get_node("Health").invulnerable = true  # the sea doesn't care
	for i in 80:  # 0.8s sink tween + margin
		await t.physics_frame
	t.check(f.car.get_node("Health").hp <= 0.0, "water: grounded car sinks and dies")
	_done(f)

func test_airborne_car_sails_over() -> void:
	var f := _fixture()
	f.car.height = 500.0  # mid ramp-jump
	for i in 20:  # airborne this whole window
		await t.physics_frame
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "water: airborne car passes over untouched")
	_done(f)

func test_ledge_hop_survives_until_touchdown() -> void:
	var f := _fixture()
	f.car.pop_airborne(240.0)  # a one-floor ledge hop's arc (~0.37s)
	for i in 10:
		await t.physics_frame
	t.check(f.car.get_node("Health").hp > 0.0, "water: mid-hop over water is safe")
	for i in 90:  # land + sink tween
		await t.physics_frame
	t.check(f.car.get_node("Health").hp <= 0.0, "water: touchdown in the drink sinks")
	_done(f)
