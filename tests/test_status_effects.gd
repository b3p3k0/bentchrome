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

func test_no_health_sibling_no_crash() -> void:
	var f := _fixture(false)
	f.status.apply(_spec(&"burn", 1.0, 10.0))
	f.status.tick(1.0)
	t.check_approx(f.status.speed_scale(), 1.0, "no Health sibling: still queryable, no crash")
	_done(f)
