extends RefCounted
## The wave director: phase table shape, phase lookup, the runtime spawn
## recipe (stats/driver/palette/position land before add_child), cap respect,
## pack-pace handoff, absorb line, the stand-down, and the kill tally.

const DirectorScript := preload("res://levels/chase/chase_director.gd")
const RunScript := preload("res://levels/chase/buzzard_run.gd")

var t

func _init(runner) -> void:
	t = runner

func test_phase_table_sane() -> void:
	var last_t := -1.0
	for ph in DirectorScript.PHASES:
		t.check(ph["t"] > last_t, "director: phase starts ascend (t=%s)" % ph["t"])
		last_t = ph["t"]
		t.check(int(ph["cap"]) >= 1 and int(ph["cap"]) <= 8, "director: cap within the perf budget")
		t.check(ph["pace"] >= 0.7 and ph["pace"] <= 1.0,
			"director: pace stays a fraction of the chased car's top (%.2f)" % ph["pace"])
		t.check(ph["t"] < RunScript.RUN_SECONDS, "director: every beat starts inside the run")
		t.check(not ph["weights"].is_empty(), "director: the spawns never stop (t=%s)" % ph["t"])
		for kind in ph["weights"]:
			t.check(DirectorScript.CLASS_TABLE.has(kind), "director: %s is a real class" % kind)
			t.check(ph["weights"][kind] > 0.0, "director: weights positive")
	t.check(is_equal_approx(DirectorScript.PHASES[0]["t"], 0.0), "director: arc starts at zero")
	var last: Dictionary = DirectorScript.PHASES[DirectorScript.PHASES.size() - 1]
	t.check(is_equal_approx(last["pace"], 1.0), "director: the last mile runs at the car's own top")

func test_phase_lookup() -> void:
	t.check(is_equal_approx(DirectorScript.phase_at(0.0)["pace"], 0.80), "director: green flag at t=0")
	t.check(is_equal_approx(DirectorScript.phase_at(28.0)["t"], 25.0), "director: breath covers t=28")
	t.check(DirectorScript.phase_at(28.0)["pace"] < DirectorScript.phase_at(20.0)["pace"],
		"director: a breath eases the pace")
	t.check(is_equal_approx(DirectorScript.phase_at(500.0)["t"], 110.0), "director: last mile is terminal")

