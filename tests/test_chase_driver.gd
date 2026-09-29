extends RefCounted
## ChaseDriver logic: intent contract, steer convergence, pace-hold throttle
## band, burst duty cycle, spawn grace, sedan rocket cadence — plus the
## speed-band governor, the player's chase pedal, and the Buzzard data
## files' glass-cannon shape.

const DriverScript := preload("res://levels/chase/chase_driver.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")

var t

class FakeController:
	var max_speed := 500.0

class FakeVehicle extends Node2D:
	var heading := -PI / 2.0   # north
	var velocity := Vector2.ZERO
	var ctrl = FakeController.new()
	func get_controller():
		return ctrl

## The chase host's duck-typed surface as the Buzzard brain sees it.
class FakeHost extends Node:
	var course = null
	var front := INF
	func wall_front_y() -> float:
		return front

func _init(runner) -> void:
	t = runner

## [container, vehicle, driver, player] — no chase_host in the tree, so the
## driver's road clamp falls back to line-holding (pure logic under test).
func _rig() -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	container.add_child(vehicle)
	var player := Node2D.new()
	player.add_to_group(&"player")
	container.add_child(player)
	var driver = DriverScript.new()
	container.add_child(driver)
	return [container, vehicle, driver, player]

func _done(container: Node) -> void:
	t.root.remove_child(container)
	container.free()

func test_intent_contract() -> void:
	var r := _rig()
	var intent: Dictionary = r[2].get_intent(r[1], 0.016)
	for key in ["throttle", "steer", "fire_mg", "fire_selected"]:
		t.check(intent.has(key), "chase-ai: intent carries %s" % key)
	t.check(intent["throttle"] >= 0.35 and intent["throttle"] <= 1.0, "chase-ai: throttle in the pace band")
	t.check(intent["steer"] >= -1.0 and intent["steer"] <= 1.0, "chase-ai: steer clamped")
	_done(r[0])

func test_steer_converges_on_target() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	vehicle.global_position = Vector2.ZERO
	player.global_position = Vector2(-300, -800)   # ahead-left; swoop opens the cycle
	var intent: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(intent["steer"] < 0.0, "chase-ai: swoop steers left toward the mark")
	_done(r[0])  # two players in the tree = the wrong mark — clear before rig 2
	var r2 := _rig()
	r2[1].global_position = Vector2.ZERO
	r2[3].global_position = Vector2(300, -800)
	var intent2: Dictionary = r2[2].get_intent(r2[1], 0.016)
	t.check(intent2["steer"] > 0.0, "chase-ai: swoop steers right toward the mark")
	_done(r2[0])

func test_pace_hold_never_stops() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	player.global_position = Vector2(0, -3000)
	vehicle.global_position = Vector2(0, 0)        # far behind the pack
	var behind: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(is_equal_approx(behind["throttle"], 1.0), "chase-ai: far behind = full gas")
	vehicle.global_position = Vector2(0, -6000)    # overshot far ahead
	var ahead: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(is_equal_approx(ahead["throttle"], 0.35), "chase-ai: ahead eases to the floor, never stops")
	_done(r[0])

## A hold mark never sits in the murk: the pack rides close now, and a sedan
## station of 430px would park it inside the dust to be absorbed.
func test_hold_mark_stays_north_of_the_crest() -> void:
	var open: float = DriverScript.hold_mark(-1000.0, 430.0, INF)
	t.check(is_equal_approx(open, -570.0), "chase-ai: no wall, the role's station stands")
	var far: float = DriverScript.hold_mark(-1000.0, 190.0, -400.0)
	t.check(is_equal_approx(far, -810.0), "chase-ai: a mark clear of the crest is untouched")
	var squeezed: float = DriverScript.hold_mark(-1000.0, 430.0, -700.0)
	t.check(is_equal_approx(squeezed, -700.0 - DriverScript.CREST_CLEAR),
		"chase-ai: a mark in the dust is pulled north of the crest (%d)" % int(squeezed))
	# Live: a host in the tree feeds the crest, and the sedan drives for the
	# clamped mark — 30px behind it means gas, not the ease-off its raw
	# station (170px further south) would call for.
	var r := _rig()
	var host := FakeHost.new()
	host.front = 300.0
	host.add_to_group(&"chase_host")
	r[0].add_child(host)
	var driver = r[2]
	driver.role = &"sedan"
	driver.phase = 3.0  # outside the swoop window: the far station is live
	r[3].global_position = Vector2.ZERO
	r[1].global_position = Vector2(0, 260)
	var intent: Dictionary = driver.get_intent(r[1], 0.016)
	t.check(intent["throttle"] > 0.6,
		"chase-ai: behind the clamped mark = on the gas (%.2f)" % intent["throttle"])
	_done(r[0])

