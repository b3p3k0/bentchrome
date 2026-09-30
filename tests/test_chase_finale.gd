extends RefCounted
## The bridge is out: the finale that plays when Route 666's clock runs out.
## The scripted drivers (the locked-in player, the birds that brake at the
## bank and the two that try the jump), the numbers that make the jump a
## sure thing for the car and a sure miss for the bikes, and the booted show
## itself — splice, halt, hand-off, splashes, card.

const BirdScript := preload("res://levels/chase/finale_bird_driver.gd")
const FinaleDriver := preload("res://levels/chase/finale_driver.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

var t

class FakeController:
	var max_speed := 500.0
	var boosting := false

class FakeVehicle extends Node2D:
	var heading := -PI / 2.0
	var velocity := Vector2.ZERO
	var height := 0.0
	var ctrl = FakeController.new()
	var popped_vz := 0.0
	func get_controller():
		return ctrl
	func pop_airborne(vz: float) -> void:
		popped_vz = vz
		height = 1.0

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

## The locked-in player: centres and governs to the launch speed on the
## approach (nitro lit), owns the velocity on the deck, pops exactly once at
## the brink, holds the arc in the air, and keeps driving north after.
func test_finale_driver_locks_in_and_pops() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	container.add_child(vehicle)
	var driver = FinaleDriver.new()
	container.add_child(driver)
	var deck_y := -3000.0
	var brink_y := -3400.0
	driver.setup(FakeCourse.new(), deck_y, brink_y)
	var pops := [0]   # a box: lambdas capture locals by value
	driver.popped.connect(func() -> void: pops[0] += 1)
	vehicle.global_position = Vector2(120, -2000)
	vehicle.velocity = Vector2(0, -500)
	var approach: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(not driver.is_forcing(), "lock-in: on the approach the controller still drives")
	t.check(approach["steer"] < 0.0, "lock-in: it steers for the centreline")
	t.check(approach["throttle"] > 0.0 and approach["boost"], "lock-in: pedal down, nitro lit")
	vehicle.velocity = Vector2(0, -FinaleDriver.LAUNCH_SPEED - 60.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] < 0.0, "lock-in: over the launch speed it eases off — the speed is set")
	t.check(not approach["fire_mg"] and not approach["fire_selected"], "lock-in: no guns in the show")
	vehicle.global_position = Vector2(40, deck_y - 5.0)
	driver.get_intent(vehicle, 0.016)
	t.check(driver.is_forcing() and driver.stage == FinaleDriver.Stage.DECK, "lock-in: on the deck it takes the velocity outright")
	t.check(is_equal_approx(vehicle.velocity.y, -FinaleDriver.LAUNCH_SPEED) and vehicle.velocity.x < 0.0,
		"lock-in: the launch speed north, easing to the centre")
	t.check(vehicle.ctrl.boosting, "lock-in: the flame stays lit while forcing")
	t.check(pops[0] == 0, "lock-in: no pop before the brink")
	vehicle.global_position = Vector2(0, brink_y - 1.0)
	driver.get_intent(vehicle, 0.016)
	t.check(pops[0] == 1 and is_equal_approx(vehicle.popped_vz, FinaleDriver.FINALE_VZ),
		"lock-in: at the brink it pops FINALE_VZ once")
	t.check(driver.stage == FinaleDriver.Stage.AIR and vehicle.velocity.is_equal_approx(Vector2(0, -FinaleDriver.LAUNCH_SPEED)),
		"lock-in: airborne at exactly the launch speed")
	vehicle.global_position = Vector2(30, brink_y - 400.0)
	driver.get_intent(vehicle, 0.016)
	t.check(vehicle.velocity.is_equal_approx(Vector2(0, -FinaleDriver.LAUNCH_SPEED)) and pops[0] == 1,
		"lock-in: in the air the velocity is held exactly — no steering, no second pop")
	vehicle.height = 0.0
	driver.get_intent(vehicle, 0.016)
	t.check(driver.stage == FinaleDriver.Stage.LANDED and driver.is_forcing(), "lock-in: landed, it keeps driving north")
	t.root.remove_child(container)
	container.free()

## The numbers: the forced arc clears the channel with room to spare and
## comes down on the road past the far shallows, whatever the car.
func test_player_jump_clears_the_river() -> void:
	var stock = load("res://levels/chase/chase_player.tscn").instantiate()
	var g: float = stock.gravity_z
	stock.free()
	var air := 2.0 * FinaleDriver.FINALE_VZ / g
	var flight: float = FinaleDriver.LAUNCH_SPEED * air
	var r: Dictionary = ChunkDefs.DEFS[&"bridge_out"]["river"]
	var landing: float = float(r["brink"]) + flight
	var kill_to: float = float(r["deep_to"]) - 24.0
	t.check(landing >= kill_to + 150.0, "numbers: the car lands %dpx past the channel's kill rect" % int(landing - kill_to))
	t.check(landing >= float(r["shallow_to"]), "numbers: and past the far shallows, on the road")
	t.check(landing < float(ChunkDefs.DEFS[&"bridge_out"]["len"]), "numbers: and still inside the river mile")

