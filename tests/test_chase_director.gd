extends RefCounted
## The wave director: phase table shape, phase lookup, the runtime spawn
## recipe (stats/driver/palette/position land before add_child), cap respect,
## wall-speed handoff, cull line, respawn grace, and the kill tally.

const DirectorScript := preload("res://levels/chase/chase_director.gd")

var t

func _init(runner) -> void:
	t = runner

func test_phase_table_sane() -> void:
	var last_t := -1.0
	for ph in DirectorScript.PHASES:
		t.check(ph["t"] > last_t, "director: phase starts ascend (t=%s)" % ph["t"])
		last_t = ph["t"]
		t.check(int(ph["cap"]) >= 1 and int(ph["cap"]) <= 8, "director: cap within the perf budget")
		t.check(ph["wall"] >= 250.0 and ph["wall"] <= 450.0, "director: wall cruise stays outrunnable")
		for kind in ph["weights"]:
			t.check(DirectorScript.CLASS_TABLE.has(kind), "director: %s is a real class" % kind)
			t.check(ph["weights"][kind] > 0.0, "director: weights positive")
	t.check(is_equal_approx(DirectorScript.PHASES[0]["t"], 0.0), "director: arc starts at zero")

func test_phase_lookup() -> void:
	t.check(is_equal_approx(DirectorScript.phase_at(0.0)["wall"], 300.0), "director: warm-up phase at t=0")
	t.check(is_equal_approx(DirectorScript.phase_at(60.0)["t"], 50.0), "director: breather covers t=60")
	t.check(is_equal_approx(DirectorScript.phase_at(500.0)["t"], 168.0), "director: finale is terminal")

func test_spawn_cull_grace_and_kills() -> void:
	var gs = t.root.get_node_or_null(^"/root/GameState")
	if gs != null:
		gs.lives = 3
		gs.devgod = false
	var scene = load("res://levels/chase/buzzard_run.tscn").instantiate()
	t.root.add_child(scene)
	t.current_scene = scene
	for i in 3:
		await t.physics_frame
	var director = scene.get_node(^"ChaseDirector")
	var player = scene.get_node(^"Vehicle")
	var wall = scene.get_node(^"HordeWall")
	# The recipe: a spawned bike lands behind the player, on the road, tuned.
	var bike = director.spawn(&"bike")
	t.check(bike.is_in_group(&"enemies"), "director: spawn joins the enemies group")
	var dy: float = bike.global_position.y - player.global_position.y
	t.check(absf(dy - DirectorScript.SPAWN_BEHIND) < 50.0,
		"director: spawns off-screen behind (dy %d)" % int(dy))
	t.check(bike.get_node(^"Driver").role == &"bike", "director: driver role set")
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
	# Wall speed rides the phase.
	scene.clock = 130.0
	await t.physics_frame
	await t.physics_frame
	t.check(is_equal_approx(wall.wall_speed, 380.0), "director: crescendo drives the wall")
	scene.clock = 20.0  # back off the crescendo for the rest of the test
	# Respawn grace: the pack holds fire, then releases.
	director.on_player_respawn()
	t.check(bike.get_node(^"Driver").hold_fire, "director: grace holds the pack's fire")
	for i in 170:
		await t.physics_frame
	t.check(not bike.get_node(^"Driver").hold_fire, "director: grace lifts")
	# Kill tally.
	var kills_before: int = scene.kills
	bike.get_node(^"Health").kill()
	await t.physics_frame
	t.check(scene.kills == kills_before + 1, "director: wrecked buzzard rings the bell")
	# Cull: freeze new spawns, leave the field far behind, sweep.
	director.frozen = true
	player.global_position.y -= 6000.0
	director._cull()
	await t.physics_frame
	await t.physics_frame
	t.check(get_tree_enemies() == 0, "director: stragglers cull far south (got %d)" % get_tree_enemies())
	t.paused = false
	if gs != null:
		gs.lives = 3
	t.current_scene = null
	t.root.remove_child(scene)
	scene.free()

func get_tree_enemies() -> int:
	return t.get_nodes_in_group(&"enemies").size()
