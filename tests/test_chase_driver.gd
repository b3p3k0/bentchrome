extends RefCounted
## ChaseDriver logic: intent contract, steer convergence, pace-hold throttle
## band, the three playbooks (bike strafe, sedan rocket-and-box, technical
## fade), flank discipline, spawn grace — plus the
## speed-band governor, the player's chase pedal, and the Buzzard data
## files' glass-cannon shape.

const DriverScript := preload("res://levels/chase/chase_driver.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

var t

class FakeController:
	var max_speed := 500.0

class FakeVehicle extends Node2D:
	var heading := -PI / 2.0   # north
	var velocity := Vector2.ZERO
	var ctrl = FakeController.new()
	func get_controller():
		return ctrl

## A car body with the attribution field the brain reads on a hit.
class HitCar extends Node2D:
	var last_attacker: Node2D = null

## A dead-straight course down x = 0.
class FakeCourse:
	func sample(_d: float) -> Dictionary:
		return {"x": 0.0, "half_w": 360.0}

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
	t.check(intent["throttle"] >= -1.0 and intent["throttle"] <= 1.0, "chase-ai: throttle is a legal pedal")
	t.check(intent["steer"] >= -1.0 and intent["steer"] <= 1.0, "chase-ai: steer clamped")
	_done(r[0])

func test_steer_converges_on_target() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	vehicle.global_position = Vector2.ZERO
	player.global_position = Vector2(-300, -800)   # ahead-left; the rush goes beside them
	var intent: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(intent["steer"] < 0.0, "chase-ai: the rush steers left toward the mark")
	_done(r[0])  # two players in the tree = the wrong mark — clear before rig 2
	var r2 := _rig()
	r2[1].global_position = Vector2.ZERO
	r2[3].global_position = Vector2(300, -800)
	var intent2: Dictionary = r2[2].get_intent(r2[1], 0.016)
	t.check(intent2["steer"] > 0.0, "chase-ai: the rush steers right toward the mark")
	_done(r2[0])

func test_pace_hold_never_stops() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]   # ctrl.max_speed 500, nose north
	var player: Node2D = r[3]
	var pace_floor: float = vehicle.ctrl.max_speed * DriverScript.MIN_PACE
	player.global_position = Vector2(0, -3000)
	vehicle.global_position = Vector2(0, 0)        # far behind the pack
	var behind: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(is_equal_approx(behind["throttle"], 1.0), "chase-ai: far behind = full gas")
	# Overshot far ahead and still carrying speed: a real brake — a Buzzard
	# can finally fall BACK to its station instead of sailing off the top.
	vehicle.global_position = Vector2(0, -6000)
	vehicle.velocity = Vector2(0, -400.0)
	var ahead: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(ahead["throttle"] < -0.5, "chase-ai: ahead of the station brakes (%.2f)" % ahead["throttle"])
	# ...but never under the pace floor: no Buzzard parks on the road.
	vehicle.velocity = Vector2(0, -(pace_floor - 20.0))
	var crawling: Dictionary = r[2].get_intent(vehicle, 0.016)
	t.check(crawling["throttle"] > 0.0, "chase-ai: under the pace floor the gas comes back — never stops")
	_done(r[0])

func test_station_speed_tracks_the_mark() -> void:
	const TOP := 500.0
	t.check(is_equal_approx(DriverScript.station_speed(400.0, 0.0, TOP), 400.0),
		"chase-ai: on station = the mark's own pace")
	t.check(DriverScript.station_speed(400.0, 100.0, TOP) > 400.0, "chase-ai: behind the station asks for more")
	t.check(DriverScript.station_speed(400.0, -100.0, TOP) < 400.0, "chase-ai: ahead of it asks for less")
	t.check(is_equal_approx(DriverScript.station_speed(0.0, -2000.0, TOP), TOP * DriverScript.MIN_PACE),
		"chase-ai: the ask never drops under the pace floor")

