extends RefCounted
## The pace keeper: Route 666's level-side speed floor. Pure floor math, the
## which-way-is-out rule, the cars it leaves alone (airborne, wrecked), and
## the real thing — a booted run with a pillar dropped dead ahead of the
## player, who must come off it and carry on north without touching a key.

const KeeperScript := preload("res://levels/chase/pace_keeper.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")

var t

class FakeController:
	var max_speed := 500.0

class FakeCar extends Node2D:
	var velocity := Vector2.ZERO
	var height := 0.0
	var hp := 100.0
	var ctrl = FakeController.new()
	func get_controller():
		return ctrl
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

## [container, car, keeper] — the keeper's own tick is parked; tests step it.
func _rig() -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var car := FakeCar.new()
	container.add_child(car)
	var keeper = KeeperScript.new()
	keeper.target = car
	container.add_child(keeper)
	keeper.set_physics_process(false)
	return [container, car, keeper]

func _done(container: Node) -> void:
	t.root.remove_child(container)
	container.free()

func test_floor_math() -> void:
	const DT := 1.0 / 60.0
	var pushed: Vector2 = KeeperScript.keep(Vector2(40.0, -100.0), 225.0, 1400.0, DT)
	t.check(is_equal_approx(-pushed.y, 100.0 + 1400.0 * DT), "keeper: under the floor gets a shove north")
	t.check(is_equal_approx(pushed.x, 40.0), "keeper: the shove never touches sideways travel")
	var capped: Vector2 = KeeperScript.keep(Vector2(0.0, -220.0), 225.0, 1400.0, DT)
	t.check(is_equal_approx(-capped.y, 225.0), "keeper: the shove stops AT the floor, never past it")
	var fast := Vector2(10.0, -400.0)
	t.check(KeeperScript.keep(fast, 225.0, 1400.0, DT).is_equal_approx(fast),
		"keeper: a car over the floor is left alone")
	var backing: Vector2 = KeeperScript.keep(Vector2(0.0, 150.0), 225.0, 1400.0, DT)
	t.check(backing.y < 150.0, "keeper: travel back toward the pack is pushed the other way")
	# A shove, not a teleport: one tick stays under the bounce threshold
	# (bounce_min_speed 100), so a pinned car never rattles or spams crash audio.
	t.check(KeeperScript.KEEP_PUSH * DT < 100.0,
		"keeper: one tick of shove stays under the bounce threshold (%.1f px/s)" % (KeeperScript.KEEP_PUSH * DT))
	t.check(KeeperScript.KEEP_FRAC < SpeedBand.FLOOR_FRAC,
		"keeper: the physics floor sits under the pedal's floor — they never fight")

func test_which_way_is_out() -> void:
	t.check(is_equal_approx(KeeperScript.free_side(30.0, 0.0), -1.0), "keeper: obstacle to the right = lean left")
	t.check(is_equal_approx(KeeperScript.free_side(-30.0, 0.0), 1.0), "keeper: obstacle to the left = lean right")
	t.check(is_equal_approx(KeeperScript.free_side(0.0, 200.0), -1.0),
		"keeper: dead-center hit right of the centerline = lean back toward the wide side")
	t.check(is_equal_approx(KeeperScript.free_side(0.0, -200.0), 1.0),
		"keeper: dead-center hit left of the centerline = lean right")
	t.check(is_equal_approx(KeeperScript.free_side(30.0, 200.0), -1.0), "keeper: the obstacle outranks the road")
	t.check(absf(KeeperScript.free_side(0.0, 0.0)) == 1.0, "keeper: a perfect tie still picks a side")

func test_floor_from_rest_on_open_road() -> void:
	var r := _rig()
	var car: FakeCar = r[1]
	var keeper = r[2]
	var want: float = keeper.floor_speed()
	t.check(is_equal_approx(want, 500.0 * KeeperScript.KEEP_FRAC), "keeper: the floor is priced off the car's top")
	const DT := 1.0 / 60.0
	var ticks := 0
	while -car.velocity.y < want - 0.5 and ticks < 120:
		keeper._physics_process(DT)
		car.position += car.velocity * DT
		ticks += 1
	t.check(ticks < 30, "keeper: a dead stop is back at the floor in under half a second (%d ticks)" % ticks)
	t.check(not keeper.is_pinned(), "keeper: a car making progress is never called pinned")
	car.velocity = Vector2(0.0, -450.0)
	keeper._physics_process(DT)
	t.check(is_equal_approx(car.velocity.y, -450.0), "keeper: no push above the floor")
	_done(r[0])

