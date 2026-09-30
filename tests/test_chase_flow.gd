extends RefCounted
## How a Route 666 run ENDS, through the booted scene: the rolling start, the
## clock's win, and the rule that replaced the lives loop — caught or wrecked
## is a ROBBERY, never a life, and the road goes on to the next stop.
## DISCIPLINE: Economy / GameState are process-global — every test restores
## them, releases the pause, and stops short of the scene change
## (auto_advance = false; nothing headless may reach SceneFlow.goto_scene).

const WallScript := preload("res://levels/chase/horde_wall.gd")
const Economy := preload("res://game/economy.gd")
const Robbery := preload("res://game/robbery.gd")
const SpeedBand := preload("res://levels/chase/speed_band.gd")
const CHASE_SCENE := "res://levels/chase/buzzard_run.tscn"

var t

func _init(runner) -> void:
	t = runner

## Boots the run with its own _process parked: tests drive the host's
## arbiter by hand, one deterministic call at a time.
func _boot() -> Node:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	gs.lives = 3
	gs.devgod = false
	gs.game_mode = &"campaign"
	var scene = load(CHASE_SCENE).instantiate()
	scene.auto_advance = false
	t.root.add_child(scene)
	t.current_scene = scene
	scene.set_process(false)
	for i in 3:
		await t.physics_frame
	return scene

func _close(scene: Node) -> void:
	t.paused = false
	var gs = t.root.get_node_or_null(^"/root/GameState")
	gs.lives = 3
	gs.devgod = false
	gs.game_mode = &"campaign"
	gs.level_index = 0
	gs.carry_ammo.clear()
	Economy.enabled = false
	Economy.god = false
	Economy.reset_run()
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()