## A hold mark never sits in the murk: the pack rides close now, and a mark
## deep behind the player would park a bird inside the dust to be absorbed.
func test_hold_mark_stays_north_of_the_crest() -> void:
	var open: float = DriverScript.hold_mark(-1000.0, 430.0, INF)
	t.check(is_equal_approx(open, -570.0), "chase-ai: no wall, the role's station stands")
	var far: float = DriverScript.hold_mark(-1000.0, 190.0, -400.0)
	t.check(is_equal_approx(far, -810.0), "chase-ai: a mark clear of the crest is untouched")
	var squeezed: float = DriverScript.hold_mark(-1000.0, 430.0, -700.0)
	t.check(is_equal_approx(squeezed, -700.0 - DriverScript.CREST_CLEAR),
		"chase-ai: a mark in the dust is pulled north of the crest (%d)" % int(squeezed))
	# Live: a host in the tree feeds the crest, and a sedan rushing up drives
	# for the clamped mark — the crest is only 150px behind the player, so its
	# 170px tail mark is pulled north to 80px, and 40px behind THAT means gas.
	var r := _rig()
	var host := FakeHost.new()
	host.front = 150.0
	host.add_to_group(&"chase_host")
	r[0].add_child(host)
	var driver = r[2]
	driver.role = &"sedan"
	driver.phase = 3.0
	r[3].global_position = Vector2.ZERO
	r[1].global_position = Vector2(0, 120)
	var intent: Dictionary = driver.get_intent(r[1], 0.016)
	t.check(intent["throttle"] > 0.6,
		"chase-ai: behind the clamped mark = on the gas (%.2f)" % intent["throttle"])
	_done(r[0])

## A rig whose player has a velocity (the pedal reads the mark's pace).
func _rig_moving(player_vn: float) -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	container.add_child(vehicle)
	var player := FakeVehicle.new()
	player.add_to_group(&"player")
	player.velocity = Vector2(0, -player_vn)
	container.add_child(player)
	var driver = DriverScript.new()
	return [container, vehicle, driver, player]

## BIKES strafe: up your tail spraying, past you on the flank, and gone off
## the top of the screen on a burst no honest engine has — across your nose
## on the way, which is your shot.
func test_bike_strafes_and_zips_past() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	var driver = r[2]
	driver.exit_north = true
	driver.cross = true
	vehicle.global_position = Vector2.ZERO
	player.global_position = Vector2(0, -300)      # in range, dead ahead (north)
	t.check(driver.stage == DriverScript.Stage.RUSH, "bike: born rushing")
	var fired := 0
	for i in 120:
		if driver.get_intent(vehicle, 0.016)["fire_mg"]:
			fired += 1
	t.check(float(fired) / 120.0 > 0.45, "bike: spraying and praying on the way up (duty %.2f)" % (float(fired) / 120.0))
	# On your tail: no loitering — straight out onto the flank.
	var pp := player.global_position
	vehicle.global_position = pp + Vector2(DriverScript.LOITER_DX, float(DriverScript.ROLES[&"bike"]["tail_dy"]))
	driver.get_intent(vehicle, 0.016)
	t.check(driver.stage == DriverScript.Stage.PASS, "bike: on your tail it goes straight for the pass")
	# Its tail leads your nose: a dealt breakaway runs for the top of the screen.
	vehicle.global_position = pp + Vector2(DriverScript.BESIDE_DX, -DriverScript.CUT_IN_CLEAR - 10.0)
	driver.get_intent(vehicle, 0.016)
	t.check(driver.stage == DriverScript.Stage.EXIT and driver.breaking_away(), "bike: past you, it breaks away up the road")
	var mark: Vector2 = driver._sortie_mark(vehicle, vehicle.global_position, pp, INF)
	t.check(mark.y < pp.y - 1000.0, "bike: the breakaway's mark is far up the road")
	t.check(is_equal_approx(mark.x, pp.x), "bike: a cocky one cuts across your nose on the way out — your shot")
	driver.cross = false
	mark = driver._sortie_mark(vehicle, vehicle.global_position, pp, INF)
	t.check(is_equal_approx(mark.x, pp.x + DriverScript.BESIDE_DX), "bike: a careful one stays wide")
	var silent := true
	for i in 60:
		if driver.get_intent(vehicle, 0.016)["fire_mg"]:
			silent = false
	t.check(silent, "bike: no fire on the way out")
	# A breakaway that can't shake you gives up and goes home.
	var ticks := 60
	while driver.stage == DriverScript.Stage.EXIT and ticks < 600:
		driver.get_intent(vehicle, 0.016)
		ticks += 1
	t.check(driver.stage == DriverScript.Stage.PEEL and absf(float(ticks) * 0.016 - DriverScript.EXIT_TIMEOUT) < 0.1,
		"bike: a breakaway that never gets clear goes home after EXIT_TIMEOUT (%.1fs)" % (float(ticks) * 0.016))
	_done(r[0])

