extends RefCounted
## The horde wall's pressure math (advance, clamp, kill, shield, reset), the
## end screen's chase-mode group-win suppression, and the full rolling-start
## respawn loop through a booted buzzard_run scene.

const WallScript := preload("res://levels/chase/horde_wall.gd")
const HealthScript := preload("res://vehicles/health.gd")

var t

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
	wall.wall_speed = 330.0
	wall.front_y = player.position.y + 2000.0
	container.add_child(wall)
	wall._physics_process(0.5)
	t.check(is_equal_approx(wall.gap(), 2000.0 - 165.0), "wall: advances at cruise (gap %d)" % int(wall.gap()))
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
	t.check(intent["throttle"] >= 0.45, "chase: throttle floor holds with feet off the pedal")
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
