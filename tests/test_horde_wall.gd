extends RefCounted
## The horde wall's pressure math (advance, clamp, kill, shield, reset), the
## end screen's chase-mode group-win suppression, and the full rolling-start
## respawn loop through a booted buzzard_run scene.

const WallScript := preload("res://levels/chase/horde_wall.gd")
const HealthScript := preload("res://vehicles/health.gd")

var t

class FakeController:
	var max_speed := 500.0

class FakeCar extends Node2D:
	var velocity := Vector2.ZERO
	var hp := 0.0  # only the end-screen fixtures read it: a wreck by default
	var ctrl = FakeController.new()
	func get_controller():
		return ctrl
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

func test_wall_pressure_math() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var player := Node2D.new()
	player.position = Vector2(0, -1000)
	var health = HealthScript.new()
	health.name = "Health"
	player.add_child(health)
	container.add_child(player)
	var wall = WallScript.new()
	wall.target = player
	wall.pace_frac = 0.8
	var trailing: float = WallScript.MAX_GAP - 60.0
	wall.front_y = player.position.y + trailing
	container.add_child(wall)
	# A bare fixture has no controller: the pack prices itself off the fallback.
	var top: float = wall.base_top()
	t.check(is_equal_approx(top, WallScript.FALLBACK_TOP), "wall: bare targets ride the fallback top")
	# Rubberband: past the leash the surge stacks on the phase pace.
	var cruise: float = top * 0.8
	var surged: float = WallScript.pack_speed(top, 0.8, trailing)
	t.check(surged > cruise, "wall: trailing past the leash surges (%d > %d)" % [int(surged), int(cruise)])
	wall._physics_process(0.5)
	t.check(is_equal_approx(wall.gap(), trailing - surged * 0.5),
		"wall: surges when trailing (gap %d)" % int(wall.gap()))
	# At the leash the surge is zero — pure phase cruise.
	wall.front_y = player.position.y + WallScript.LEASH_GAP
	wall._physics_process(0.05)
	t.check(is_equal_approx(wall.gap(), WallScript.LEASH_GAP - cruise * 0.05),
		"wall: eases to cruise inside the leash")
	# From the max clamp the pack beats the chased car's honest top at the
	# slowest pace on the books — a boost only ever buys a few seconds.
	wall.front_y = player.position.y + WallScript.MAX_GAP
	var gap_before: float = wall.gap()
	wall._physics_process(0.5)
	t.check((gap_before - wall.gap()) / 0.5 > top,
		"wall: nothing outruns the horde globally (closing %d/s)" % int((gap_before - wall.gap()) / 0.5))
	player.position.y = -30000.0
	wall._physics_process(0.016)
	t.check(is_equal_approx(wall.gap(), WallScript.MAX_GAP), "wall: clamps to MAX_GAP when outrun")
	t.check(health.hp > 0.0, "wall: distant player untouched")
	wall.front_y = player.position.y + WallScript.KILL_MARGIN - 10.0
	wall._physics_process(0.016)
	t.check(health.hp <= 0.0, "wall: contact takes the life")
	health.hp = 100.0
	health.invulnerable = true
	wall.front_y = player.position.y + 10.0
	wall._physics_process(0.016)
	t.check(health.hp == 100.0, "wall: respawn shield holds the line")
	health.invulnerable = false
	wall.front_y = player.position.y + 100.0
	wall.reset_behind(player.position.y + WallScript.RESPAWN_GAP)
	t.check(is_equal_approx(wall.gap(), WallScript.RESPAWN_GAP), "wall: death reset regroups it")
	wall.reset_behind(player.position.y + 500.0)
	t.check(is_equal_approx(wall.gap(), WallScript.RESPAWN_GAP), "wall: reset never pulls it closer")
	t.root.remove_child(container)
	container.free()

## The squeeze is priced in fractions of the chased car's top: the slowest and
## fastest rides on the roster get the same pack, scaled — and the same
## flat-out resting gap.
func test_pack_is_priced_against_the_car() -> void:
	const SLOW := 453.0  # Hubcap
	const FAST := 640.0  # Cyclone
	for gap_px in [100.0, WallScript.LEASH_GAP, WallScript.LEASH_GAP + 300.0, WallScript.MAX_GAP]:
		var slow: float = WallScript.pack_speed(SLOW, 0.9, gap_px) / SLOW
		var fast: float = WallScript.pack_speed(FAST, 0.9, gap_px) / FAST
		t.check(is_equal_approx(slow, fast),
			"wall: same squeeze for every ride at gap %d (%.3f of top)" % [int(gap_px), slow])
	# Flat out (speed == top) the gap rests where the surge eats the pace deficit.
	var rest: float = WallScript.LEASH_GAP + (1.0 - 0.9) / WallScript.SURGE_PER_PX
	t.check(is_equal_approx(WallScript.pack_speed(SLOW, 0.9, rest), SLOW)
		and is_equal_approx(WallScript.pack_speed(FAST, 0.9, rest), FAST),
		"wall: the flat-out resting gap is the same for every car (%d px)" % int(rest))
	# A fixture with a controller prices the pack off ITS top, read live.
	var container := Node2D.new()
	t.root.add_child(container)
	var car := FakeCar.new()
	car.ctrl.max_speed = FAST
	container.add_child(car)
	var wall = WallScript.new()
	wall.target = car
	container.add_child(wall)
	t.check(is_equal_approx(wall.base_top(), FAST), "wall: reads the chased car's own top")
	car.ctrl.max_speed = SLOW
	t.check(is_equal_approx(wall.base_top(), SLOW), "wall: the read is live, never cached")
	t.root.remove_child(container)
	container.free()