## The show itself, booted: at 0:00 the run doesn't end — the road is
## rewritten with the river a frame's height ahead, the car is locked in and
## untouchable, the pack is told where the bank is, two bikes are cast to
## jump — then, compressed: the car flies the exact arc, lands on the far
## road unhurt while the scene camera holds, both bikes go into the river for
## free, and the card comes a beat after the last splash.
func test_the_bridge_is_out() -> void:
	const FinaleDirector := preload("res://levels/chase/finale_director.gd")
	const Economy := preload("res://game/economy.gd")
	var gs = t.root.get_node_or_null(^"/root/GameState")
	gs.lives = 3
	gs.devgod = false
	gs.game_mode = &"campaign"
	var scene = load("res://levels/chase/buzzard_run.tscn").instantiate()
	scene.auto_advance = false
	t.root.add_child(scene)
	t.current_scene = scene
	scene.set_process(false)
	for i in 3:
		await t.physics_frame
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	var director = scene.get_node(^"ChaseDirector")
	var streamer = scene.get_node(^"CourseStreamer")
	var pcam: Camera2D = player.get_node(^"Camera2D")
	var d0: float = -player.global_position.y
	Economy.enabled = true
	Economy.funds = 1000
	var beat_was: float = FinaleDirector.FINALE_BEAT
	FinaleDirector.FINALE_BEAT = 0.3
	scene.clock = scene.RUN_SECONDS
	scene._process(0.016)
	t.check(scene.finale_running() and not scene._won, "finale: at 0:00 the show starts instead of the win")
	var fin = scene._finale
	t.check(fin != null and fin.entry["name"] == &"bridge_out", "finale: the river mile is on the plan")
	var cut: int = scene.course.plan.find(fin.entry)
	t.check(float(fin.entry["start_d"]) >= d0 + FinaleDirector.FINALE_LEAD, "finale: spliced past the top of the frame")
	for i in streamer._live:
		t.check(i < cut or i >= cut, "finale: live keys are sane")
	t.check(scene.course.plan.size() == cut + 4, "finale: the river and three straights of run-out end the plan")
	var driver = player.get_driver()
	t.check(driver != null and driver.get_script() == FinaleDirector.FinaleDriver, "finale: the car is locked in")
	t.check(player.get_node(^"Health").god and not scene.catch_enabled, "finale: nothing can hurt or catch it now")
	t.check(is_equal_approx(wall.halt_y, ChunkDefs.river_y(fin.entry, "bank")), "finale: the pack knows where the bank is")
	t.check(director.frozen and not director.kill_hooks, "finale: the director is in show mode")
	t.check(fin.jumpers.size() == FinaleDirector.JUMPERS, "finale: %d bikes are cast to jump" % FinaleDirector.JUMPERS)
	var dare: float = scene.daredevil
	scene._process(0.016)
	t.check(is_equal_approx(scene.daredevil, dare), "finale: the daredevil bonus is frozen at the line")
	# Compress the road: the car a hundred px short of the bank at speed, the
	# jumpers on its tail — and let the show run.
	var bank_y: float = ChunkDefs.river_y(fin.entry, "bank")
	player.global_position = Vector2(scene.course.sample(-bank_y)["x"], bank_y + 100.0)
	player.velocity = Vector2(0, -FinaleDirector.FinaleDriver.LAUNCH_SPEED)
	for j in fin.jumpers:
		j.global_position = player.global_position + Vector2(0, 150.0)
		j.velocity = player.velocity
	wall.front_y = player.global_position.y + 300.0   # on the bumper, as it would be
	var hp_before: float = player.get_hp()
	var flew := false
	var landed := false
	var cam_held := false
	var frames := 0
	while frames < 420 and not scene._won:
		await t.physics_frame
		frames += 1
		if player.height > 0.0:
			flew = true
			if is_equal_approx(player.velocity.y, -FinaleDirector.FinaleDriver.LAUNCH_SPEED) \
					and t.root.get_viewport().get_camera_2d() != pcam:
				cam_held = true
		elif flew and not landed:
			landed = true
	t.check(flew, "finale: the car flew")
	t.check(cam_held, "finale: airborne at exactly the launch speed with the scene camera holding")
	t.check(landed and -player.global_position.y - float(fin.entry["start_d"]) >= float(fin.entry["def"]["river"]["shallow_to"]),
		"finale: it came down on the far road (d %d)" % int(-player.global_position.y - float(fin.entry["start_d"])))
	t.check(is_equal_approx(player.get_hp(), hp_before) and player.is_physics_processing(), "finale: unhurt, still driving")
	var gone := 0
	for j in fin.jumpers:
		if not is_instance_valid(j):
			gone += 1
	t.check(gone == FinaleDirector.JUMPERS, "finale: both bikes went into the river (%d)" % gone)
	t.check(scene.kills == 0 and Economy.funds == 1000 + scene.PURSE, "finale: for free — and the purse is paid at the card")
	t.check(scene._won and scene._end_screen.visible and t.paused, "finale: the card comes after the last splash (%d frames)" % frames)
	t.check(wall.halted and wall.front_y >= wall.halt_y - 0.01, "finale: the pack pulled up at the bank")
	FinaleDirector.FINALE_BEAT = beat_was
	t.paused = false
	Economy.enabled = false
	Economy.funds = 0
	gs.lives = 3
	gs.level_index = 0
	gs.carry_ammo.clear()
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()
