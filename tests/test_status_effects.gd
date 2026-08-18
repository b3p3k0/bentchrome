extends RefCounted
## Status-effect framework tests (burn / slow / invuln: tick, refresh, expiry).
## Driven by tests/run_tests.gd, which calls every test_* method.

const HealthScript := preload("res://vehicles/health.gd")
const ReceiverScript := preload("res://vehicles/status_receiver.gd")
const SpecScript := preload("res://resources/status_effect.gd")

var t  # the runner: check()/check_approx() helpers + root access

func _init(runner) -> void:
	t = runner

func _fixture(with_health := true) -> Dictionary:
	var parent := Node.new()
	if with_health:
		var health: Node = HealthScript.new()
		health.name = "Health"  # StatusReceiver looks up its sibling by this literal name
		parent.add_child(health)
	var status: Node = ReceiverScript.new()
	status.name = "Status"
	parent.add_child(status)
	t.root.add_child(parent)  # _ready/@onready fire here (hp = max_hp, _health wired)
	status.set_physics_process(false)  # tests own time via manual tick()
	return {"parent": parent, "health": parent.get_node_or_null("Health"), "status": status}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.parent)
	f.parent.free()  # immediate free keeps exit output orphan-free

func _spec(kind: StringName, duration: float, magnitude := 1.0) -> StatusEffectSpec:
	var s: StatusEffectSpec = SpecScript.new()
	s.kind = kind
	s.duration = duration
	s.magnitude = magnitude
	return s

## Regression: an active burn must not follow the player into their next life.
func test_respawn_clears_effects() -> void:
	var car = preload("res://vehicles/vehicle.tscn").instantiate()
	t.root.add_child(car)
	car.apply_effect(_spec(&"burn", 10.0, 4.0))
	t.check(car.is_burning(), "respawn-clear: burn active before death")
	car.respawn(Vector2.ZERO, 0.0, 2.0)
	t.check(not car.is_burning(), "respawn-clear: burn gone after respawn")
	t.check(car.get_node("Health").invulnerable or car.get_node("Status").has_effect(&"invuln"),
		"respawn-clear: fresh shield survives the clear")
	t.root.remove_child(car)
	car.free()

func test_fixture_ready() -> void:
	var f := _fixture()
	t.check_approx(f.health.hp, 100.0, "fixture: hp initialized by _ready")
	t.check_approx(f.status.speed_scale(), 1.0, "fixture: neutral speed scale")
	_done(f)

func test_burn_ticks_damage() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"burn", 3.0, 10.0))
	f.status.tick(0.5)
	t.check_approx(f.health.hp, 95.0, "burn: 10 dps * 0.5s")
	f.status.tick(0.5)
	t.check_approx(f.health.hp, 90.0, "burn: second tick")
	_done(f)

func test_burn_expires() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"burn", 1.0, 10.0))
	f.status.tick(1.0)
	t.check_approx(f.health.hp, 90.0, "burn: full duration ticked")
	f.status.tick(1.0)
	t.check_approx(f.health.hp, 90.0, "burn: expired, no further damage")
	_done(f)

func test_slow_speed_scale() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"slow", 2.0, 0.5))
	t.check_approx(f.status.speed_scale(), 0.5, "slow: speed scale halved")
	_done(f)

func test_slow_refresh_overwrites() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"slow", 2.0, 0.5))
	f.status.apply(_spec(&"slow", 1.0, 0.8))
	t.check_approx(f.status.speed_scale(), 0.8, "slow: same-kind refresh overwrites magnitude")
	f.status.tick(1.5)
	t.check_approx(f.status.speed_scale(), 0.8, "slow: refresh kept the longer remaining")
	f.status.tick(0.6)
	t.check_approx(f.status.speed_scale(), 1.0, "slow: expired, scale back to neutral")
	_done(f)

## refresh = false (Chilblain / Chill Out): a same-kind re-application while
## active is ignored outright — no extension, no magnitude overwrite — but a
## fresh application after expiry lands normally.
func test_no_refresh_flag_ignores_reapply() -> void:
	var f := _fixture()
	var first := _spec(&"slow", 3.0, 0.5)
	first.refresh = false
	f.status.apply(first)
	var again := _spec(&"slow", 10.0, 0.8)
	again.refresh = false
	f.status.apply(again)
	t.check_approx(f.status.speed_scale(), 0.5, "no-refresh: magnitude never overwritten")
	f.status.tick(3.1)
	t.check_approx(f.status.speed_scale(), 1.0, "no-refresh: original duration held, never extended")
	f.status.apply(again)
	t.check_approx(f.status.speed_scale(), 0.8, "no-refresh: post-expiry application lands")
	_done(f)

func test_invuln_blocks_damage() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"invuln", 1.0))
	f.status.tick(0.1)  # the flag is set by tick(), not apply()
	t.check(f.health.invulnerable, "invuln: flag set after tick")
	f.health.take_damage(50.0)
	t.check_approx(f.health.hp, 100.0, "invuln: damage blocked")
	f.status.tick(1.0)  # remaining 0.9 -> expired
	t.check(not f.health.invulnerable, "invuln: flag cleared on expiry")
	f.health.take_damage(30.0)
	t.check_approx(f.health.hp, 70.0, "invuln: damage lands after expiry")
	_done(f)

