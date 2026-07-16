extends RefCounted
## EnemyDriver logic tests: archetype mix blending, stuck detection, and the
## unstick escape intent. Pure logic only — feeler raycasts are HI-verified.

const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

var t

## Minimal stand-in for targeting tests: position + hp fraction + groups.
class FakeCar extends Node2D:
	var hpf := 1.0
	var last_attacker: Node2D = null
	var last_attacker_ms := 0
	var heading := 0.0
	var hops: Array = []  # escape_hop directions received
	func get_hp_fraction() -> float:
		return hpf
	func get_hp() -> float:
		return hpf * 100.0
	func escape_hop(dir: Vector2) -> void:
		hops.append(dir)

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

func test_runtime_mix_refreshes_cached_traits() -> void:
	var d = DriverScript.new()
	d.mix = Vector3(0, 0, 1)
	t.check_approx(d._near, 260.0, "runtime mix: opportunist near refreshes after assignment")
	t.check_approx(d._flee, 0.35, "runtime mix: opportunist flee refreshes after assignment")
	t.check_approx(d._w_weak, 1.0, "runtime mix: opportunist targeting refreshes after assignment")
	d.mix = Vector3(0, 1, 0)
	t.check_approx(d._flank, 1.0, "runtime mix: a second assignment refreshes flank")
	d.free()

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

func test_target_commitment_and_switch_margin() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var first := _car(rig[0], Vector2(500, 0), 1.0)
	var challenger := _car(rig[0], Vector2(900, 0), 1.0)
	t.check(driver._select_target(rig[1], 0.0) == first, "commit: nearest target adopted")
	challenger.global_position = Vector2(450, 0)  # a tiny lead, below the switch margin
	t.check(driver._select_target(rig[1], DriverScript.TARGET_COMMIT_TIME) == first,
		"commit: near-tie challenger cannot turn the car")
	challenger.global_position = Vector2(100, 0)  # a meaningful score win
	t.check(driver._select_target(rig[1], DriverScript.TARGET_REEVAL_TIME) == challenger,
		"commit: meaningful challenger wins after reevaluation")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_revenge_expires() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var near := _car(rig[0], Vector2(300, 0), 1.0)
	var attacker := _car(rig[0], Vector2(700, 0), 1.0)
	rig[1].last_attacker = attacker
	rig[1].last_attacker_ms = Time.get_ticks_msec()
	t.check(driver._best_target(rig[1]) == attacker, "revenge: fresh attacker wins the score")
	rig[1].last_attacker_ms = Time.get_ticks_msec() - int((DriverScript.REVENGE_WINDOW + 1.0) * 1000.0)
	t.check(driver._best_target(rig[1]) == near, "revenge: expired attacker loses to the nearer fight")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_invalid_committed_target_replaced_immediately() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var first := _car(rig[0], Vector2(100, 0), 1.0)
	var live := _car(rig[0], Vector2(800, 0), 1.0)
	t.check(driver._select_target(rig[1], 0.0) == first, "invalid target: first rival committed")
	first.hpf = 0.0
	t.check(driver._select_target(rig[1], 0.01) == live,
		"invalid target: dead rival bypasses commitment immediately")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_carpin_classification_sets_shun() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var elk := _car(rig[0], Vector2(80, 0), 1.0)
	# Clear feelers + vehicle in contact range = car-pin -> shun.
	driver._blocked = false
	driver._classify_car_pin(elk, 80.0)
	t.check(driver._shun_target == elk and driver._shun_t > 0.0, "carpin: contact deadlock shuns the elk")
	# Wall-pin (blocked feelers) must NOT shun.
	var driver2 = DriverScript.new()
	driver2._blocked = true
	driver2._classify_car_pin(elk, 80.0)
	t.check(driver2._shun_target == null, "carpin: blocked feelers = wall pin, no shun")
	# The player is exempt — boss shoving matches are gameplay.
	var player := _car(rig[0], Vector2(60, 0), 1.0, true)
	var driver3 = DriverScript.new()
	driver3._classify_car_pin(player, 60.0)
	t.check(driver3._shun_target == null, "carpin: player contact never shuns")
	# Out of contact range: not a pin.
	var driver4 = DriverScript.new()
	driver4._classify_car_pin(elk, 400.0)
	t.check(driver4._shun_target == null, "carpin: distant target is not a car-pin")
	driver.free()
	driver2.free()
	driver3.free()
	driver4.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_shunned_target_skipped_with_fallback() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var elk := _car(rig[0], Vector2(100, 0), 1.0)
	var other := _car(rig[0], Vector2(900, 0), 1.0)
	driver._shun_target = elk
	driver._shun_t = 4.0
	t.check(driver._select_target(rig[1]) == other, "shun: scored targeting skips the elk")
	t.check(driver._nearest_any(rig[1]) == other, "shun: hunt fallback skips the elk")
	# Elk is the ONLY combatant: shun yields to no-camping.
	rig[0].remove_child(other)
	other.free()
	t.check(driver._nearest_any(rig[1]) == elk, "shun: only combatant left overrides the shun")
	# Expiry restores normal targeting.
	driver._shun_t = 0.0
	t.check(driver._select_target(rig[1]) == elk, "shun: expired shun targets normally")
	driver.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_repeat_pin_earns_the_hop() -> void:
	var rig := _targeting_rig()
	var driver = DriverScript.new()
	var stuck_car: FakeCar = rig[1]
	var target := _car(rig[0], Vector2(300, 0), 1.0)
	# First trip at this spot: normal reverse-out, no hop.
	var intent: Dictionary = driver._on_stuck(stuck_car, target, 0.0)
	t.check(stuck_car.hops.is_empty(), "hop: first pin reverses, no hop")
	t.check_approx(intent["throttle"], -1.0, "hop: first pin is the normal unstick")
	# Second trip at the same spot: hop over it, toward the fight.
	intent = driver._on_stuck(stuck_car, target, 0.0)
	t.check(stuck_car.hops.size() == 1, "hop: second same-spot pin hops")
	t.check(stuck_car.hops[0].dot(Vector2.RIGHT) > 0.9, "hop: launched toward the target")
	t.check_approx(intent["throttle"], 1.0, "hop: lands driving forward (CLEAR)")
	t.check(driver._hop_cd > 0.0, "hop: cooldown armed")
	# Third trip while cooling down: back to reversing, no pogo.
	intent = driver._on_stuck(stuck_car, target, 0.0)
	t.check(stuck_car.hops.size() == 1, "hop: cooldown blocks a pogo chain")
	# A pin far away resets the repeat counter.
	var driver2 = DriverScript.new()
	driver2._on_stuck(stuck_car, target, 0.0)
	stuck_car.global_position = Vector2(2000, 0)
	driver2._on_stuck(stuck_car, target, 0.0)
	t.check(stuck_car.hops.size() == 1, "hop: a distant pin starts a fresh count")
	driver.free()
	driver2.free()
	t.root.remove_child(rig[0])
	rig[0].free()