## The breakaway is the one honest cheat in the pack: BREAKAWAY px/s over
## whatever the player is doing, boost included. Everything else a bird does
## stays under a boost.
func test_breakaway_outruns_even_a_boost() -> void:
	var r := _rig_moving(900.0)     # the player is on the nitro
	r[0].add_child(r[2])
	var vehicle: FakeVehicle = r[1]
	var driver = r[2]
	var honest: float = vehicle.ctrl.max_speed
	driver.exit_north = true
	driver.skip_to(DriverScript.Stage.EXIT)
	r[3].global_position = Vector2(0, 0)
	vehicle.global_position = Vector2(0, -200)
	for i in 120:
		driver.get_intent(vehicle, 0.016)
	t.check(vehicle.ctrl.max_speed > 900.0 + DriverScript.BREAKAWAY * 0.9,
		"breakaway: it finds BREAKAWAY over even a boosting car (%d)" % int(vehicle.ctrl.max_speed))
	driver.peel()
	for i in 240:
		driver.get_intent(vehicle, 0.016)
	t.check(absf(vehicle.ctrl.max_speed - honest) < 2.0, "breakaway: going home, the engine gives it all back (%d)" % int(vehicle.ctrl.max_speed))
	_done(r[0])

## A bike dealt the other way out shows you its tail for a moment, then
## swerves for the shoulder and drops back into the pack.
func test_bike_that_stays_peels_to_the_shoulder() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	var driver = r[2]
	driver.exit_north = false
	player.global_position = Vector2(0, -1000)
	var pp := player.global_position
	driver.get_intent(vehicle, 0.016)   # take the aim snapshot
	driver.skip_to(DriverScript.Stage.PASS)
	vehicle.global_position = pp + Vector2(DriverScript.BESIDE_DX, -DriverScript.CUT_IN_CLEAR - 10.0)
	driver.get_intent(vehicle, 0.016)
	t.check(driver.stage == DriverScript.Stage.BOX, "bike: a bird that isn't leaving north shows you its tail")
	var span: Array = DriverScript.ROLES[&"bike"]["box"]
	t.check(driver.box_seconds() >= float(span[0]) and driver.box_seconds() <= float(span[1]) and float(span[1]) < 1.0,
		"bike: only for a moment (%.2fs)" % driver.box_seconds())
	vehicle.global_position = pp + Vector2(0.0, DriverScript.BOX_DY)
	var ticks := 0
	while driver.stage == DriverScript.Stage.BOX and ticks < 200:
		driver.get_intent(vehicle, 0.016)
		ticks += 1
	t.check(driver.stage == DriverScript.Stage.PEEL and absf(float(ticks) * 0.016 - driver.box_seconds()) <= 0.05,
		"bike: then it peels (%.2fs)" % (float(ticks) * 0.016))
	_done(r[0])

