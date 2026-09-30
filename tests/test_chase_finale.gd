extends RefCounted
## The bridge is out: the finale that plays when Route 666's clock runs out.
## The scripted drivers (the locked-in player, the birds that brake at the
## bank and the two that try the jump), the numbers that make the jump a
## sure thing for the car and a sure miss for the bikes, and the booted show
## itself — splice, halt, hand-off, splashes, card.

const BirdScript := preload("res://levels/chase/finale_bird_driver.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

var t

class FakeController:
	var max_speed := 500.0

class FakeVehicle extends Node2D:
	var heading := -PI / 2.0
	var velocity := Vector2.ZERO
	var height := 0.0
	var ctrl = FakeController.new()
	func get_controller():
		return ctrl

## A dead-straight course down x = 0.
class FakeCourse:
	func sample(_d: float) -> Dictionary:
		return {"x": 0.0, "half_w": 360.0}

func _init(runner) -> void:
	t = runner

func _rig() -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	container.add_child(vehicle)
	var player := FakeVehicle.new()
	player.add_to_group(&"player")
	container.add_child(player)
	var driver = BirdScript.new()
	container.add_child(driver)
	return [container, vehicle, driver, player]

func _done(container: Node) -> void:
	t.root.remove_child(container)
	container.free()

## A braker pulls over and brakes to a real stop short of the bank.
func test_bird_brakes_at_the_bank() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var driver = r[2]
	var bank_y := -3000.0
	driver.setup(FakeCourse.new(), bank_y, bank_y, &"brake", 1.0)
	vehicle.global_position = Vector2(0, -1500)   # far short: still driving
	vehicle.velocity = Vector2(0, -400)
	var far: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(far["throttle"] >= 0.0, "brake: well short of the bank it keeps rolling")
	t.check(far["steer"] > 0.0, "brake: and pulls over to its shoulder")
	vehicle.global_position = Vector2(0, bank_y + BirdScript.STOP_AHEAD + 120.0)
	var near: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(near["throttle"] < 0.0, "brake: inside the brake zone it goes to the brakes")
	vehicle.velocity = Vector2(0, -6.0)
	var stopped: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_zero_approx(stopped["throttle"]), "brake: at a crawl the pedal comes off — never reverse gear")
	t.check(not stopped["fire_mg"] and not stopped["fire_selected"], "brake: nobody fires in the show")
	t.check(not driver.is_forcing(), "brake: a braker never forces its velocity")
	_done(r[0])

## A jumper follows the car up the deck without passing it, then forces the
## set speed on the deck and holds it in the air — the arc is the numbers',
## not the bike's.
func test_bird_jumps_short() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var driver = r[2]
	var player: FakeVehicle = r[3]
	var deck_y := -3000.0
	driver.setup(FakeCourse.new(), deck_y + 400.0, deck_y, &"jump")
	player.global_position = Vector2(0, -2000)
	player.velocity = Vector2(0, -700)
	vehicle.global_position = Vector2(40, -1000)
	vehicle.velocity = Vector2(0, -300)
	var chasing: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(chasing["throttle"] > 0.0, "jump: behind its mark it chases")
	t.check(chasing["steer"] < 0.0, "jump: toward the deck's centre")
	vehicle.global_position = Vector2(0, player.global_position.y + BirdScript.TRAIL_DY - 100.0)
	vehicle.velocity = Vector2(0, -760)
	var close: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(close["throttle"] < 0.0, "jump: on the car's tail it lifts — it never passes")
	t.check(not driver.is_forcing(), "jump: not forcing yet")
	vehicle.global_position = Vector2(30, deck_y - 10.0)
	driver.get_intent(vehicle, 0.016)
	t.check(driver.is_forcing(), "jump: on the deck it takes the wheel outright")
	t.check(is_equal_approx(vehicle.velocity.y, -BirdScript.BIKE_JUMP_SPEED) and vehicle.velocity.x < 0.0,
		"jump: a set speed north, easing to the centre (%s)" % str(vehicle.velocity))
	vehicle.height = 40.0   # launched
	driver.get_intent(vehicle, 0.016)
	t.check(vehicle.velocity.is_equal_approx(Vector2(0, -BirdScript.BIKE_JUMP_SPEED)),
		"jump: in the air the velocity is held exactly — no drag, no steering")
	t.check(is_equal_approx(vehicle.heading, -PI / 2.0), "jump: nose north")
	_done(r[0])

## The numbers: the bike's forced launch falls short of the far bank with
## room to spare, from anywhere on the lip.
func test_bike_launch_falls_short() -> void:
	var stock = load("res://levels/chase/buzzard.tscn").instantiate()
	var g: float = stock.gravity_z
	var vz: float = stock.jump_launch
	stock.free()
	var air := 2.0 * vz / g
	var flight: float = BirdScript.BIKE_JUMP_SPEED * air
	var r: Dictionary = ChunkDefs.DEFS[&"bridge_out"]["river"]
	var kill_from: float = float(r["brink"]) + 24.0
	var kill_to: float = float(r["deep_to"]) - 24.0
	var earliest: float = float(r["pad_d"]) - 112.0 - 20.0   # entering the pad's rect, nose first
	var latest: float = float(r["pad_d"]) + 112.0
	t.check(earliest + flight > kill_from + 60.0 and latest + flight < kill_to - 60.0,
		"numbers: a bike off the lip lands in the channel from anywhere on it (%d..%d inside %d..%d)"
		% [int(earliest + flight), int(latest + flight), int(kill_from), int(kill_to)])
	t.check(700.0 * air + earliest < kill_to, "numbers: even an unforced sedan-sprint launch off the lip's entry falls short")