## Drives a fixture car north at a fixed fraction of its top and steps the
## wall beside it; returns the gap after `seconds`.
func _chase(top: float, pace: float, speed_frac: float, start_gap: float, seconds: float) -> float:
	var container := Node2D.new()
	t.root.add_child(container)
	var car := FakeCar.new()
	car.ctrl.max_speed = top
	car.velocity = Vector2(0.0, -top * speed_frac)
	container.add_child(car)
	var wall = WallScript.new()
	wall.target = car
	wall.pace_frac = pace
	wall.front_y = car.position.y + start_gap
	container.add_child(wall)
	wall.set_physics_process(false)  # the test owns the clock
	# Wall first, then the car: the gap read after each full tick is the gap
	# the wall prices its NEXT step on (no half-step measuring artifact).
	const DT := 1.0 / 60.0
	for i in int(seconds / DT):
		wall._physics_process(DT)
		car.position += car.velocity * DT
	var out: float = wall.gap()
	t.root.remove_child(container)
	container.free()
	return out

## THE GAP IS THE HEALTH BAR: clean flat-out driving parks the dust crest at
## the same resting gap for every ride — on screen — and each beat of the
## arc tightens it.
func test_flat_out_gap_rests_on_screen_for_every_car() -> void:
	# View behind the player at the pinned chase framing: half the 720px play
	# square at zoom 0.55, plus the camera's 140px northward lead spent.
	const VIEW_BEHIND := 720.0 / 0.55 / 2.0 - 140.0
	for top in [453.0, 484.0, 640.0]:
		for pace in [0.80, 0.90, 1.00]:
			var want: float = WallScript.LEASH_GAP + (1.0 - pace) / WallScript.SURGE_PER_PX
			var got := _chase(top, pace, 1.0, WallScript.START_GAP, 30.0)
			t.check(absf(got - want) < 3.0,
				"wall: top %d pace %.2f rests at %d px (got %d)" % [int(top), pace, int(want), int(got)])
			t.check(want < VIEW_BEHIND,
				"wall: the resting crest is on screen at pace %.2f (%d < %d)" % [pace, int(want), int(VIEW_BEHIND)])
			t.check(want > WallScript.DANGER_GAP,
				"wall: clean driving never rests in the danger zone (pace %.2f)" % pace)

## Mistakes cost ground, and the last stretch always takes a beat.
func test_lifting_costs_gap_and_mercy_stretches_the_close() -> void:
	const TOP := 484.0
	var rest: float = WallScript.LEASH_GAP + (1.0 - 0.9) / WallScript.SURGE_PER_PX
	var lifted := _chase(TOP, 0.9, 0.8, rest, 1.0)
	t.check(lifted < rest - 30.0, "wall: a one-second lift visibly costs gap (%d -> %d)" % [int(rest), int(lifted)])
	# A car pinned dead on a pillar at the mercy line: the pack may close no
	# faster than MERCY_CLOSE, so contact is at least two seconds away.
	var span: float = WallScript.MERCY_GAP - WallScript.KILL_MARGIN
	var floor_s: float = span / WallScript.MERCY_CLOSE
	t.check(floor_s >= 2.0, "wall: the mercy stretch is at least two seconds (%.1f)" % floor_s)
	var pinned := _chase(TOP, 1.0, 0.0, WallScript.MERCY_GAP - 1.0, floor_s - 0.2)
	t.check(pinned > WallScript.KILL_MARGIN,
		"wall: a pinned car still has its beat to escape (gap %d)" % int(pinned))
	t.check(is_equal_approx(WallScript.mercy_cap(900.0, WallScript.MERCY_GAP + 1.0, 0.0), 900.0),
		"wall: no mercy outside the mercy gap")
	t.check(is_equal_approx(WallScript.mercy_cap(900.0, 100.0, 250.0), 250.0 + WallScript.MERCY_CLOSE),
		"wall: inside it, closing is capped over the car's own speed")
	t.check(is_equal_approx(WallScript.mercy_cap(200.0, 100.0, 400.0), 200.0),
		"wall: mercy never speeds the pack up")

