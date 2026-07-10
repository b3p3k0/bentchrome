extends RefCounted
## The phase-1 brain's reflexes, headless: a player in the front arc gets the
## grille (RAM), a player on the flank gets the tail steered INTO them
## (JACKKNIFE with the away-side sign), out-of-range players are ignored on
## the loop, committed maneuvers expire through the PARTING shot back to the
## loop with re-engage grace, and a pinned rig trips the real-velocity stuck
## sense into a committed reverse RECOVER. The rig is a duck-typed fake so
## the tests own its reported real velocity (the driver never types Vehicle).

const DriverScript := preload("res://vehicles/goliath/goliath_driver.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

## Everything the driver duck-types off its vehicle, with a scriptable
## real velocity so stuck detection is deterministic.
class FakeRig:
	extends Node2D
	var heading := 0.0
	var velocity := Vector2.ZERO     # written by the forced charge
	var fake_vel := Vector2(400, 0)  # cruising: fast enough to earn the tail
	func get_real_velocity() -> Vector2:
		return fake_vel

## A stand-in BossController: just the phase the driver reads.
class FakeBoss:
	extends Node
	var phase := 2

var t

func _init(runner) -> void:
	t = runner

func _fixture(player_at: Vector2) -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var rig := FakeRig.new()
	container.add_child(rig)
	var driver = DriverScript.new()
	driver.set_loop(PackedVector2Array([Vector2(10000, 0)]))  # far mark: pure LOOP
	rig.add_child(driver)
	var player = VehicleScene.instantiate()
	player.position = player_at
	container.add_child(player)
	return {"container": container, "rig": rig, "driver": driver, "player": player}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_front_arc_gets_the_grille() -> void:
	var f := _fixture(Vector2(400, 0))  # dead ahead of the +x heading
	var intent: Dictionary = f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.RAM, "react: front arc -> RAM")
	t.check(float(intent.get("throttle", 0.0)) >= 1.0, "react: the hunt is full gas")
	t.check(bool(intent.get("boost", false)), "react: nitro backs the grille")
	_done(f)

func test_flank_gets_the_tail() -> void:
	var f := _fixture(Vector2(0, 300))  # hard on the right flank (y-down)
	var intent: Dictionary = f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.JACKKNIFE, "react: flank -> JACKKNIFE")
	t.check(float(intent.get("steer", 0.0)) < 0.0,
		"react: steers AWAY from the player's side (tail whips into them)")
	_done(f)

func test_far_player_is_ignored() -> void:
	var f := _fixture(Vector2(2000, 0))  # well outside APPROACH_TRIGGER
	f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.LOOP, "loop: distance keeps the peace")
	_done(f)

func test_jackknife_hands_off_via_parting_shot() -> void:
	var f := _fixture(Vector2(0, 300))
	f.driver.get_intent(f.rig, 1.0 / 60.0)  # -> JACKKNIFE
	f.driver.get_intent(f.rig, DriverScript.JACKKNIFE_TIME + 0.1)
	t.check(f.driver._mode == DriverScript.Mode.PARTING, "flow: jackknife expires into PARTING")
	f.driver.get_intent(f.rig, DriverScript.PARTING_SHOT_TIME + 0.1)
	t.check(f.driver._mode == DriverScript.Mode.LOOP, "flow: parting shot resumes the loop")
	t.check(f.driver._reengage > 0.0, "flow: re-engage grace armed — waves, not a smother")
	_done(f)

## The jackknife is a whip-crack sway, not a U-turn: wind-up away from the
## player, counter-snap back across, then hands straight for the settle.
func test_jackknife_sways_out_back_and_straight() -> void:
	var f := _fixture(Vector2(0, 300))  # right flank -> wind-up steer is negative
	var intent: Dictionary = f.driver.get_intent(f.rig, 1.0 / 60.0)
	var wind_up: float = float(intent.get("steer", 0.0))
	t.check(wind_up < 0.0, "sway: wind-up loads the tail (away side)")
	intent = f.driver.get_intent(f.rig, DriverScript.JACKKNIFE_TIME * 0.5)
	t.check(float(intent.get("steer", 0.0)) > 0.0, "sway: the crack snaps back across")
	intent = f.driver.get_intent(f.rig, DriverScript.JACKKNIFE_TIME * 0.35)
	t.check(f.driver._mode == DriverScript.Mode.JACKKNIFE
		and is_zero_approx(float(intent.get("steer", 0.0))),
		"sway: the settle runs hands-straight — no U-turn")
	_done(f)

