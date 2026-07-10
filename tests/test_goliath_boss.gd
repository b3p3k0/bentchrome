extends RefCounted
## The two-pool phase machinery: the boss controller overrides the cab's
## Health to the phase-1 pool, spawns/attaches the trailer beside the level,
## and — the load-bearing check — an overkill hit that empties the pool trips
## the phase gate WITHOUT ever firing died (the sentinel refill inside the
## same synchronous take_damage call beats health.gd's hp<=0 check).

const BossScript := preload("res://vehicles/goliath/goliath_boss.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

func _init(runner) -> void:
	t = runner

func _fixture() -> Dictionary:
	var container := Node2D.new()
	t.root.add_child(container)
	var cab = VehicleScene.instantiate()
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

func test_chip_damage_does_not_trip_the_gate() -> void:
	var f := _fixture()
	await t.physics_frame
	var health: Health = f.cab.get_node("Health")
	health.take_damage(BossScript.PHASE1_HP * 0.5)
	t.check(f.boss.phase == 1, "boss: half the pool is not a transition")
	t.check(not health.god, "boss: still mortal mid-phase")
	_done(f)