func test_pressure_meter_and_danger_line() -> void:
	t.check(is_equal_approx(WallScript.pressure_at(WallScript.MAX_GAP), 0.0), "wall: farthest = no pressure")
	t.check(is_equal_approx(WallScript.pressure_at(WallScript.KILL_MARGIN), 1.0), "wall: contact = full pressure")
	t.check(is_equal_approx(WallScript.pressure_at(-40.0), 1.0), "wall: pressure clamps past contact")
	t.check(WallScript.pressure_at(300.0) > WallScript.pressure_at(500.0), "wall: closer = more pressure")
	t.check(WallScript.DANGER_GAP > WallScript.KILL_MARGIN and WallScript.DANGER_GAP < WallScript.LEASH_GAP,
		"wall: the danger zone sits between contact and the leash")
	t.check(WallScript.START_GAP <= WallScript.MAX_GAP, "wall: the green flag drops inside the clamp")

func test_end_screen_suppression() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var es = load("res://ui/end_screen.tscn").instantiate()
	es.suppress_group_win = true
	container.add_child(es)
	var buzzard := Node.new()
	buzzard.add_to_group(&"enemies")
	container.add_child(buzzard)
	es._process(0.016)  # latches _seen_enemies
	container.remove_child(buzzard)
	buzzard.free()
	es._process(0.016)  # arena-style win would fire here
	t.check(not es.visible, "end: wiped wave is not a win in chase mode")
	t.check(not t.paused, "end: world keeps running")
	es._show(true)
	t.check(es.visible, "end: the host's timed win still lands")
	t.paused = false
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

## Nobody dies for good on Route 666: with suppress_loss set, a dead player on
## an empty lives tank (stale state from anywhere) can't trip the loss card —
## the host owns that call, and can still make it.
func test_end_screen_loss_suppression() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	if gs == null:
		return
	var lives_were: int = gs.lives
	gs.lives = 0
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var player := FakeCar.new()
	player.add_to_group(&"player")
	container.add_child(player)
	var es = load("res://ui/end_screen.tscn").instantiate()
	es.suppress_group_win = true
	es.suppress_loss = true
	container.add_child(es)
	es._process(0.016)
	t.check(not es.visible, "end: a wreck is not a loss card in chase mode")
	t.check(not t.paused, "end: world keeps running")
	es.suppress_loss = false
	es._process(0.016)
	t.check(es.visible, "end: everywhere else a dead player on an empty tank still loses")
	t.paused = false
	gs.lives = lives_were
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_group_win_still_default_elsewhere() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	t.current_scene = container
	var es = load("res://ui/end_screen.tscn").instantiate()
	container.add_child(es)
	var foe := Node.new()
	foe.add_to_group(&"enemies")
	container.add_child(foe)
	es._process(0.016)
	container.remove_child(foe)
	foe.free()
	es._process(0.016)
	t.check(es.visible, "end: arenas keep the cleared-field win")
	t.paused = false
	t.current_scene = null
	t.root.remove_child(container)
	container.free()

func test_rolling_start_respawn() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	t.check(gs != null, "chase: GameState autoload present")
	if gs == null:
		return
	gs.lives = 3
	gs.devgod = false
	var scene = load("res://levels/chase/buzzard_run.tscn").instantiate()
	t.root.add_child(scene)
	t.current_scene = scene
	for i in 5:
		await t.physics_frame
	var player = scene.get_node(^"Vehicle")
	var driver = player.get_node(^"Driver")
	var intent: Dictionary = driver.get_intent(player, 0.016)
	t.check(intent["throttle"] > 0.0, "chase: hands off under cruise keeps the gas on")
	var health = player.get_node(^"Health")
	health.kill()
	var respawned := false
	for i in 200:
		await t.physics_frame
		if health.hp > 0.0:
			respawned = true
			break
	t.check(respawned, "chase: lives loop rolls a respawn")
	t.check(gs.lives == 2, "chase: the death cost a life")
	t.check(player.velocity.y < -200.0, "chase: rolling start — already moving north (vy %d)" % int(player.velocity.y))
	var gap: float = scene.wall_gap()
	t.check(gap >= WallScript.RESPAWN_GAP - 50.0 and gap <= WallScript.MAX_GAP + 1.0,
		"chase: wall regrouped behind the respawn (gap %d)" % int(gap))
	scene.clock = scene.RUN_SECONDS - 0.05
	var won := false
	for i in 30:
		await t.physics_frame
		if scene._won:
			won = true
			break
	t.check(won, "chase: the clock calls the win")
	t.paused = false
	gs.lives = 3
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()