func test_burst_duty_cycle() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	vehicle.global_position = Vector2.ZERO
	player.global_position = Vector2(0, -300)      # in range, dead ahead (north)
	var fired := 0
	var ticks := 400
	for i in ticks:
		var intent: Dictionary = r[2].get_intent(vehicle, 0.016)
		if intent["fire_mg"]:
			fired += 1
	var duty := float(fired) / float(ticks)
	t.check(duty > 0.1 and duty < 0.35,
		"chase-ai: bike fires in bursts, not a hose (duty %.2f)" % duty)
	_done(r[0])

func test_hold_fire_grace() -> void:
	var r := _rig()
	r[2].hold_fire = true
	r[3].global_position = Vector2(0, -300)
	var fired := false
	for i in 120:
		var intent: Dictionary = r[2].get_intent(r[1], 0.016)
		if intent["fire_mg"] or intent["fire_selected"]:
			fired = true
	t.check(not fired, "chase-ai: spawn grace holds every trigger")
	_done(r[0])

func test_sedan_rocket_cadence() -> void:
	var r := _rig()
	var driver = r[2]
	driver.role = &"sedan"
	r[3].global_position = Vector2(0, -400)
	var pulses := 0
	var streak := 0
	var max_streak := 0
	for i in 500:  # 8 seconds
		var intent: Dictionary = driver.get_intent(r[1], 0.016)
		if intent["fire_selected"]:
			pulses += 1
			streak += 1
			max_streak = maxi(max_streak, streak)
		else:
			streak = 0
	t.check(pulses >= 1 and pulses <= 3, "chase-ai: sedan rockets on a lazy clock (%d in 8s)" % pulses)
	t.check(max_streak <= 1, "chase-ai: rocket intent is a single-frame pulse")
	_done(r[0])

func test_yoyo_catchup() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	container.add_child(vehicle)
	var player := FakeVehicle.new()   # has velocity — the sprinting mark
	player.add_to_group(&"player")
	player.velocity = Vector2(0, -600)
	player.global_position = Vector2(0, -2000)
	container.add_child(player)
	var driver = DriverScript.new()
	container.add_child(driver)
	vehicle.global_position = Vector2(0, -1000)  # 1000px behind — cheat range
	for i in 40:
		driver.get_intent(vehicle, 0.1)
	t.check(vehicle.ctrl.max_speed > 600.0,
		"chase-ai: yo-yo finds the pace when trailing (%d)" % int(vehicle.ctrl.max_speed))
	vehicle.global_position = Vector2(0, -1900)  # 100px behind — knife range
	for i in 40:
		driver.get_intent(vehicle, 0.1)
	t.check(vehicle.ctrl.max_speed < 560.0,
		"chase-ai: honest stats resume up close (%d)" % int(vehicle.ctrl.max_speed))
	t.root.remove_child(container)
	container.free()

## The governor's pure math: carry a speed up to a target and hold it; the
## brake only bites rolling forward, well over the target.
func test_speed_band_governor() -> void:
	const TOP := 500.0
	var cruise: float = TOP * SpeedBand.CRUISE_FRAC
	var floor_speed: float = TOP * SpeedBand.FLOOR_FRAC
	t.check(floor_speed < cruise and cruise < TOP, "band: floor < cruise < top")
	t.check(is_equal_approx(SpeedBand.band_target(0.0, TOP), cruise), "band: hands off asks for cruise")
	t.check(is_equal_approx(SpeedBand.band_target(1.0, TOP), TOP), "band: W asks for the top")
	t.check(is_equal_approx(SpeedBand.band_target(-1.0, TOP), floor_speed), "band: S asks for the floor")
	t.check(is_equal_approx(SpeedBand.band_target(0.5, TOP), (cruise + TOP) * 0.5),
		"band: a half stick lands between cruise and top")
	t.check(is_equal_approx(SpeedBand.toward(100.0, cruise, false), 1.0), "band: far under the target = full gas")
	var near: float = SpeedBand.toward(cruise - SpeedBand.BAND * 0.5, cruise, false)
	t.check(is_equal_approx(near, 0.5), "band: the gas ramps down into the target (%.2f)" % near)
	t.check(is_equal_approx(SpeedBand.toward(cruise + 60.0, cruise, false), 0.0),
		"band: over the target without the brake = coast")
	t.check(is_equal_approx(SpeedBand.toward(cruise + 60.0, cruise, true), -1.0),
		"band: over the target with the brake = brake")
	t.check(is_equal_approx(SpeedBand.toward(cruise + 4.0, cruise, true), 0.0),
		"band: inside the brake margin the pedal rests (no chatter)")
	t.check(SpeedBand.toward(5.0, -50.0, true) >= 0.0, "band: never the brake at a crawl — that's reverse gear")
	t.check(SpeedBand.toward(-200.0, -400.0, true) >= 0.0, "band: never the brake mid backward-slide")