func test_refresh_extends_and_updates_magnitude() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"burn", 3.0, 10.0))
	f.status.apply(_spec(&"burn", 1.0, 2.0))  # remaining stays 3.0 (maxf), magnitude -> 2
	f.status.tick(2.0)
	t.check_approx(f.health.hp, 96.0, "refresh: new magnitude used (2 dps * 2s)")
	f.status.tick(0.5)
	t.check_approx(f.health.hp, 95.0, "refresh: duration never shortened")
	_done(f)

func test_clear_resets_everything() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"burn", 3.0, 10.0))
	f.status.apply(_spec(&"slow", 2.0, 0.5))
	f.status.apply(_spec(&"invuln", 2.0))
	f.status.tick(0.1)  # invuln flag sets at end of tick, so this burn tick lands
	t.check_approx(f.health.hp, 99.0, "clear: pre-clear burn tick landed")
	f.status.clear()
	t.check_approx(f.status.speed_scale(), 1.0, "clear: speed scale reset")
	t.check(not f.health.invulnerable, "clear: invulnerable reset")
	f.health.take_damage(10.0)
	t.check_approx(f.health.hp, 89.0, "clear: damage lands after clear")
	_done(f)

func test_clear_kind_targets_one_effect() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"burn", 5.0, 10.0))
	f.status.apply(_spec(&"slow", 5.0, 0.5))
	t.check(f.status.has_effect(&"burn"), "clear_kind: burn active before")
	f.status.clear_kind(&"burn")  # the boost-extinguish path
	t.check(not f.status.has_effect(&"burn"), "clear_kind: burn extinguished")
	t.check_approx(f.status.speed_scale(), 0.5, "clear_kind: slow untouched")
	_done(f)

func test_water_extinguishes_burn() -> void:
	var car = preload("res://vehicles/vehicle.tscn").instantiate()
	t.root.add_child(car)
	car.apply_effect(_spec(&"burn", 10.0, 4.0))
	car.get_node("TerrainSensor").current_terrain = &"water"
	# SceneTree's physics-frame signal resumes before node physics callbacks;
	# the second frame observes Vehicle consuming the sensor's wet surface.
	for i in 2:
		await t.physics_frame
	t.check(car.current_terrain == &"water", "water-extinguish: vehicle reads the wet surface")
	t.check(not car.is_burning(), "water-extinguish: shallow water douses hull fire")
	t.root.remove_child(car)
	car.free()

func test_stun_holds_then_expires() -> void:
	var f := _fixture()
	f.status.apply(_spec(&"stun", 0.5))
	t.check(f.status.is_stunned(), "stun: active after apply")
	f.status.tick(0.6)
	t.check(not f.status.is_stunned(), "stun: expired after its duration")
	_done(f)

## The vehicle-level gate: a stunned car ignores its driver entirely — full
## throttle from the stub moves nothing until the stun expires.
func test_stun_cuts_driver_intent() -> void:
	var car = preload("res://vehicles/vehicle.tscn").instantiate()
	var old_driver = car.get_node("Driver")
	car.remove_child(old_driver)
	old_driver.free()
	var stub = preload("res://tests/stub_driver.gd").new()
	stub.name = "Driver"
	car.add_child(stub)
	t.root.add_child(car)
	stub.intent = {"throttle": 1.0}
	car.apply_effect(_spec(&"stun", 10.0))
	for i in 8:
		await t.physics_frame
	t.check(car.velocity.length() < 5.0, "stun: full throttle moves nothing (%.0f px/s)" % car.velocity.length())
	car.get_node("Status").clear_kind(&"stun")
	for i in 8:
		await t.physics_frame
	t.check(car.velocity.length() > 20.0, "stun cleared: throttle bites again")
	t.root.remove_child(car)
	car.free()

## The heavyweight hit reaction: flung from the impact point, spun, billed,
## and stunned in one call.
func test_apply_impact_flings_spins_stuns() -> void:
	var car = preload("res://vehicles/vehicle.tscn").instantiate()
	t.root.add_child(car)
	car.global_position = Vector2(100, 0)
	var heading_before: float = car.heading
	var hp_before: float = car.get_node("Health").hp
	car.apply_impact(Vector2.ZERO, 26.0, 900.0, deg_to_rad(140.0), 0.5)
	t.check(car.velocity.x > 800.0, "impact: flung away from the impact point")
	t.check(absf(angle_difference(heading_before, car.heading)) > deg_to_rad(90.0),
		"impact: spun hard off heading")
	t.check_approx(car.get_node("Health").hp, hp_before - 26.0, "impact: damage billed")
	t.check(car.get_node("Status").is_stunned(), "impact: stunned")
	t.root.remove_child(car)
	car.free()

func test_no_health_sibling_no_crash() -> void:
	var f := _fixture(false)
	f.status.apply(_spec(&"burn", 1.0, 10.0))
	f.status.tick(1.0)
	t.check_approx(f.status.speed_scale(), 1.0, "no Health sibling: still queryable, no crash")
	_done(f)