func test_boss_break_scales_with_dominance() -> void:
	var driver = DriverScript.new()
	driver.relentless = true
	var boss := FakeCar.new()
	var player := FakeCar.new()
	# Full dominance (player untouched, boss on fumes): minimum mercy.
	boss.hpf = 0.0
	player.hpf = 1.0
	var pressed: float = driver._boss_break_time(boss, player)
	t.check(is_equal_approx(pressed, DriverScript.BOSS_BREAK_MIN),
		"boss valve: dominant player gets the min breather (%.2f)" % pressed)
	# Fully outmatched (player on fumes, boss untouched): maximum window.
	boss.hpf = 1.0
	player.hpf = 0.0
	var mercy: float = driver._boss_break_time(boss, player)
	t.check(is_equal_approx(mercy, DriverScript.BOSS_BREAK_MAX),
		"boss valve: losing player gets the max breather (%.2f)" % mercy)
	# Even fight: in between.
	boss.hpf = 0.6
	player.hpf = 0.6
	var mid: float = driver._boss_break_time(boss, player)
	t.check(mid > pressed and mid < mercy, "boss valve: even fight lands between")
	# Entering the break arms RELENT with the scaled timer.
	driver._enter_boss_break(boss, player)
	t.check(driver._mode == DriverScript.Mode.RELENT, "boss valve: break-off uses RELENT drive")
	t.check(driver._relent_t > 0.0, "boss valve: breather timer armed")
	boss.free()
	player.free()
	driver.free()

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