## SEDANS bully: one rocket from behind, MG blazing on the way up, then the
## box — guns silent, nose in your sights.
func test_sedan_rockets_then_boxes() -> void:
	for ph in [0.5, 2.0, 4.5]:
		var probe = DriverScript.new()
		probe.role = &"sedan"
		probe.phase = ph
		t.root.add_child(probe)
		t.check(not probe.exit_north and probe.cross, "sedan: always the box, always the cut-in (phase %.1f)" % ph)
		t.root.remove_child(probe)
		probe.free()
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	var driver = r[2]
	driver.role = &"sedan"
	driver._ready()   # re-deal as a sedan (the rig adds the node as a bike)
	vehicle.global_position = Vector2.ZERO
	player.global_position = Vector2(0, -400)
	var pulses := 0
	var first_pulse := -1
	var stage_at_pulse := -1
	var mg := 0
	for i in 300:   # the rush, from behind
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_selected"]:
			pulses += 1
			if first_pulse < 0:
				first_pulse = i
				stage_at_pulse = driver.stage
		if intent["fire_mg"]:
			mg += 1
	t.check(pulses == 1, "sedan: ONE rocket per sortie (%d)" % pulses)
	t.check(stage_at_pulse == DriverScript.Stage.RUSH and float(first_pulse) * 0.016 < 2.0,
		"sedan: popped early, from behind, before it comes up (%.1fs)" % (float(first_pulse) * 0.016))
	t.check(float(mg) / 300.0 > 0.25, "sedan: MG blazing on the way up (duty %.2f)" % (float(mg) / 300.0))
	# The box: on station, guns silent, for its dealt seconds.
	var pp := player.global_position
	driver.skip_to(DriverScript.Stage.BOX)
	vehicle.global_position = pp + Vector2(0.0, DriverScript.BOX_DY)
	var span: Array = DriverScript.ROLES[&"sedan"]["box"]
	t.check(driver.box_seconds() >= float(span[0]) and driver.box_seconds() <= float(span[1]),
		"sedan: the box holds a couple of seconds (dealt %.2fs)" % driver.box_seconds())
	var fired := 0
	var ticks := 0
	while driver.stage == DriverScript.Stage.BOX and ticks < 400:
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_mg"] or intent["fire_selected"]:
			fired += 1
		ticks += 1
	t.check(fired == 0, "sedan: the box is a body block — guns silent")
	t.check(absf(float(ticks) * 0.016 - driver.box_seconds()) <= 0.05, "sedan: it lasts its dealt seconds on station (%.2fs)" % (float(ticks) * 0.016))
	t.check(driver.stage == DriverScript.Stage.PEEL, "sedan: then it peels off")
	var fired_peeling := 0
	vehicle.velocity = Vector2(0, -400.0)
	vehicle.global_position = pp + Vector2(300.0, 100.0)
	var eased := false
	for i in 60:
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_mg"]:
			fired_peeling += 1
		if float(intent["throttle"]) < 0.0:
			eased = true
	t.check(fired_peeling == 0, "sedan: no fire on the way home")
	t.check(eased, "sedan: peeling, the pedal comes off — home is the pack")
	_done(r[0])

## Ahead of you the rocket stays in the tube: it is a from-behind weapon.
func test_sedan_never_rockets_from_ahead() -> void:
	var r := _rig()
	r[2].role = &"sedan"
	r[2]._ready()
	r[3].global_position = Vector2(0, 0)
	r[1].global_position = Vector2(100, -100)
	var popped := false
	for i in 300:
		if r[2].get_intent(r[1], 0.016)["fire_selected"]:
			popped = true
	t.check(not popped, "sedan: never rockets from ahead of you")
	_done(r[0])

