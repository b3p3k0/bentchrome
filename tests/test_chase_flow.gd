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
	scene._open_robbery()
	var card = scene.get_node_or_null(^"RobberyScreen")
	t.check(card != null and t.paused, "chase: the robbery card freezes the world")
	t.check(Economy.funds == 3000,
		"chase: the placeholder shakedown takes a quarter (wallet %d)" % Economy.funds)
	t.check(card.get_node_or_null(^"CenterContainer") != null or card.get_child_count() > 0,
		"chase: the card has something to show")
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

## The leaf on its own: a bite of bolts, and the fallbacks when there's
## nothing to bite.
func test_placeholder_shakedown() -> void:
	Economy.enabled = true
	Economy.god = false
	Economy.funds = 1000
	var hit: Dictionary = Robbery.apply(Robbery.placeholder_slice(), null)
	t.check(hit["kind"] == Robbery.Kind.BOLTS and hit["bolts"] == 250 and Economy.funds == 750,
		"robbery: a quarter of the wallet")
	t.check(String(hit["headline"]) != "" and String(hit["detail"]).contains("250"),
		"robbery: the outcome says what was taken")
	Economy.funds = 0
	var broke: Dictionary = Robbery.apply(Robbery.placeholder_slice(), null)
	t.check(broke["kind"] == Robbery.Kind.DIGNITY and broke["bolts"] == 0,
		"robbery: a dry wallet costs nothing but dignity")
	var odd: Dictionary = Robbery.apply({"kind": Robbery.Kind.DIGNITY}, null)
	t.check(odd["bolts"] == 0 and String(odd["headline"]) != "", "robbery: a harmless slice is harmless")
	Economy.enabled = false
	Economy.reset_run()
