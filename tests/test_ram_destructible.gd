extends RefCounted
## Integration: driving into a destructible block damages it (speed-scaled ram),
## while a slow nudge stays under ram_min_speed and leaves it untouched. Pumps
## real physics frames like test_corner_escape (the runner awaits test methods).

const VehicleScene := preload("res://vehicles/vehicle.tscn")
const BlockScene := preload("res://environment/destructible_block.tscn")

const IMPACT_FRAMES := 30

var t

func _init(runner) -> void:
	t = runner

func _fixture(speed: float, block_x: float) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # player faction loads default stats in _ready
	car.velocity = Vector2(speed, 0)
	var block = BlockScene.instantiate()
	block.position = Vector2(block_x, 0)
	container.add_child(block)
	return {"container": container, "car": car, "block": block}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_fast_ram_damages_block() -> void:
	var f := _fixture(600.0, 150.0)
	var health = f.block.get_node("Health")
	var start: float = health.hp
	for i in IMPACT_FRAMES:
		await t.physics_frame
	t.check(health.hp < start, "fast impact chips the block (hp %.1f -> %.1f)" % [start, health.hp])
	t.check(health.hp > 0.0, "single ram doesn't obliterate a fresh block")
	_done(f)

func test_slow_nudge_is_free() -> void:
	var f := _fixture(150.0, 90.0)
	var health = f.block.get_node("Health")
	var start: float = health.hp
	for i in IMPACT_FRAMES:
		await t.physics_frame
	t.check_approx(health.hp, start, "sub-threshold contact deals no damage")
	_done(f)