## Birds pass you, they never drive through you: on your tail the pass mark
## is out on the flank AND held back, clear of your flank it goes by, a
## cut-in waits until it leads your nose, and a bird leaving swerves for the
## SHOULDER before it lifts.
func test_birds_pass_on_the_flank() -> void:
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	var driver = r[2]
	driver.lane_offset = 120.0
	driver._side = 1.0
	driver.exit_north = false
	driver.cross = true
	player.global_position = Vector2(0, -1000)
	driver.get_intent(vehicle, 0.016)   # take the aim snapshot
	var pp := player.global_position
	driver.skip_to(DriverScript.Stage.PASS)
	var astern: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(10, 150), pp, INF)
	t.check(is_equal_approx(astern.x, pp.x + DriverScript.BESIDE_DX), "flank: moving up, the mark is out on the bird's side")
	t.check(is_equal_approx(astern.y, pp.y + DriverScript.QUARTER_DY), "flank: on your tail it hangs off your quarter, never through you")
	var wide: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(120, 150), pp, INF)
	t.check(is_equal_approx(wide.y, pp.y - DriverScript.PASS_LEAD), "flank: clear of your flank it goes by")
	driver.skip_to(DriverScript.Stage.BOX)
	var level: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(120, 0), pp, INF)
	t.check(is_equal_approx(level.x, pp.x + DriverScript.BESIDE_DX), "flank: level with you the box bird stays in its own lane")
	var ahead: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(120, -DriverScript.CUT_IN_CLEAR - 10.0), pp, INF)
	t.check(is_equal_approx(ahead.x, pp.x), "flank: once it leads your nose it cuts across — at where you were")
	driver.peel()
	var wide_lane: float = DriverScript.BESIDE_DX * 2.0   # the fixture's "shoulder" (no course in the tree)
	var boxed: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(5, -110), pp, INF)
	t.check(is_equal_approx(boxed.x, pp.x + wide_lane) and is_equal_approx(boxed.y, pp.y - 110.0),
		"flank: leaving the box it swerves out first — no brake check")
	var clear: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(130, -110), pp, INF)
	t.check(clear.y > pp.y + 300.0, "flank: clear of you, it drops home to the pack")
	t.check(is_equal_approx(clear.x, pp.x + wide_lane), "flank: down the shoulder — never back across your nose")
	var left: Vector2 = driver._sortie_mark(vehicle, pp + Vector2(-30, -110), pp, INF)
	t.check(is_equal_approx(left.x, pp.x - wide_lane), "flank: a bird boxed on your left leaves left")
	_done(r[0])
	# With a road under it, the way out IS the shoulder: past the road edge,
	# on the verge — and the other verge when you are hugging that one.
	var r2 := _rig()
	var host := FakeHost.new()
	host.course = FakeCourse.new()
	host.add_to_group(&"chase_host")
	r2[0].add_child(host)
	r2[3].global_position = Vector2(0, -1000)
	r2[2].get_intent(r2[1], 0.016)
	r2[2].peel()
	var edge: float = 360.0 + DriverScript.SHOULDER_OUT
	var verge: Vector2 = r2[2]._sortie_mark(r2[1], Vector2(40, -1100), Vector2(0, -1000), INF)
	t.check(is_equal_approx(verge.x, edge), "shoulder: a leaving bird rides the verge past the road edge (%d)" % int(verge.x))
	var hugged: Vector2 = r2[2]._sortie_mark(r2[1], Vector2(352, -1100), Vector2(345, -1000), INF)
	t.check(is_equal_approx(hugged.x, -edge), "shoulder: hugging that verge yourself sends it to the other one")
	_done(r2[0])

## A bird that can't get by doesn't hang on your quarter forever.
func test_pass_gives_up() -> void:
	var r := _rig()
	var driver = r[2]
	r[1].global_position = Vector2(0, 400)      # far astern and never moving
	r[3].global_position = Vector2(0, -300)
	driver.skip_to(DriverScript.Stage.PASS)
	var ticks := 0
	while driver.stage == DriverScript.Stage.PASS and ticks < 600:
		driver.get_intent(r[1], 0.016)
		ticks += 1
	t.check(driver.stage == DriverScript.Stage.PEEL and absf(float(ticks) * 0.016 - DriverScript.PASS_TIMEOUT) <= 0.05,
		"sortie: a bird that can't get by goes home after PASS_TIMEOUT (%.2fs)" % (float(ticks) * 0.016))
	_done(r[0])

## A rush that never reaches your tail still gets its turn.
func test_rush_runs_out_of_patience() -> void:
	var r := _rig()
	var driver = r[2]
	r[1].global_position = Vector2(0, 900)
	r[3].global_position = Vector2(0, -300)
	var ticks := 0
	while driver.stage == DriverScript.Stage.RUSH and ticks < 600:
		driver.get_intent(r[1], 0.016)
		ticks += 1
	t.check(driver.stage == DriverScript.Stage.PASS and absf(float(ticks) * 0.016 - DriverScript.RUSH_TIMEOUT) <= 0.05,
		"sortie: patience is RUSH_TIMEOUT (%.2fs)" % (float(ticks) * 0.016))
	_done(r[0])

