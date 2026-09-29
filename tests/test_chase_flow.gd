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
	scene._process(0.016)
	t.check(scene.loss_cause() == &"" and not scene.is_jacked(), "chase: a clean run is still running")
	scene.clock = scene.RUN_SECONDS - 0.01
	scene._process(0.016)
	t.check(scene._won, "chase: the clock calls the win")
	t.check(not scene.is_jacked() and gs.lives == 3, "chase: a win costs nothing")
	t.check(scene.get_node(^"ChaseDirector").frozen, "chase: the pack stands down at the line")
	_close(scene)

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
	Economy.funds = 4000
	player.get_node(^"Health").kill()
	scene._process(0.016)
	t.check(scene.is_jacked(), "chase: the run still ends")
	scene._open_robbery()
	t.check(scene.get_node_or_null(^"RobberyScreen") == null, "chase: no robbery off the tour")
	t.check(scene._end_screen.visible, "chase: the classic loss panel stands in")
	t.check(Economy.funds == 4000, "chase: nothing is taken off the tour")
	_close(scene)