func test_leaves_the_air_and_the_wrecked_alone() -> void:
	var r := _rig()
	var car: FakeCar = r[1]
	var keeper = r[2]
	car.height = 40.0
	keeper._physics_process(0.016)
	t.check(car.velocity.is_equal_approx(Vector2.ZERO), "keeper: airborne cars keep their arc")
	car.height = 0.0
	car.hp = 0.0
	keeper._physics_process(0.016)
	t.check(car.velocity.is_equal_approx(Vector2.ZERO), "keeper: a wreck stays where it died")
	car.hp = 100.0
	keeper.enabled = false
	keeper._physics_process(0.016)
	t.check(car.velocity.is_equal_approx(Vector2.ZERO), "keeper: stands down when the run is over")
	_done(r[0])

func test_pinned_car_leans_out() -> void:
	var r := _rig()
	var car: FakeCar = r[1]   # never moved: the nose is buried in something
	var keeper = r[2]
	const DT := 1.0 / 60.0
	var pin_ticks := int(ceil(KeeperScript.PIN_TIME / DT))
	for i in pin_ticks - 3:
		keeper._physics_process(DT)
		car.velocity.y = 0.0   # the slide ate the shove
	t.check(not keeper.is_pinned(), "keeper: a brief bump is not a pin")
	t.check(is_equal_approx(car.velocity.x, 0.0), "keeper: no lean before the pin clock runs out")
	for i in 30:
		keeper._physics_process(DT)
		car.velocity.y = 0.0
	t.check(keeper.is_pinned(), "keeper: buried past the pin clock = pinned")
	t.check(KeeperScript.PIN_TIME <= 0.25, "keeper: the pin clock is quick — the pack is right there")
	t.check(absf(car.velocity.x) > 50.0, "keeper: pinned cars lean sideways (vx %d)" % int(car.velocity.x))
	t.check(absf(car.velocity.x) <= KeeperScript.NUDGE_MAX + 0.01, "keeper: the lean has a ceiling")
	_done(r[0])

## The real thing: a pillar dead ahead of the player at the green flag, no
## keys held. The car must come off it and carry on north.
func test_player_comes_off_a_pillar_hands_off() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	if gs != null:
		gs.lives = 3
		gs.devgod = false
	var scene = load("res://levels/chase/buzzard_run.tscn").instantiate()
	scene.catch_enabled = false  # this test is about the pillar, not the pack
	t.root.add_child(scene)
	t.current_scene = scene
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	var director = scene.get_node(^"ChaseDirector")
	wall.set_physics_process(false)  # this test is about the pillar, not the pack
	director.frozen = true
	t.check(scene.get_node_or_null(^"PaceKeeper") != null, "keeper: the run hosts a pace keeper")
	var pillar := StaticBody2D.new()
	pillar.collision_layer = 2  # wall
	pillar.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120.0, 60.0)
	col.shape = shape
	pillar.add_child(col)
	pillar.position = player.global_position + Vector2(0.0, -260.0)
	scene.add_child(pillar)
	var pillar_y: float = pillar.position.y
	var start_x: float = player.global_position.x
	var cleared := false
	var frames := 0
	for i in 300:  # 5 seconds
		await t.physics_frame
		frames += 1
		if player.global_position.y < pillar_y - 120.0:
			cleared = true
			break
	t.check(cleared, "keeper: the car comes off a dead-ahead pillar on its own (y %d, pillar %d)"
		% [int(player.global_position.y), int(pillar_y)])
	# Hands off, from the green flag's cruise: reach it, bury the nose, lean
	# out, pull away. The pack's mercy stretch is sized around this number.
	t.check(frames < 210, "keeper: a head-on pillar costs about two seconds, not the run (%d frames)" % frames)
	t.check(absf(player.global_position.x - start_x) > 40.0,
		"keeper: it got out sideways (dx %d)" % int(player.global_position.x - start_x))
	t.check(player.get_hp() > 0.0, "keeper: a pillar costs ground, not the car")
	t.paused = false
	if gs != null:
		gs.lives = 3
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()