## The sprint never out-runs a boost: nitro always shakes a bird that is
## coming UP. (Only a breakaway, already past you and leaving, cheats.)
func test_sprint_stays_under_a_boost() -> void:
	const Director := preload("res://levels/chase/chase_director.gd")
	for kind in Director.ROLE_PACE:
		var role: Dictionary = DriverScript.ROLES[kind]
		if not role.get("sortie", false):
			continue
		var best: float = float(Director.ROLE_PACE[kind]) * float(role["sprint"])
		t.check(best < 1.45, "sortie: a %s's sprint (%.2f of your top) stays under a boost's 1.5x" % [kind, best])
		t.check(best > 1.2, "sortie: and it is enough to pass a flat-out car in about a second (%.2f)" % best)
	t.check(float(DriverScript.ROLES[&"bike"]["sprint"]) > float(DriverScript.ROLES[&"sedan"]["sprint"]),
		"sortie: bikes come up faster than sedans")
	var r := _rig()
	var vehicle: FakeVehicle = r[1]
	var driver = r[2]
	var honest: float = vehicle.ctrl.max_speed
	var sprint: float = DriverScript.ROLES[&"bike"]["sprint"]
	for i in 60:
		driver._sprint(vehicle, 150.0, 0.016)
	t.check(absf(vehicle.ctrl.max_speed - honest * sprint) < 12.0,
		"sortie: behind its mark the engine finds the sprint (%d)" % int(vehicle.ctrl.max_speed))
	for i in 120:
		driver._sprint(vehicle, 0.0, 0.016)
	t.check(absf(vehicle.ctrl.max_speed - honest) < 1.0, "sortie: on its mark it gives it back (%d)" % int(vehicle.ctrl.max_speed))
	_done(r[0])

## Sedans are timid: a weapon hit, or a few MG rounds, and they swerve for
## the shoulder. Bikes are committed — they die or they leave.
func test_sedan_flinches_bike_commits() -> void:
	var r := _rig()
	var driver = r[2]
	driver.role = &"sedan"
	r[3].global_position = Vector2(0, -300)
	driver.skip_to(DriverScript.Stage.BOX)
	var nerve: float = DriverScript.ROLES[&"sedan"]["flinch"]
	t.check(nerve > 2.0 and nerve <= 8.0, "flinch: a sedan's nerve is a few MG rounds (%.0f damage at 2 a round)" % nerve)
	driver._on_hit(2.0, 23.0)
	driver._on_hit(2.0, 21.0)
	t.check(driver.stage == DriverScript.Stage.BOX, "flinch: a scratch doesn't scare it")
	driver._on_hit(2.0, 19.0)
	t.check(driver.stage == DriverScript.Stage.PEEL, "flinch: a few MG rounds and it peels")
	driver.peel()
	t.check(driver.stage == DriverScript.Stage.PEEL, "flinch: peeling twice is harmless")
	driver.skip_to(DriverScript.Stage.BOX)
	t.check(driver.stage == DriverScript.Stage.PEEL, "flinch: the sortie only ever runs forward")
	_done(r[0])
	var r2 := _rig()
	r2[2].role = &"sedan"
	r2[2]._on_hit(15.0, 10.0)
	t.check(r2[2].stage == DriverScript.Stage.PEEL, "flinch: one weapon hit sends a sedan home — from any stage")
	_done(r2[0])
	var r3 := _rig()
	r3[2]._on_hit(12.0, 2.0)
	t.check(r3[2].stage == DriverScript.Stage.RUSH, "flinch: a bike is committed — it dies or it leaves")
	_done(r3[0])
	# The pack's own stray lead doesn't count: only the player's fire scares a sedan.
	var yard := Node2D.new()
	t.root.add_child(yard)
	var car := HitCar.new()
	yard.add_child(car)
	var brain = DriverScript.new()
	brain.role = &"sedan"
	car.add_child(brain)
	var packmate := Node2D.new()
	yard.add_child(packmate)
	car.last_attacker = packmate
	brain._on_hit(20.0, 5.0)
	t.check(brain.stage == DriverScript.Stage.RUSH, "flinch: friendly fire from the pack is shrugged off")
	var shooter := Node2D.new()
	shooter.add_to_group(&"player")
	yard.add_child(shooter)
	car.last_attacker = shooter
	brain._on_hit(20.0, 5.0)
	t.check(brain.stage == DriverScript.Stage.PEEL, "flinch: the player's fire is what sends it home")
	t.root.remove_child(yard)
	yard.free()

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

