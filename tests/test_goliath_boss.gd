extends RefCounted
## The two-pool phase machinery: the boss controller overrides the cab's
## Health to the phase-1 pool, spawns/attaches the trailer beside the level,
## and — the load-bearing check — an overkill hit that empties the pool trips
## the phase gate WITHOUT ever firing died (the sentinel refill inside the
## same synchronous take_damage call beats health.gd's hp<=0 check).

const BossScript := preload("res://vehicles/goliath/goliath_boss.gd")
const CutsceneScript := preload("res://vehicles/goliath/goliath_cutscene.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var cab = VehicleScene.instantiate()
	cab.faction = &"enemies"  # keep the fixture cab out of the player group —
							  # transitions take the instant path unless a test
							  # stages a real player for the theatre
	container.add_child(cab)
	var boss = BossScript.new()
	boss.name = "BossController"
	cab.add_child(boss)
	return {"container": container, "cab": cab, "boss": boss}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func test_phase_gate_never_dies() -> void:
	var f := _fixture()
	await t.physics_frame  # deferred setup: trailer spawn + pool override
	var health: Health = f.cab.get_node("Health")
	t.check(is_equal_approx(health.max_hp, BossScript.PHASE1_HP),
		"boss: phase-1 pool authored over the stats deck")
	t.check(f.boss.trailer != null and is_instance_valid(f.boss.trailer),
		"boss: trailer spawned beside the level")
	t.check(f.boss.trailer.get_parent() == f.container,
		"boss: trailer is a level sibling, not a cab child")
	var died_flag := [false]
	health.died.connect(func() -> void: died_flag[0] = true)
	health.take_damage(BossScript.PHASE1_HP + 500.0)  # one overkill hit
	t.check(f.boss.phase == 2, "boss: pool depletion trips the phase gate")
	t.check(not died_flag[0], "boss: died NEVER fires at the transition")
	t.check(health.god, "boss: immortal while the transition pends")
	t.check(health.hp > 0.0, "boss: sentinel refill holds the pool positive")
	# Further phase-1 hits are shrugged off — the gate never re-trips.
	health.take_damage(9999.0)
	t.check(f.boss.phase == 2 and not died_flag[0], "boss: post-gate hits are no-ops")
	_done(f)

## No player to stage for: the instant path lands phase 2 hot — fresh pool,
## trailer gone, mortality back, feel deck swapped on the controller.
func test_transition_lands_phase2_hot() -> void:
	var f := _fixture()
	await t.physics_frame
	var health: Health = f.cab.get_node("Health")
	var ctrl = f.cab.get_controller()
	var speed_before: float = ctrl.max_speed
	health.take_damage(BossScript.PHASE1_HP + 10.0)
	await t.physics_frame  # deferred _begin_transition
	t.check(is_equal_approx(health.max_hp, BossScript.PHASE2_HP), "phase 2: fresh pool")
	t.check(not health.god, "phase 2: mortal again")
	t.check(f.boss.trailer == null, "phase 2: the trailer is gone")
	t.check(not is_equal_approx(ctrl.max_speed, speed_before),
		"phase 2: the bobtail feel deck swapped onto the controller")
	t.check(not t.paused, "phase 2: no stray pause on the instant path")
	_done(f)

## With a live player the transition is staged: the world freezes, the show
## plays (shrunk beats for the suite), and phase 2 is handed back unpaused.
func test_theatrical_transition_freezes_and_hands_back() -> void:
	var saved := [CutsceneScript.CAM_TIME, CutsceneScript.EXPLOSION_COUNT,
		CutsceneScript.EXPLOSION_GAP, CutsceneScript.REV_TIME, CutsceneScript.HANDBACK_TIME]
	CutsceneScript.CAM_TIME = 0.05
	CutsceneScript.EXPLOSION_COUNT = 1
	CutsceneScript.EXPLOSION_GAP = 0.05
	CutsceneScript.REV_TIME = 0.05
	CutsceneScript.HANDBACK_TIME = 0.05
	var f := _fixture()
	var player = VehicleScene.instantiate()  # default faction joins "player"
	player.position = Vector2(600, 0)
	f.container.add_child(player)
	await t.physics_frame
	var health: Health = f.cab.get_node("Health")
	health.take_damage(BossScript.PHASE1_HP + 10.0)
	await t.physics_frame  # deferred director spawn
	t.check(t.paused, "cutscene: the world holds its breath")
	t.check(health.hp > 0.0, "cutscene: the boss is alive under the fireworks")
	for i in 180:
		await t.process_frame
		if not t.paused:
			break
	var handed_back: bool = not t.paused
	t.paused = false  # safety: never leak a paused tree into later suites
	t.check(handed_back, "cutscene: the show ends and unpauses on its own")
	t.check(is_equal_approx(health.max_hp, BossScript.PHASE2_HP),
		"cutscene: phase 2 handed back hot")
	CutsceneScript.CAM_TIME = saved[0]
	CutsceneScript.EXPLOSION_COUNT = saved[1]
	CutsceneScript.EXPLOSION_GAP = saved[2]
	CutsceneScript.REV_TIME = saved[3]
	CutsceneScript.HANDBACK_TIME = saved[4]
	_done(f)

func test_chip_damage_does_not_trip_the_gate() -> void:
	var f := _fixture()
	await t.physics_frame
	var health: Health = f.cab.get_node("Health")
	health.take_damage(BossScript.PHASE1_HP * 0.5)
	t.check(f.boss.phase == 1, "boss: half the pool is not a transition")
	t.check(not health.god, "boss: still mortal mid-phase")
	_done(f)