## The tail is an occasion: it demands momentum AND a cooled-down rig —
## a glued-on player can't bait a dog-chases-tail spin cycle.
func test_jackknife_needs_momentum_and_cooldown() -> void:
	var f := _fixture(Vector2(0, 300))
	f.rig.fake_vel = Vector2(100, 0)  # crawling: no swing without momentum
	f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.LOOP,
		"tail gate: a slow rig holds course and accelerates")
	f.rig.fake_vel = Vector2(400, 0)  # back up to speed
	f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.JACKKNIFE, "tail gate: momentum earns the swing")
	t.check(f.driver._jk_cd > 0.0, "tail gate: the swing arms its cooldown")
	# Ride the maneuver out with the player still glued on...
	f.driver.get_intent(f.rig, DriverScript.JACKKNIFE_TIME + 0.1)   # -> PARTING
	f.driver.get_intent(f.rig, DriverScript.PARTING_SHOT_TIME + 0.1)  # -> LOOP
	f.driver._reengage = 0.0  # even past the re-engage grace...
	f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.LOOP,
		"tail gate: the cooldown holds the second swing — resume course first")
	f.driver._jk_cd = 0.0  # cooled down and still at speed:
	f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.JACKKNIFE, "tail gate: earned again")
	_done(f)

func _phase2_fixture(player_at: Vector2) -> Dictionary:
	var f := _fixture(player_at)
	var boss := FakeBoss.new()
	boss.name = "BossController"
	f.rig.add_child(boss)
	return f

## Phase 2: the wind-up gates the commit; the committed charge forces
## velocity dead-straight and bypasses the controller (is_forcing); an
## open-air whiff squares back up.
func test_charge_commits_after_windup() -> void:
	var f := _phase2_fixture(Vector2(600, 0))  # aligned dead ahead
	var intent: Dictionary = f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(f.driver._mode == DriverScript.Mode.LINE_UP, "ph2: squares up first")
	t.check(float(intent.get("throttle", 0.0)) > 0.0, "ph2: line-up keeps rolling")
	intent = f.driver.get_intent(f.rig, DriverScript.CHARGE_WINDUP + 0.1)
	t.check(f.driver._mode == DriverScript.Mode.CHARGE, "ph2: wind-up expires into the commit")
	t.check(f.rig.velocity.x > DriverScript.CHARGE_SPEED * 0.9,
		"ph2: forced velocity down the committed line")
	t.check(f.driver.is_forcing(), "ph2: the controller is bypassed mid-charge")
	t.check(intent.is_empty(), "ph2: no intent while forcing")
	intent = f.driver.get_intent(f.rig, DriverScript.CHARGE_TIME + 0.1)
	t.check(f.driver._mode == DriverScript.Mode.LINE_UP, "ph2: an open-air whiff squares up again")
	t.check(not f.driver.is_forcing(), "ph2: forcing ends with the charge")
	_done(f)

## The outcome classifiers, pure: a car with apply_impact is a strike, a
## static is scenery (the bait), and the self-stun sits the boss down.
func test_charge_outcomes() -> void:
	var f := _phase2_fixture(Vector2(600, 0))
	var car = VehicleScene.instantiate()
	f.container.add_child(car)
	var wall := StaticBody2D.new()
	f.container.add_child(wall)
	t.check(f.driver._charge_hit_car([wall, car]) == car, "outcome: the car is the victim")
	t.check(f.driver._charge_hit_car([wall]) == null, "outcome: scenery is not a victim")
	t.check(f.driver._charge_hit_scenery([wall]), "outcome: a wall reads as scenery")
	t.check(not f.driver._charge_hit_scenery([car]), "outcome: a car alone is no bait")
	var hp_before: float = car.get_node("Health").hp
	f.driver._self_stun(car)
	t.check(car.get_node("Health").hp < hp_before, "whiff: the wall bill landed")
	t.check(car.get_node("Status").is_stunned(), "whiff: sitting-duck stun landed")
	_done(f)

## The connect buys a back-off lap on the ring, then squares up again.
func test_retreat_laps_then_lines_up() -> void:
	var f := _phase2_fixture(Vector2(600, 0))
	f.driver._mode = DriverScript.Mode.RETREAT
	f.driver._timer = 1.0
	var intent: Dictionary = f.driver.get_intent(f.rig, 1.0 / 60.0)
	t.check(is_equal_approx(float(intent.get("throttle", 0.0)), DriverScript.RETREAT_THROTTLE),
		"retreat: full gas on the ring")
	f.driver.get_intent(f.rig, 1.2)
	t.check(f.driver._mode == DriverScript.Mode.LINE_UP, "retreat: hands back to the line-up")
	_done(f)

func test_pinned_rig_recovers_in_reverse() -> void:
	var f := _fixture(Vector2(2000, 0))
	f.rig.fake_vel = Vector2.ZERO  # pinned: real displacement reads nothing
	var intent: Dictionary = {}
	for i in 4:
		intent = f.driver.get_intent(f.rig, 0.5)
	t.check(f.driver._mode == DriverScript.Mode.RECOVER, "stuck: trip -> RECOVER")
	t.check(float(intent.get("throttle", 0.0)) < 0.0, "stuck: committed full reverse")
	f.rig.fake_vel = Vector2(200, 0)  # the reverse-out found daylight
	for i in 5:
		intent = f.driver.get_intent(f.rig, 0.5)
	t.check(f.driver._mode == DriverScript.Mode.LOOP, "stuck: recovery rejoins the loop")
	_done(f)
