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
	var fake_vel := Vector2(200, 0)
	func get_real_velocity() -> Vector2:
		return fake_vel

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