## A seed whose first roll on a ten-wedge wheel lands on `index` — the same
## draw Robbery.spin() makes, searched rather than assumed.
func _seed_landing_on(index: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in range(1, 500):
		rng.seed = candidate
		if rng.randi_range(0, Robbery.WHEEL.size() - 1) == index:
			return candidate
	return 1

func _chase_index() -> int:
	var flow = t.root.get_node_or_null(^"/root/SceneFlow")
	for i in flow.CAMPAIGN.size():
		if String(flow.CAMPAIGN[i].scene) == CHASE_SCENE:
			return i
	return -1

func test_rolling_start_and_the_clock_win() -> void:
	var scene = await _boot()
	var gs = t.root.get_node(^"/root/GameState")
	var player = scene.get_node(^"Vehicle")
	t.check(player.velocity.y < -200.0,
		"chase: the green flag drops on a rolling start (vy %d)" % int(player.velocity.y))
	var gap: float = scene.wall_gap()
	t.check(gap > WallScript.LEASH_GAP and gap <= WallScript.MAX_GAP,
		"chase: the pack starts behind, inside the clamp (gap %d)" % int(gap))
	var es = scene._end_screen
	t.check(es != null and es.suppress_group_win and es.suppress_loss,
		"chase: the host owns both calls — the win and the loss")
	t.check(not player.weapon_lock_exempt,
		"chase: the player's bay keeps its 2s lock — no full-auto missiles")
	scene._process(0.016)
	t.check(scene.loss_cause() == &"" and not scene.is_jacked(), "chase: a clean run is still running")
	scene.finale_enabled = false   # the instant win: the show is test_chase_finale's
	scene.clock = scene.RUN_SECONDS - 0.01
	scene._process(0.016)
	t.check(scene._won, "chase: the clock calls the win")
	t.check(not scene.is_jacked() and gs.lives == 3, "chase: a win costs nothing")
	t.check(scene.get_node(^"ChaseDirector").frozen, "chase: the pack stands down at the line")
	_close(scene)

## Smash and pass: nothing on the road ever stops the car. A log under the
## nose dies on contact, the momentum mostly survives, the hull takes a bite.
func test_smash_and_pass() -> void:
	var scene = await _boot()
	scene.catch_enabled = false
	scene.get_node(^"ChaseDirector").frozen = true
	scene.get_node(^"HordeWall").set_physics_process(false)
	var player = scene.get_node(^"Vehicle")
	t.check(player.smash_and_pass, "smash: the chase car runs the smash-and-pass rule")
	for i in 135:  # let the level-start blink shield lapse: the bite must land
		await t.physics_frame
	t.check(not player.is_shielded(), "smash: the spawn shield is down")
	var log_block = load("res://environment/destructible_block.tscn").instantiate()
	log_block.size = Vector2(140, 26)
	log_block.max_hp = 15.0
	log_block.deco = &"log"
	log_block.position = player.global_position + Vector2(0.0, -220.0)
	scene.add_child(log_block)
	var hp_before: float = player.get_hp()
	var funds_before: int = Economy.funds
	var slowest := INF
	var passed := false
	for i in 90:  # 1.5s: more than enough road for a 220px approach
		await t.physics_frame
		slowest = minf(slowest, -player.velocity.y)
		if player.global_position.y < log_block.position.y - 60.0:
			passed = true
			break
	t.check(passed, "smash: the car is through and past the log (y %d vs %d)" % [int(player.global_position.y), int(log_block.position.y)])
	t.check(log_block.get_node(^"Health").hp <= 0.0, "smash: the log died on contact")
	var floor_speed: float = player.get_controller().max_speed * SpeedBand.FLOOR_FRAC
	t.check(slowest > floor_speed * 0.8,
		"smash: the car never stopped — slowest %d px/s against a floor of %d" % [int(slowest), int(floor_speed)])
	t.check(player.get_hp() < hp_before and hp_before - player.get_hp() <= 15.0 * player.smash_bite + 0.01,
		"smash: the hull took the log's bite (%.1f)" % (hp_before - player.get_hp()))
	t.check(Economy.funds > funds_before, "smash: the salvage still pays")
	_close(scene)

## The bumper is a weapon out here: the chase car rams at twice the arena
## rate from a far lower speed floor, the birds are glass, and a ram that
## wrecks one punches through the wreck — a bird that boxes you in can be
## shot OR driven through.
func test_ram_swats_a_bird() -> void:
	var scene = await _boot()
	scene.catch_enabled = false
	var director = scene.get_node(^"ChaseDirector")
	director.frozen = true
	scene.get_node(^"HordeWall").set_physics_process(false)
	var player = scene.get_node(^"Vehicle")
	t.check(player.ram_damage_scale > 0.06 and player.ram_min_speed < 220.0,
		"ram: the chase car's bumper is tuned up (scale %.2f, floor %d)" % [player.ram_damage_scale, int(player.ram_min_speed)])
	for i in 20:
		await t.physics_frame
	var bird = director.spawn(&"bike")
	bird.set_physics_process(false)   # a sitting duck: the ram rule is what's under test
	bird.velocity = Vector2.ZERO
	bird.global_position = player.global_position + Vector2(0.0, -200.0)
	var mark_y: float = bird.global_position.y
	t.check(bird.get_max_hp() <= 20.0, "ram: a bike is glass (%d HP)" % int(bird.get_max_hp()))
	var kills_before: int = scene.kills
	var slowest := INF
	var passed := false
	for i in 90:
		await t.physics_frame
		slowest = minf(slowest, -player.velocity.y)
		if player.global_position.y < mark_y - 60.0:
			passed = true
			break
	t.check(scene.kills == kills_before + 1, "ram: the bird died under the bumper — and it counts as a kill")
	t.check(passed, "ram: the car is through and past the wreck")
	var floor_speed: float = player.get_controller().max_speed * SpeedBand.FLOOR_FRAC
	t.check(slowest > floor_speed * 0.8,
		"ram: the car never stopped — slowest %d px/s against a floor of %d" % [int(slowest), int(floor_speed)])
	_close(scene)

## Ordnance in the dust makes the pack flinch: a mine of yours the crest
## rolls over goes off under it, a missile of yours that flies into it goes
## off there; the pack's own mines, your MG rounds and anything still in
## front of the crest are left alone.
func test_ordnance_in_the_dust_makes_the_pack_flinch() -> void:
	var scene = await _boot()
	scene.catch_enabled = false
	scene.get_node(^"ChaseDirector").frozen = true
	var wall = scene.get_node(^"HordeWall")
	wall.set_physics_process(false)
	var player = scene.get_node(^"Vehicle")
	var road_x: float = scene.course.sample(-wall.front_y)["x"]
	var inside := Vector2(road_x, wall.front_y + 100.0)
	var outside := Vector2(road_x, wall.front_y - 100.0)
	var MineScene := load("res://environment/mine_land.tscn")
	var mine = MineScene.instantiate()
	mine.dropper = player
	mine.global_position = inside
	scene.add_child(mine)
	var early = MineScene.instantiate()
	early.dropper = player
	early.global_position = outside
	scene.add_child(early)
	var theirs = MineScene.instantiate()
	theirs.dropper = scene.get_node(^"ChaseDirector").spawn(&"bike")
	theirs.global_position = inside
	scene.add_child(theirs)
	var kills_before: int = scene.kills
	scene._physics_process(0.016)
	t.check(mine.is_queued_for_deletion(), "flinch: a mine of yours under the dust goes off")
	t.check(wall.flinching(), "flinch: and the pack flinches")
	t.check(scene.flinches == 1, "flinch: the host counts it")
	t.check(not early.is_queued_for_deletion(), "flinch: a mine still in front of the crest waits for it")
	t.check(not theirs.is_queued_for_deletion(), "flinch: the pack's own mines don't scare it")
	t.check(scene.kills == kills_before, "flinch: a bang in the dust is no kill")
	# The crest rolls over the early mine later: the poll is the fuse.
	wall.front_y = outside.y - 100.0
	scene._physics_process(0.016)
	t.check(early.is_queued_for_deletion() and scene.flinches == 2, "flinch: a mine dropped early pops when the crest reaches it")
	# A missile of yours flying into the dust goes off there; an MG round is nothing.
	wall._flinch_t = 0.0
	var missile = load("res://weapons/missile.tscn").instantiate()
	scene.add_child(missile)
	missile.setup(inside, Vector2.DOWN, 0.0, 26.0, 4.0, player)
	var retired := [false]
	missile.retired.connect(func(_id: int) -> void: retired[0] = true)
	scene._physics_process(0.016)
	t.check(retired[0] and wall.flinching(), "flinch: a missile of yours in the dust goes off there")
	var round_ = load("res://weapons/projectile.tscn").instantiate()
	scene.add_child(round_)
	round_.setup(inside, Vector2.DOWN, 0.0, 2.0, 1.0, player)
	round_.hit_sfx = &"hit_mg"
	var mg_retired := [false]
	round_.retired.connect(func(_id: int) -> void: mg_retired[0] = true)
	wall._flinch_t = 0.0
	scene._physics_process(0.016)
	t.check(not mg_retired[0] and not wall.flinching(), "flinch: an MG round in the dust is nothing")
	_close(scene)

## The back roads: on a cutoff's trail the pack loses sight of the car —
## and finds it again when the car comes back through the mouth. The birds
## themselves never leave the road.
func test_the_trail_loses_the_pack() -> void:
	const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")
	var scene = await _boot()
	scene.catch_enabled = false
	var director = scene.get_node(^"ChaseDirector")
	director.frozen = true
	var wall = scene.get_node(^"HordeWall")
	wall.set_physics_process(false)
	var player = scene.get_node(^"Vehicle")
	player.set_physics_process(false)
	var streamer = scene.get_node(^"CourseStreamer")
	var d: float = -player.global_position.y
	var cut: int = scene.course.chunk_index_at(d) + 1
	streamer.invalidate_from(cut)
	scene.course.splice(cut, [&"cutoff_l", &"straight", &"straight"])
	var entry: Dictionary = scene.course.plan[cut]
	var def: Dictionary = entry["def"]
	var start: float = entry["start_d"]
	t.check(not scene.on_trail(), "trail: on the road the pack has you")
	# Onto the trail, mid-straight.
	var td: float = start + 1000.0
	player.global_position = Vector2(float(entry["entry_x"]) + ChunkDefs.cutoff_x(def, 1000.0), -td)
	scene._physics_process(0.016)
	t.check(scene.on_trail() and wall.lost_sight, "trail: off the road on the trail the pack loses sight of you")
	t.check(wall.get_node(^"Deco").lost_sight, "trail: and the riders start looking")
	# The same d, back on the asphalt: found.
	player.global_position = Vector2(scene.course.sample(td)["x"], -td)
	scene._physics_process(0.016)
	t.check(not scene.on_trail() and not wall.lost_sight, "trail: back on the road they have you again")
	# Out past the shoulder but beyond the trail's reach along the road: not the trail.
	player.global_position = Vector2(float(entry["entry_x"]) - 600.0, -(start + 40.0))
	scene._physics_process(0.016)
	t.check(not scene.on_trail(), "trail: the verge before the mouth is not the trail")
	# A bird's steering never leaves the road, trail or no trail.
	var bird = director.spawn(&"bike")
	bird.global_position = Vector2(float(entry["entry_x"]) - 500.0, -td)
	player.global_position = Vector2(float(entry["entry_x"]) + ChunkDefs.cutoff_x(def, 1000.0), -td)
	var brain = bird.get_driver()
	var clamp_x: float = brain._clamp_to_road(bird, bird.global_position, player.global_position.x)
	var s: Dictionary = scene.course.sample(td)
	t.check(clamp_x >= float(s["x"]) - float(s["half_w"]), "trail: the birds' road clamp keeps them on the asphalt (%d)" % int(clamp_x))
	_close(scene)

## The windshield streaks read "flat out" the same for every ride.
func test_speed_streaks_scale_to_the_car() -> void:
	const Lines := preload("res://ui/speed_lines.gd")
	for top in [453.0, 640.0]:
		t.check(is_equal_approx(Lines.intensity(top * SpeedBand.CRUISE_FRAC, top), 0.0),
			"streaks: nothing at cruise (top %d)" % int(top))
		var flat: float = Lines.intensity(top, top)
		t.check(flat > 0.0 and flat < 0.5, "streaks: a whisper flat out (top %d, %.2f)" % [int(top), flat])
		t.check(is_equal_approx(Lines.intensity(top * 1.5, top), 1.0),
			"streaks: the full windshield on the boost (top %d)" % int(top))
	t.check(is_equal_approx(Lines.intensity(453.0, 453.0), Lines.intensity(640.0, 640.0)),
		"streaks: the slowest ride reads flat out exactly like the fastest")
	t.check(is_equal_approx(Lines.intensity(500.0, 0.0), 0.0), "streaks: no top, no streaks, no divide by zero")

## The other side of the gamble: living dangerously pays, if you live.
func test_daredevil_accrues_on_the_bumper_and_pays_at_the_line() -> void:
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	Economy.funds = 1000
	scene._process(1.0)
	t.check(scene.daredevil_bonus() == 0, "dare: a comfortable gap earns nothing")
	wall.front_y = player.global_position.y + WallScript.DANGER_GAP - 20.0
	scene._process(1.0)
	t.check(scene.daredevil_bonus() == int(scene.DAREDEVIL_RATE),
		"dare: a second on the bumper banks a second's bonus (%d)" % scene.daredevil_bonus())
	for i in 40:
		scene.clock = 0.0  # hold the clock still: this is about the bonus, not the line
		scene._process(1.0)
	t.check(scene.daredevil_bonus() == scene.DAREDEVIL_CAP, "dare: the bonus has a ceiling")
	t.check(Economy.funds == 1000, "dare: nothing is paid until the line")
	t.check(WallScript.DANGER_GAP > WallScript.CATCH_MARGIN and WallScript.DANGER_GAP < WallScript.LEASH_GAP,
		"dare: the danger zone is never where clean driving rests — it has to be dared")
	scene.finale_enabled = false
	scene.clock = scene.RUN_SECONDS
	scene._process(0.016)
	t.check(scene._won, "dare: made it")
	t.check(Economy.funds == 1000 + scene.PURSE + scene.DAREDEVIL_CAP,
		"dare: the purse and the bonus land in the wallet (%d)" % Economy.funds)
	var es = scene._end_screen
	t.check(String(es.win_note).contains(str(scene.PURSE)) and String(es.win_note).contains(str(scene.DAREDEVIL_CAP)),
		"dare: the win card says what for (%s)" % es.win_note)
	t.check(es.visible, "dare: the win card is up")
	_close(scene)

func test_no_purse_for_the_robbed_or_off_the_tour() -> void:
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	Economy.funds = 1000
	wall.front_y = player.global_position.y + WallScript.DANGER_GAP - 20.0
	scene._process(5.0)
	t.check(scene.daredevil_bonus() > 0, "dare: bonus on the table")
	wall.front_y = player.global_position.y + WallScript.CATCH_MARGIN - 5.0
	scene._process(0.016)
	t.check(scene.is_jacked() and Economy.funds == 1000, "dare: caught before the line = the bonus dies with the run")
	_close(scene)
	var off = await _boot()
	Economy.enabled = false  # a non-campaign lane: the wallet valve is shut
	Economy.funds = 1000
	off.finale_enabled = false
	off.clock = off.RUN_SECONDS
	off._process(0.016)
	t.check(off._won and Economy.funds == 1000, "dare: off the tour the line pays nothing")
	t.check(String(off._end_screen.win_note) == "", "dare: and the card doesn't pretend it did")
	_close(off)

## The pack, the pedal, the keeper and the Buzzardz all price off ONE number:
## the car's honest top on asphalt — its road profile included.
func test_everything_prices_off_the_asphalt_top() -> void:
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	var keeper = scene.get_node(^"PaceKeeper")
	var listed: float = player.get_controller().max_speed
	var road: float = float(DrivingController.effective_terrain(player, &"road")["top"])
	var want: float = listed * road
	t.check(is_equal_approx(SpeedBand.road_top(player), want),
		"chase: the honest top is the ceiling on asphalt (%d x %.2f)" % [int(listed), road])
	t.check(is_equal_approx(wall.base_top(), want), "chase: the pack prices off it")
	t.check(is_equal_approx(keeper.floor_speed(), want * keeper.KEEP_FRAC), "chase: the pace floor prices off it")
	t.check(is_equal_approx(-player.velocity.y, want * SpeedBand.CRUISE_FRAC)
		or absf(-player.velocity.y - want * SpeedBand.CRUISE_FRAC) < want * 0.2,
		"chase: the rolling start lands near the car's own cruise (vy %d)" % int(player.velocity.y))
	_close(scene)

## A scene booted with no car to chase (mp_managed strips the baked cars —
## the level-shot probe does this) must stand down, not crash.
func test_no_car_no_run() -> void:
	var scene = load(CHASE_SCENE).instantiate()
	scene.mp_managed = true
	t.root.add_child(scene)
	t.current_scene = scene
	for i in 3:
		await t.physics_frame
	t.check(scene.course != null and scene.course.plan.size() > 0, "chase: the plan is still rolled")
	t.check(scene.get_node_or_null(^"HordeWall") == null, "chase: no car, no pack")
	t.check(is_equal_approx(scene.wall_gap(), WallScript.MAX_GAP) and not scene.in_danger()
		and is_equal_approx(scene.pressure(), 0.0), "chase: the HUD surface stays safe to poll")
	t.check(not scene.is_jacked(), "chase: nobody to rob")
	t.paused = false
	Economy.enabled = false
	Economy.reset_run()
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()

func test_caught_is_a_robbery_not_a_life() -> void:
	var scene = await _boot()
	var gs = t.root.get_node(^"/root/GameState")
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	var events: Array = []
	scene.jacked.connect(func(cause: StringName) -> void: events.append(cause))
	Economy.funds = 4000
	wall.front_y = player.global_position.y + WallScript.CATCH_MARGIN - 5.0
	scene._process(0.016)
	t.check(scene.is_jacked() and scene.jack_cause == &"caught", "chase: the pack catching the car ends the run")
	t.check(events.size() == 1 and events[0] == &"caught", "chase: jacked fires once, with the cause")
	t.check(gs.lives == 3, "chase: a catch never costs a life")
	t.check(Economy.funds == 4000, "chase: no wreck penalty — the robbery is the only bill")
	t.check(player.get_hp() > 0.0, "chase: the catch never touched Health")
	t.check(scene.get_node(^"ChaseDirector").frozen, "chase: the pack comes off the trigger")
	t.check(not scene.get_node(^"PaceKeeper").enabled, "chase: the road lets go of the car")
	t.check(wall.no_mercy, "chase: the dust rolls over the car")
	var intent: Dictionary = player.get_driver().get_intent(player, 0.016)
	t.check(is_equal_approx(float(intent["throttle"]), 0.0) and not intent["fire_mg"],
		"chase: a caught driver's hands leave the wheel")
	scene._process(0.016)
	t.check(events.size() == 1, "chase: the run ends once")
	# The robbery card (the jack beat's timer lands here on its own in play).
	# Seeded dice: wedge 0 of the default wheel is a quarter of the wallet.
	scene.robbery_rng.seed = _seed_landing_on(0)
	scene._open_robbery()
	var card = scene.get_node_or_null(^"RobberyScreen")
	t.check(card != null and t.paused, "chase: the robbery card freezes the world")
	t.check(Economy.funds == 3000,
		"chase: the wheel landed on a quarter of the wallet (wallet %d)" % Economy.funds)
	t.check(card.get_node_or_null(^"Panel") != null, "chase: the card has something to show")
	t.check(gs.carry_ammo.size() == WeaponRack.Slot.size(),
		"chase: the bay you had rides on to the next stop")
	scene._open_robbery()
	t.check(Economy.funds == 3000, "chase: you are only robbed once")
	# Rolling on: the campaign advances past Route 666 — robbed, not beaten.
	var rolls: Array = []
	scene.rolled_on.connect(func(next: int) -> void: rolls.append(next))
	card.roll_on()
	card.roll_on()
	t.check(rolls.size() == 1, "chase: the card rolls on exactly once")
	t.check(rolls.size() == 1 and rolls[0] == _chase_index() + 1 and gs.level_index == _chase_index() + 1,
		"chase: the road goes on to the next stop (index %d)" % gs.level_index)
	t.check(not t.paused, "chase: rolling on releases the pause")
	t.check(gs.lives == 3, "chase: three lives in, three lives out")
	_close(scene)

func test_wrecked_is_the_same_robbery() -> void:
	var scene = await _boot()
	var gs = t.root.get_node(^"/root/GameState")
	var player = scene.get_node(^"Vehicle")
	scene.catch_enabled = false  # a stood-down pack still can't save a wreck
	Economy.funds = 2000
	player.get_node(^"Health").kill()
	scene._process(0.016)
	t.check(scene.is_jacked() and scene.jack_cause == &"wrecked", "chase: a wreck ends the run the same way")
	t.check(gs.lives == 3, "chase: a wreck never costs a life either")
	t.check(Economy.funds == 2000, "chase: no destroyed penalty on Route 666")
	scene.robbery_rng.seed = _seed_landing_on(0)
	scene._open_robbery()
	t.check(scene.get_node_or_null(^"RobberyScreen") != null and Economy.funds == 1500,
		"chase: they pick over the wreck (wallet %d)" % Economy.funds)
	var es = scene._end_screen
	es._process(0.016)
	t.check(not es.visible, "chase: the loss card never shows on the tour")
	_close(scene)

func test_stood_down_pack_cannot_catch() -> void:
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	scene.catch_enabled = false
	wall.front_y = player.global_position.y + 10.0
	scene._process(0.016)
	t.check(not scene.is_jacked(), "chase: catch_enabled = false stands the pack down (other suites' fixtures)")
	_close(scene)

func test_a_tie_goes_to_the_pack() -> void:
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	wall.front_y = player.global_position.y + WallScript.CATCH_MARGIN - 5.0
	scene.clock = scene.RUN_SECONDS - 0.001
	scene._process(0.016)
	t.check(scene.is_jacked() and not scene._won, "chase: caught on the line is still caught")
	_close(scene)

func test_devgod_robbery_is_inert() -> void:
	var gs = t.root.get_node(^"/root/GameState")
	var dev_was: bool = gs.dev_mode
	var scene = await _boot()
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	Economy.god = true  # what combat_level sets from is_devgod_enabled() at boot
	Economy.funds = 4000
	wall.front_y = player.global_position.y + WallScript.CATCH_MARGIN - 5.0
	scene._process(0.016)
	t.check(scene.is_jacked(), "chase: DEVGOD can still be caught (the pit precedent)")
	scene._open_robbery()
	t.check(Economy.funds == 4000, "chase: DEVGOD's wallet is untouched")
	t.check(scene.get_node_or_null(^"RobberyScreen") != null, "chase: the flow still plays — it stays testable")
	gs.dev_mode = dev_was
	_close(scene)

func test_off_the_tour_the_loss_panel_stands_in() -> void:
	var scene = await _boot()
	var gs = t.root.get_node(^"/root/GameState")
	var player = scene.get_node(^"Vehicle")
	gs.game_mode = &"single_battle"  # no tour to rejoin: nothing to rob, nowhere to roll on
	gs.owned_mods = ["armor_plating"]
	Economy.funds = 4000
	player.get_node(^"Health").kill()
	scene._process(0.016)
	t.check(scene.is_jacked(), "chase: the run still ends")
	scene._open_robbery()
	t.check(scene.get_node_or_null(^"RobberyScreen") == null, "chase: no wheel off the tour — nothing to take")
	t.check(scene._end_screen.visible, "chase: the classic loss panel stands in")
	t.check(Economy.funds == 4000 and gs.owned_mods == ["armor_plating"] and gs.lives == 3,
		"chase: nothing is taken off the tour")
	gs.owned_mods.clear()
	_close(scene)