## Steering is a lane change: the nose swings at most LANE_YAW_DEG off north
## and comes back to straight hands-off; the handbrake is eaten.
func test_lane_steering() -> void:
	const IR := preload("res://game/input_router.gd")
	const Pedal := preload("res://levels/chase/chase_player_driver.gd")
	var north: float = -PI / 2.0
	var cone: float = deg_to_rad(Pedal.LANE_YAW_DEG)
	t.check(Pedal.lane_steer(north, 1.0) > 0.5, "lane: RIGHT from straight swings the nose right")
	t.check(Pedal.lane_steer(north, -1.0) < -0.5, "lane: LEFT from straight swings the nose left")
	t.check(is_equal_approx(Pedal.lane_steer(north + cone, 1.0), 0.0),
		"lane: at the cone's edge, RIGHT asks for nothing more")
	t.check(Pedal.lane_steer(north + cone, 0.0) < 0.0, "lane: hands off, the nose comes back toward north")
	t.check(is_equal_approx(Pedal.lane_steer(north, 0.0), 0.0), "lane: straight and hands off = no steer")
	t.check(Pedal.lane_steer(north + cone * 2.0, 1.0) < 0.0,
		"lane: past the cone (a shove), even RIGHT steers back inside it")
	t.check(Pedal.lane_steer(north + PI, 0.0) != 0.0, "lane: a car facing south is steered back around")
	# A sweeper is the driver's to drive, and the cone has to be able to: over
	# every bend chunk as a whole (exit_dx over len) full lock out-turns the
	# road, and on the steepest single leg of any chunk (the chicane's
	# middle) a car at full lock falls off the centreline by less than a
	# quarter of the road before the leg ends — the line is yours to find,
	# never yours to lose.
	var lock := tan(deg_to_rad(Pedal.LANE_YAW_DEG))
	var worst_leg := 0.0
	var worst_name := &""
	for name in ChunkDefs.DEFS:
		var def: Dictionary = ChunkDefs.DEFS[name]
		var whole := absf(float(def["exit_dx"])) / float(def["len"])
		t.check(whole < lock, "lane: full lock out-turns the %s chunk as a whole" % name)
		var pts: Array = [Vector2.ZERO]
		for pt in def.get("path", []):
			pts.append(Vector2(pt[0], pt[1]))
		pts.append(Vector2(def["len"], def["exit_dx"]))
		for i in pts.size() - 1:
			var run: float = pts[i + 1].x - pts[i].x
			var rise: float = absf(pts[i + 1].y - pts[i].y)
			var deficit := maxf(rise / run - lock, 0.0) * run   # px the centreline gets away, at full lock
			if deficit > worst_leg:
				worst_leg = deficit
				worst_name = name
	t.check(worst_leg < 90.0, "lane: the steepest leg (%s) only gets %dpx away from full lock — a quarter of the road" % [worst_name, int(worst_leg)])
	# Through the real driver: the arena's free wheel and whip are gone.
	var container := Node2D.new()
	t.root.add_child(container)
	var vehicle := FakeVehicle.new()
	vehicle.velocity = Vector2(0, -400.0)
	container.add_child(vehicle)
	var driver = Pedal.new()
	container.add_child(driver)
	Input.action_press(IR.ACTION_MOVE_RIGHT)
	Input.action_press(IR.ACTION_HANDBRAKE)
	var intent: Dictionary = driver.get_intent(vehicle, 0.016)
	Input.action_release(IR.ACTION_MOVE_RIGHT)
	Input.action_release(IR.ACTION_HANDBRAKE)
	t.check(intent["steer"] > 0.0, "lane: RIGHT reaches the wheel")
	t.check(not intent["handbrake"], "lane: the handbrake is eaten on Route 666")
	vehicle.heading = north + cone
	var held: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(is_equal_approx(float(held["steer"]), 0.0) or float(held["steer"]) < 0.0,
		"lane: hands off at the cone's edge, the wheel centres")
	t.root.remove_child(container)
	container.free()

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