func test_spawn_cull_grace_and_kills() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	if gs != null:
		gs.lives = 3
		gs.devgod = false
	var scene = load("res://levels/chase/buzzard_run.tscn").instantiate()
	scene.catch_enabled = false  # this suite is about the director, not the catch
	t.root.add_child(scene)
	t.current_scene = scene
	for i in 3:
		await t.physics_frame
	var director = scene.get_node(^"ChaseDirector")
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	# The recipe: a spawned bike boils up out of the dust crest, on the road, tuned.
	var bike = director.spawn(&"bike")
	t.check(bike.is_in_group(&"enemies"), "director: spawn joins the enemies group")
	var depth: float = bike.global_position.y - wall.front_y
	t.check(is_equal_approx(depth, DirectorScript.EMERGE_DEPTH),
		"director: pursuers are born inside the dust crest (depth %d)" % int(depth))
	t.check(DirectorScript.EMERGE_DEPTH < DirectorScript.ABSORB_DEPTH,
		"director: a newborn is never already past the absorb line")
	t.check(bike.global_position.y > player.global_position.y,
		"director: the pack spawns behind the player")
	t.check(bike.get_node(^"Driver").role == &"bike", "director: driver role set")
	# Every Buzzard's ceiling is priced against the car it chases.
	var player_top: float = player.get_controller().max_speed
	t.check(is_equal_approx(bike.get_controller().max_speed, player_top * DirectorScript.ROLE_PACE[&"bike"]),
		"director: a bike tops out at %.2f of the player's top" % DirectorScript.ROLE_PACE[&"bike"])
	t.check(DirectorScript.ROLE_PACE[&"bike"] > 1.0 and DirectorScript.ROLE_PACE[&"sedan"] > 1.0,
		"director: pursuers can always catch an honest car")
	t.check(DirectorScript.ROLE_PACE[&"technical"] < 1.0,
		"director: ahead-spawns are slow by design — they fall back through the field")
	for kind in DirectorScript.CLASS_TABLE:
		t.check(DirectorScript.ROLE_PACE.has(kind), "director: %s has a pace" % kind)
	var bike_hp: float = bike.get_node(^"Health").max_hp
	t.check(bike_hp < 50.0, "director: bike is glass (hp %d)" % int(bike_hp))
	var sedan = director.spawn(&"sedan")
	var sedan_hp: float = sedan.get_node(^"Health").max_hp
	t.check(sedan_hp > bike_hp, "director: sedan carries more plate")
	var tech = director.spawn(&"technical")
	var tech_dy: float = tech.global_position.y - player.global_position.y
	t.check(absf(tech_dy + DirectorScript.SPAWN_AHEAD) < 50.0,
		"director: technical rolls in from ahead (dy %d)" % int(tech_dy))
	t.check(tech.get_node_or_null(^"Visual/Turret") != null,
		"director: the bed turret grew from stats")
	tech.queue_free()  # keep the cap math below at two live birds
	await t.physics_frame
	t.check(sedan.get_node(^"Driver").lane_offset * bike.get_node(^"Driver").lane_offset < 0.0,
		"director: lanes alternate sides")
	# Cap respect: phase 0 caps at 2 and both slots are taken.
	scene.clock = 0.0
	director._spawn_cd = 0.0
	for i in 3:
		await t.physics_frame
	t.check(get_tree_enemies() == 2, "director: cap holds the line (got %d)" % get_tree_enemies())
	# The pack's pace rides the phase.
	scene.clock = 95.0
	await t.physics_frame
	await t.physics_frame
	t.check(is_equal_approx(wall.pace_frac, 0.97), "director: all-in drives the pack's pace")
	scene.clock = 20.0  # back off the crescendo for the rest of the test
	# Park the dust front: the rest of this test is about the director, not
	# the chase (a surging front rolls over its own outriders and absorbs them).
	wall.set_physics_process(false)
	# Kill tally.
	var kills_before: int = scene.kills
	bike.get_node(^"Health").kill()
	await t.physics_frame
	t.check(scene.kills == kills_before + 1, "director: wrecked buzzard rings the bell")
	var tumbling := false
	for child in scene.get_children():
		var script = child.get_script()
		if script and script.resource_path.ends_with("death_tumble.gd"):
			tumbling = true
	t.check(tumbling, "director: the wreck tumbles out")
	# Stand-down (the run is over): spawns freeze and every live Buzzard
	# comes off the trigger — and stays off it. Nobody respawns on Route 666.
	t.check(not sedan.get_node(^"Driver").hold_fire, "director: the pack fights until the run ends")
	director.stand_down()
	t.check(director.frozen, "director: stand-down freezes the director")
	t.check(sedan.get_node(^"Driver").hold_fire, "director: stand-down takes the pack off the trigger")
	# Absorb: leave the field far behind, let the dust front catch up (one
	# tick clamps it to MAX_GAP), sweep. The pack takes its own back
	# quietly — no wreck, no bell, no bounty.
	wall.set_physics_process(true)
	var straggler = director.spawn(&"bike")
	await t.physics_frame
	var Economy := preload("res://game/economy.gd")
	var econ_was: bool = Economy.enabled
	Economy.enabled = true
	var funds_before: int = Economy.funds
	var kills_at_absorb: int = scene.kills
	player.global_position.y -= 6000.0
	await t.physics_frame
	t.check(straggler.global_position.y > wall.front_y + DirectorScript.ABSORB_DEPTH,
		"director: the dust front rolled over the straggler")
	director._absorb()
	await t.physics_frame
	await t.physics_frame
	t.check(get_tree_enemies() == 0, "director: the pack absorbs what you outrun (got %d)" % get_tree_enemies())
	t.check(scene.kills == kills_at_absorb, "director: an absorbed Buzzard rings no bell")
	t.check(Economy.funds == funds_before, "director: an absorbed Buzzard pays no bounty")
	Economy.enabled = econ_was
	Economy.funds = funds_before
	t.paused = false
	if gs != null:
		gs.lives = 3
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()

func get_tree_enemies() -> int:
	return t.get_nodes_in_group(&"enemies").size()
