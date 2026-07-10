extends RefCounted
## ChaseDriver logic: intent contract, steer convergence, pace-hold throttle
## band, burst duty cycle, spawn grace, sedan rocket cadence — plus the
## Buzzard data files' glass-cannon shape.

const DriverScript := preload("res://levels/chase/chase_driver.gd")

var t

class FakeVehicle extends Node2D:
	var heading := -PI / 2.0   # north
	var velocity := Vector2.ZERO

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

func test_buzzard_data_shape() -> void:
	var bike = load("res://data/vehicles/buzz_bike.tres")
	var sedan = load("res://data/vehicles/buzz_sedan.tres")
	t.check(bike.armor <= 2 and sedan.armor <= 3, "buzzardz: glass cannons, thin plating")
	t.check(bike.no_mines and sedan.no_mines, "buzzardz: never mine the road")
	t.check(bike.special == null, "buzzardz: scouts carry no signature weapon")
	t.check(sedan.special != null and sedan.special.damage <= 15.0,
		"buzzardz: sedan rocket stays a nuisance")
	t.check(bike.top_speed >= 7, "buzzardz: bikes can actually catch you")
	var buzzard = load("res://levels/chase/buzzard.tscn").instantiate()
	t.check(buzzard.ai_cooldown_scale < 3.0,
		"buzzardz: pack cadence, not the arena 3x throttle")
	buzzard.free()