## The player's pedal through the real driver: speed up, slow down, never stop.
func test_player_pedal_is_a_speed_band() -> void:
	const IR := preload("res://game/input_router.gd")
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()   # heading north, ctrl.max_speed 500
	container.add_child(vehicle)
	var driver = preload("res://levels/chase/chase_player_driver.gd").new()
	container.add_child(driver)
	var top: float = vehicle.ctrl.max_speed
	var cruise: float = top * SpeedBand.CRUISE_FRAC
	var floor_speed: float = top * SpeedBand.FLOOR_FRAC
	# Hands off: gas below cruise, coast above it — settles at cruise, not top.
	vehicle.velocity = Vector2(0, -200.0)
	var slow: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(slow["throttle"] > 0.9, "chase: hands off under cruise pulls up to it (%.2f)" % slow["throttle"])
	vehicle.velocity = Vector2(0, -(cruise + 30.0))
	var fast: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_equal_approx(fast["throttle"], 0.0), "chase: hands off over cruise coasts — never the top for free")
	# S: a real brake above the floor, a HOLD at it — never a stop, never reverse.
	Input.action_press(IR.ACTION_MOVE_DOWN)
	vehicle.velocity = Vector2(0, -top)
	var braking: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(braking["throttle"] < -0.5, "chase: S brakes while above the floor (%.2f)" % braking["throttle"])
	vehicle.velocity = Vector2(0, -(floor_speed - 5.0))
	var held: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(held["throttle"] > 0.0, "chase: S under the floor feeds gas — the car never stops (%.2f)" % held["throttle"])
	vehicle.velocity = Vector2.ZERO
	var parked: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(parked["throttle"] > 0.9, "chase: S at a standstill is full gas, not reverse")
	# Post-whip backward slide (nose north, travelling south along it): the
	# brake would be reverse gear and chop the slide — the pedal rests.
	vehicle.velocity = Vector2(0, 300.0)
	var sliding: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_equal_approx(sliding["throttle"], 0.0), "chase: S in a backward slide never finds reverse")
	Input.action_release(IR.ACTION_MOVE_DOWN)
	var drifting: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_equal_approx(drifting["throttle"], 0.0), "chase: hands off in a backward slide coasts")
	# W: flat out, the controller owns the ceiling.
	Input.action_press(IR.ACTION_MOVE_UP)
	vehicle.velocity = Vector2(0, -top)
	var sprint: Dictionary = driver.get_intent(vehicle, 0.016)
	Input.action_release(IR.ACTION_MOVE_UP)
	t.check(is_equal_approx(sprint["throttle"], 1.0), "chase: W is flat out")
	# Boost: full throttle even over the honest top — the headroom is the point.
	t.check(is_equal_approx(SpeedBand.pedal(0.0, top * 1.3, top, true), 1.0),
		"chase: a live boost is never governed")
	t.check(is_equal_approx(SpeedBand.pedal(-1.0, top * 1.3, top, false), -1.0),
		"chase: a dry boost button governs like any other pedal")
	t.root.remove_child(container)
	container.free()

func test_technical_holds_lane_and_never_fires() -> void:
	var r := _rig()
	var driver = r[2]
	driver.role = &"technical"
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	player.global_position = Vector2(0, -400)
	vehicle.global_position = Vector2(0, -200)   # close behind — bikes would shoot
	var fired := false
	for i in 200:
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_mg"] or intent["fire_selected"]:
			fired = true
	t.check(not fired, "chase-ai: technical's driver never touches a trigger")
	vehicle.global_position = Vector2(0, 1000)   # 1400 behind — yo-yo range for others
	var base: float = vehicle.ctrl.max_speed
	for i in 40:
		driver.get_intent(vehicle, 0.1)
	t.check(is_equal_approx(vehicle.ctrl.max_speed, base),
		"chase-ai: no yo-yo — falling back is the technical's job")
	var behind_mark: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_equal_approx(behind_mark["throttle"], 1.0),
		"chase-ai: it always chases its ahead-mark flat out")
	_done(r[0])

func test_buzzard_data_shape() -> void:
	var bike = load("res://data/vehicles/buzz_bike.tres")
	var sedan = load("res://data/vehicles/buzz_sedan.tres")
	t.check(bike.armor <= 3 and sedan.armor <= 5, "buzzardz: glass cannons, thin plating")
	t.check(bike.no_mines and sedan.no_mines, "buzzardz: never mine the road")
	t.check(bike.special == null, "buzzardz: scouts carry no signature weapon")
	t.check(sedan.special != null and sedan.special.damage <= 15.0,
		"buzzardz: sedan rocket stays a nuisance")
	t.check(bike.top_speed >= 13, "buzzardz: bikes can actually catch you")
	var tech = load("res://data/vehicles/buzz_technical.tres")
	t.check(tech.top_speed <= 5, "buzzardz: the technical can't chase — it doesn't have to")
	t.check(tech.no_mines, "buzzardz: technicals never mine the road")
	t.check(tech.turret != null and tech.turret.damage <= 15.0 and tech.turret.cooldown >= 2.0
		and tech.turret.projectile_speed <= 800.0,
		"buzzardz: the bed gun thumps but stays dodgeable")
	var buzzard = load("res://levels/chase/buzzard.tscn").instantiate()
	t.check(buzzard.ai_cooldown_scale < 3.0,
		"buzzardz: pack cadence, not the arena 3x throttle")
	buzzard.free()
