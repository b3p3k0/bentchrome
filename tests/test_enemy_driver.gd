extends RefCounted
## EnemyDriver logic tests: archetype mix blending, stuck detection, and the
## unstick escape intent. Pure logic only — feeler raycasts are HI-verified.

const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

var t

## Minimal stand-in for targeting tests: position + hp fraction + groups.
class FakeCar extends Node2D:
	var hpf := 1.0
	var last_attacker: Node2D = null
	func get_hp_fraction() -> float:
		return hpf

func _init(runner) -> void:
	t = runner

## Mounts fake cars in the tree ("vehicles" group; optionally "player") and
## returns [container, hunter]. Caller frees the container.
func _targeting_rig() -> Array:
	var container := Node2D.new()
	t.root.add_child(container)
	var hunter := FakeCar.new()
	container.add_child(hunter)
	hunter.add_to_group(&"vehicles")
	return [container, hunter]

func _car(container: Node, pos: Vector2, hpf: float, is_player := false) -> FakeCar:
	var c := FakeCar.new()
	container.add_child(c)
	c.global_position = pos
	c.hpf = hpf
	c.add_to_group(&"vehicles")
	if is_player:
		c.add_to_group(&"player")
	return c

func test_blend_pure_archetypes() -> void:
	var agg: Dictionary = DriverScript.blend_params(Vector3(1, 0, 0))
	t.check_approx(agg["near"], 110.0, "blend: aggressor near")
	t.check_approx(agg["far"], 300.0, "blend: aggressor far")
	t.check_approx(agg["flee"], 0.10, "blend: aggressor flees at 10%")
	var opp: Dictionary = DriverScript.blend_params(Vector3(0, 0, 1))
	t.check_approx(opp["near"], 260.0, "blend: opportunist near")
	t.check_approx(opp["flee"], 0.35, "blend: opportunist flees at 35%")
	t.check_approx(opp["w_weak"], 1.0, "blend: opportunist hunts the weak")

func test_blend_hybrid_interpolates() -> void:
	var p: Dictionary = DriverScript.blend_params(Vector3(1, 1, 0))  # 50/50 agg+amb
	t.check_approx(p["near"], 135.0, "blend: hybrid near is the midpoint")
	t.check_approx(p["flee"], 0.16, "blend: hybrid flee is the midpoint")
	t.check_approx(p["flank"], 0.5, "blend: hybrid flank bias halves")

func test_blend_zero_mix_falls_back_to_aggressor() -> void:
	var p: Dictionary = DriverScript.blend_params(Vector3.ZERO)
	t.check_approx(p["near"], 110.0, "blend: zero mix = pure aggressor")

func test_stuck_trips_after_sustained_stall() -> void:
	var d = DriverScript.new()
	t.check(not d._update_stuck(10.0, true, 0.3), "stuck: not yet at 0.3s")
	t.check(d._update_stuck(10.0, true, 0.35), "stuck: trips past 0.6s")
	t.check(not d._update_stuck(10.0, true, 0.3), "stuck: timer reset after tripping")
	d.free()

func test_stuck_resets_when_moving_or_idle() -> void:
	var d = DriverScript.new()
	d._update_stuck(10.0, true, 0.5)
	t.check(not d._update_stuck(300.0, true, 0.35), "stuck: moving fast resets the timer")
	d._update_stuck(10.0, true, 0.5)
	t.check(not d._update_stuck(10.0, false, 0.35), "stuck: idle throttle resets the timer")
	d.free()

func test_dying_ai_still_gets_targeted() -> void:
	# Immunity lives in Vehicle.combat_scale, NOT targeting — the theatrics
	# (AI shooting a nearly-dead AI) must keep happening.
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var dying_ai := _car(rig[0], Vector2(100, 0), 0.05)
	var _healthy_ai := _car(rig[0], Vector2(900, 0), 1.0)
	t.check(driver._select_target(rig[1]) == dying_ai, "targeting: dying AI is still a target (w_weak even prefers it)")
	t.check(driver._nearest_any(rig[1]) == dying_ai, "targeting: hunt fallback ignores hp")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_freed_grudge_is_ignored() -> void:
	# A killed attacker leaves a freed instance in last_attacker; targeting
	# must shrug it off (regression: typed assignment of a freed ref errors).
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var victim := _car(rig[0], Vector2(400, 0), 1.0)
	var attacker := _car(rig[0], Vector2(800, 0), 1.0)
	rig[1].last_attacker = attacker
	rig[0].remove_child(attacker)
	attacker.free()
	t.check(driver._select_target(rig[1]) == victim, "grudge: freed attacker ignored, targeting continues")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_player_priority_breaks_near_ties() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var _ai := _car(rig[0], Vector2(500, 0), 1.0)
	var player := _car(rig[0], Vector2(650, 0), 1.0, true)
	t.check(driver._select_target(rig[1]) == player, "priority: player wins over a slightly nearer AI")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_unstick_intent_reverses_with_inverted_steer() -> void:
	var d = DriverScript.new()
	d._avoid_bias = 0.8  # blocked on the left -> escape steers right (pre-inversion)
	d._enter_unstick(0.0, 0.0)
	var intent: Dictionary = d._unstick_intent()
	t.check_approx(intent["throttle"], -1.0, "unstick: full reverse")
	t.check_approx(intent["steer"], -0.8, "unstick: steer inverted for reversing")
	t.check(not intent["fire_mg"], "unstick: holds fire")
	d._avoid_bias = 0.0  # nothing blocked -> swing toward the target bearing
	d._enter_unstick(0.0, 1.0)
	t.check_approx(d._unstick_intent()["steer"], -1.0, "unstick: falls back to target bearing")
	d._avoid_bias = -0.9  # commit holds even if the feelers flip afterward
	t.check_approx(d._unstick_intent()["steer"], -1.0, "unstick: escape swing stays committed")
	d.free()
