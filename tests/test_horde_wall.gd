extends RefCounted
## The horde wall's pressure math (pace, surge, clamp, mercy, the catch it
## reports but never enforces) and the end screen's chase-mode suppressions.
## The run's end-to-end flow lives in test_chase_flow.gd.

const WallScript := preload("res://levels/chase/horde_wall.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const HealthScript := preload("res://vehicles/health.gd")

var t

class FakeController:
	var max_speed := 500.0

## A course whose centreline drifts `slope` px of x per px of distance.
class FakeCourse:
	var slope := 0.0
	func sample(d: float) -> Dictionary:
		return {"x": slope * d, "half_w": 360.0}

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
	t.check(not wall.caught(), "wall: a distant car is not caught")
	# The catch is REPORTED, never enforced: the wall doesn't touch Health —
	# what a catch costs is the host's call (a robbery, not a life).
	var hp_before: float = health.hp
	wall.front_y = player.position.y + WallScript.CATCH_MARGIN - 10.0
	wall._physics_process(0.016)
	t.check(wall.caught(), "wall: inside the catch margin the swarm has the car")
	t.check(health.hp == hp_before, "wall: contact never touches Health")
	wall.front_y = player.position.y + WallScript.CATCH_MARGIN + 30.0
	t.check(not wall.caught(), "wall: a hair outside the margin is still a close call")
	# Once the run is lost the host drops the mercy: the pack rolls over the car.
	wall.front_y = player.position.y + 100.0
	wall._physics_process(0.1)
	var merciful: float = 100.0 - wall.gap()
	wall.front_y = player.position.y + 100.0
	wall.no_mercy = true
	wall._physics_process(0.1)
	var merciless: float = 100.0 - wall.gap()
	t.check(merciless > merciful * 3.0,
		"wall: no_mercy swallows the car (%d px vs %d px in a tenth)" % [int(merciless), int(merciful)])
	t.check(wall.get_node_or_null(^"Backstop") == null, "wall: nothing blocks the road — the pedal has no reverse")
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
	t.check(is_equal_approx(SpeedBand.road_top(null), SpeedBand.FALLBACK_TOP),
		"band: no car = the fallback top")
	t.check(is_equal_approx(SpeedBand.road_top(null, 300.0), 300.0), "band: the fallback is the caller's to choose")
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
	# A car crawling at the mercy line: the pack may close no faster than
	# MERCY_CLOSE. Smash-and-pass means nothing on the road stops a car any
	# more, so the stretch only has to cover a bad smash (a derelict costs a
	# quarter of the momentum) — about three seconds.
	var span: float = WallScript.MERCY_GAP - WallScript.CATCH_MARGIN
	var floor_s: float = span / WallScript.MERCY_CLOSE
	t.check(floor_s >= 3.0, "wall: the mercy stretch covers a bad smash (%.1fs)" % floor_s)
	t.check(WallScript.MERCY_GAP < WallScript.LEASH_GAP,
		"wall: clean driving never rests inside the mercy zone")
	var pinned := _chase(TOP, 1.0, 0.0, WallScript.MERCY_GAP - 1.0, floor_s - 0.2)
	t.check(pinned > WallScript.CATCH_MARGIN,
		"wall: a pinned car still has its beat to escape (gap %d)" % int(pinned))
	t.check(is_equal_approx(WallScript.mercy_cap(900.0, WallScript.MERCY_GAP + 1.0, 0.0), 900.0),
		"wall: no mercy outside the mercy gap")
	t.check(is_equal_approx(WallScript.mercy_cap(900.0, 100.0, 250.0), 250.0 + WallScript.MERCY_CLOSE),
		"wall: inside it, closing is capped over the car's own speed")
	t.check(is_equal_approx(WallScript.mercy_cap(200.0, 100.0, 400.0), 200.0),
		"wall: mercy never speeds the pack up")

## Easier tiers slow the whole pack; HARD runs the arc exactly as authored.
func test_difficulty_slows_the_pack() -> void:
	const Difficulty := preload("res://game/difficulty.gd")
	var container := Node2D.new()
	t.root.add_child(container)
	var car := FakeCar.new()
	container.add_child(car)
	var wall = WallScript.new()
	wall.target = car
	wall.pace_frac = 0.9
	container.add_child(wall)
	wall.set_physics_process(false)
	Difficulty.tier = Difficulty.Tier.HARD
	t.check(is_equal_approx(wall.tier_pace(), 0.9), "tier: HARD runs the authored pace")
	Difficulty.tier = Difficulty.Tier.MEDIUM
	var medium: float = wall.tier_pace()
	Difficulty.tier = Difficulty.Tier.EASY
	var easy: float = wall.tier_pace()
	t.check(easy < medium and medium < 0.9, "tier: each easier tier slows the pack (%.3f < %.3f < 0.900)" % [easy, medium])
	# On EASY even the last mile leaves air: flat out the driver GAINS ground.
	wall.pace_frac = 1.0
	t.check(wall.tier_pace() < 1.0, "tier: EASY's last mile runs under the car's own top (%.2f)" % wall.tier_pace())
	wall.front_y = car.position.y + 400.0
	wall._physics_process(0.1)
	var easy_gap: float = wall.gap()
	Difficulty.tier = Difficulty.Tier.HARD
	wall.front_y = car.position.y + 400.0
	wall._physics_process(0.1)
	t.check(easy_gap > wall.gap(), "tier: the same tenth of a second closes less ground on EASY")
	Difficulty.tier = Difficulty.Tier.HARD  # statics leak across suites
	t.root.remove_child(container)
	container.free()

## The pack's voice: gain rides the gap, the horn sounds on the edge only.
func test_the_pack_has_a_voice() -> void:
	t.check(is_equal_approx(WallScript.roar_gain(0.0), WallScript.ROAR_FLOOR), "voice: never silent, even at its farthest")
	t.check(is_equal_approx(WallScript.roar_gain(1.0), 1.0), "voice: full at contact")
	t.check(WallScript.roar_gain(0.7) > WallScript.roar_gain(0.3), "voice: closer is louder")
	t.check(is_equal_approx(WallScript.roar_gain(7.0), 1.0), "voice: the gain clamps")
	t.check(WallScript.horn_due(true, false, 0.0), "voice: the horn sounds crossing INTO danger")
	t.check(not WallScript.horn_due(true, true, 0.0), "voice: not while sitting in it")
	t.check(not WallScript.horn_due(false, true, 0.0), "voice: not on the way out")
	t.check(not WallScript.horn_due(true, false, 2.0), "voice: and never inside its cooldown")
	t.check(WallScript.HORN_COOLDOWN >= 4.0, "voice: hovering on the line can't machine-gun the horn")

## The brink: told to halt at a line, the pack brakes over HALT_BRAKE px,
## never crosses it, and stops dragging north after the escaping car; the
## riders lock up and the engines die.
func test_the_pack_halts_at_the_bank() -> void:
	t.check(is_equal_approx(WallScript.halt_speed(500.0, -1000.0, -1160.0, 320.0), 250.0),
		"halt: halfway into the braking ramp the pack runs at half speed")
	t.check(is_equal_approx(WallScript.halt_speed(500.0, -1000.0, -1320.0, 320.0), 500.0), "halt: outside the ramp, full speed")
	t.check(is_zero_approx(WallScript.halt_speed(500.0, -1000.0, -1000.0, 320.0)), "halt: on the line, stopped")
	t.check(is_equal_approx(WallScript.halt_speed(500.0, -1000.0, -1002.0, 320.0), WallScript.HALT_CREEP),
		"halt: a hair off the line it still creeps in — it arrives, never asymptotes")
	t.check(is_equal_approx(WallScript.halt_speed(500.0, -1000.0, INF, 320.0), 500.0), "halt: no line, no ramp")
	var container := Node2D.new()
	t.root.add_child(container)
	var player := Node2D.new()
	player.position = Vector2(0, -1000)
	container.add_child(player)
	var wall = WallScript.new()
	wall.target = player
	wall.pace_frac = 1.0
	wall.front_y = player.position.y + 700.0
	container.add_child(wall)
	var line: float = player.position.y + 300.0   # outside the mercy zone: a bare fixture has no speed
	wall.halt_at(line)
	var crossed := false
	for i in 120:
		wall._physics_process(0.05)   # six seconds: plenty to arrive
		if wall.front_y < line - 0.01:
			crossed = true
	t.check(not crossed, "halt: the crest never crosses the line")
	t.check(wall.halted and is_equal_approx(wall.front_y, line), "halt: it arrives and stops on it")
	t.check(wall.get_node(^"Deco").halted, "halt: the riders are told to lock up")
	t.check(not wall.caught(), "halt: a halted pack catches nobody")
	player.position.y -= 5000.0   # the car speeds off up the road
	wall._physics_process(0.05)
	t.check(is_equal_approx(wall.front_y, line), "halt: and the MAX_GAP drag no longer pulls it after the car")
	# From the wrong side of the line (the car has passed the bank when the
	# order comes): the crest snaps to the line, never past it.
	wall.halted = false
	wall.front_y = line - 300.0
	wall._physics_process(0.05)
	t.check(is_equal_approx(wall.front_y, line), "halt: a crest already past the line is held on it")
	# The lock-up: the riders settle within half a second and lay skids once.
	var deco = wall.get_node(^"Deco")
	deco.halted = true
	for i in 40:
		deco._process(0.016)
	var laid: int = deco.skid_marks.size()
	t.check(laid >= 11, "halt: every rider lays a skid (%d streaks)" % laid)
	var before: Array = []
	for r in deco._riders:
		before.append(r["node"].position)
	for i in 10:
		deco._process(0.016)
	var drift := 0.0
	for i in deco._riders.size():
		drift = maxf(drift, deco._riders[i]["node"].position.distance_to(before[i]))
	t.check(drift < 2.0, "halt: a locked-up rider barely moves (%.2f px in 10 ticks)" % drift)
	t.check(deco.skid_marks.size() == laid, "halt: the skids are laid once")
	t.root.remove_child(container)
	container.free()

## The curve tax: through a sweeper the pack, like the car, covers less
## north per second of speed — otherwise it quietly gains on every bend.
func test_curve_tax() -> void:
	t.check(is_equal_approx(WallScript.road_cos(null, 500.0), 1.0), "curve: no course = a straight")
	var course := FakeCourse.new()
	t.check(is_equal_approx(WallScript.road_cos(course, 500.0), 1.0), "curve: a straight pays nothing")
	course.slope = 0.33  # the course's own sweepers: 460px of x over 1400px
	var taxed: float = WallScript.road_cos(course, 500.0)
	t.check(taxed < 0.96 and taxed > 0.9, "curve: a sweeper costs the pack a few percent (%.3f)" % taxed)
	course.slope = -0.33
	t.check(is_equal_approx(WallScript.road_cos(course, 500.0), taxed), "curve: left or right, the same tax")

func test_pressure_meter_and_danger_line() -> void:
	t.check(is_equal_approx(WallScript.pressure_at(WallScript.MAX_GAP), 0.0), "wall: farthest = no pressure")
	t.check(is_equal_approx(WallScript.pressure_at(WallScript.CATCH_MARGIN), 1.0), "wall: contact = full pressure")
	t.check(is_equal_approx(WallScript.pressure_at(-40.0), 1.0), "wall: pressure clamps past contact")
	t.check(WallScript.pressure_at(300.0) > WallScript.pressure_at(500.0), "wall: closer = more pressure")
	t.check(WallScript.DANGER_GAP > WallScript.CATCH_MARGIN and WallScript.DANGER_GAP < WallScript.LEASH_GAP,
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