## The technical: never touches a trigger (the bed turret does the talking),
## never sprints, and once it is inside its mark it gives ground at a steady
## `fade` whatever the player does with the pedal — a few seconds on screen.
func test_technical_fades_at_a_steady_rate() -> void:
	var r := _rig_moving(500.0)
	r[0].add_child(r[2])
	var driver = r[2]
	driver.role = &"technical"
	var vehicle: FakeVehicle = r[1]
	var player: FakeVehicle = r[3]
	vehicle.ctrl.max_speed = 310.0                 # 0.62 of a 500 top
	player.global_position = Vector2(0, -400)
	vehicle.global_position = Vector2(0, -200)   # close behind — bikes would shoot
	var fired := false
	for i in 200:
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_mg"] or intent["fire_selected"]:
			fired = true
	t.check(not fired, "technical: the driver never touches a trigger")
	t.check(is_equal_approx(vehicle.ctrl.max_speed, 310.0), "technical: no sprint — falling back is the job")
	var fade: float = DriverScript.ROLES[&"technical"]["fade"]
	t.check(fade >= 200.0 and fade <= 320.0, "technical: on screen for four to six seconds (fade %d px/s)" % int(fade))
	# Inside its mark, 300px ahead of a flat-out car: it wants YOUR pace minus the fade.
	vehicle.global_position = player.global_position + Vector2(0, -300)
	vehicle.velocity = Vector2(0, -(500.0 - fade) - 60.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] < 0.0, "technical: faster than the fade asks, it lifts")
	vehicle.velocity = Vector2(0, -(500.0 - fade) + 60.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] > 0.0, "technical: slower than the fade asks, it gets back on the gas")
	# The player brakes hard: the truck does NOT hang there — it gives ground just the same.
	player.velocity = Vector2(0, -300.0)
	vehicle.velocity = Vector2(0, -250.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] < 0.0, "technical: brake and it still fades — it never parks on your nose")
	# Far up the road, outside its mark: it crawls, so it reaches the screen quickly.
	player.velocity = Vector2(0, -500.0)
	vehicle.global_position = player.global_position + Vector2(0, -1500)
	vehicle.velocity = Vector2(0, -250.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] < 0.0, "technical: up the road it waits for you at a crawl")
	vehicle.velocity = Vector2(0, -(310.0 * DriverScript.MIN_PACE) + 30.0)
	t.check(driver.get_intent(vehicle, 0.016)["throttle"] > 0.0, "technical: but never under the pace floor")
	_done(r[0])

## The blocker: steals YOUR lane while it's ahead of you, on a stale read a
## late juke beats; gives the lane up once passed; never touches a trigger.
func test_blocker_steals_the_lane_then_gives_it_up() -> void:
	var r := _rig()
	var driver = r[2]
	driver.role = &"blocker"
	driver.lane_offset = 200.0   # its own lane is far right
	var vehicle: FakeVehicle = r[1]
	var player: Node2D = r[3]
	player.global_position = Vector2(-250, 0)      # the player runs far LEFT
	vehicle.global_position = Vector2(100, -600)   # blocker ahead (north), to the right
	var ahead: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(ahead["steer"] < 0.0, "blocker: ahead of you, it steers INTO your lane (%.2f)" % ahead["steer"])
	# The read is stale: the player jukes right, the blocker keeps heading left.
	player.global_position = Vector2(250, 0)
	var fooled: Dictionary = driver.get_intent(vehicle, 0.016)
	t.check(fooled["steer"] < 0.0, "blocker: a late juke beats the stale snapshot")
	var caught_up := false
	for i in 60:   # a second later the snapshot has refreshed
		var later: Dictionary = driver.get_intent(vehicle, 0.016)
		if later["steer"] > 0.0:
			caught_up = true
	t.check(caught_up, "blocker: but it does catch on, eventually")
	var fired := false
	vehicle.global_position = Vector2(250, -200)
	for i in 200:
		var intent: Dictionary = driver.get_intent(vehicle, 0.016)
		if intent["fire_mg"] or intent["fire_selected"]:
			fired = true
	t.check(not fired, "blocker: never touches a trigger")
	# Passed: it gives the lane up and heads for its own.
	_done(r[0])
	var r2 := _rig()
	r2[2].role = &"blocker"
	r2[2].lane_offset = 200.0
	r2[3].global_position = Vector2(-250, -1000)   # the player is now AHEAD of it
	r2[1].global_position = Vector2(0, -600)
	var passed: Dictionary = r2[2].get_intent(r2[1], 0.016)
	t.check(passed["steer"] > 0.0, "blocker: once passed it gives up your lane for its own (%.2f)" % passed["steer"])
	var base: float = r2[1].ctrl.max_speed
	r2[1].global_position = Vector2(0, 1000)       # far behind: a bike would sprint
	for i in 40:
		r2[2].get_intent(r2[1], 0.1)
	t.check(is_equal_approx(r2[1].ctrl.max_speed, base), "blocker: no sprint — falling back is the job")
	_done(r2[0])

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
