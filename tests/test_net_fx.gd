extends RefCounted
## The reliable FX plane's plumbing: the NetEvents fx queue is armed-gated and
## drains clean, mine ids only mint while armed, and a cosmetic mine twin
## draws and arms without ever sensing or billing anyone.

const NetEventsTap := preload("res://game/net/net_events.gd")
const MineScene := preload("res://environment/mine_land.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_fx_queue_gating_and_drain() -> void:
	NetEventsTap.reset()
	var a := Node2D.new()
	var b := Node2D.new()
	NetEventsTap.beam_on(a, b)
	NetEventsTap.pulse(Vector2(10, 10), 300.0, 0.5)
	t.check(NetEventsTap.drain_fx().is_empty(), "fx: disarmed tap swallows everything")
	t.check(NetEventsTap.next_mine_id() == 0, "fx: disarmed mine ids stay 0 (no event)")

	NetEventsTap.armed = true
	NetEventsTap.beam_on(a, b)
	NetEventsTap.beam_off(a)
	NetEventsTap.pulse(Vector2(5, 5), 270.0, 0.4)
	var id_one := NetEventsTap.next_mine_id()
	var id_two := NetEventsTap.next_mine_id()
	t.check(id_one == 1 and id_two == 2, "fx: mine ids mint sequentially while armed")
	NetEventsTap.mine_drop(id_one, "res://environment/mine_land.tscn",
		Vector2(50, 60), 2, false)
	NetEventsTap.mine_clear(id_one, true, Vector2(50, 60), false)
	NetEventsTap.mine_drop(0, "res://environment/mine_land.tscn", Vector2.ZERO, -1, false)
	var out: Array = NetEventsTap.drain_fx()
	t.check(out.size() == 5, "fx: five armed events queued, the id-0 mine skipped")
	t.check(StringName(out[0].kind) == &"beam_on" and out[0].shooter == a and out[0].target == b,
		"fx: beam_on carries its nodes for drain-time resolution")
	t.check(StringName(out[1].kind) == &"beam_off", "fx: beam_off follows")
	t.check(StringName(out[2].kind) == &"pulse" and is_equal_approx(float(out[2].range), 270.0),
		"fx: pulse carries range and duration")
	t.check(int(out[3].id) == id_one and int(out[3].floor) == 2 and not bool(out[3].jump),
		"fx: mine_drop carries id/path/floor/kind")
	t.check(StringName(out[4].kind) == &"mine_clear" and bool(out[4].exploded),
		"fx: mine_clear carries the boom")
	t.check(NetEventsTap.drain_fx().is_empty(), "fx: drain empties the plane")
	NetEventsTap.reset()
	a.free()
	b.free()

func test_cosmetic_mine_is_inert() -> void:
	var twin: Area2D = MineScene.instantiate()
	twin.set("cosmetic", true)
	t.root.add_child(twin)
	t.check(twin.collision_mask == 0, "mine twin: senses nothing (mask stays zero)")
	# Tick well past ARM_DELAY: a live mine would scan; a twin just blinks on.
	for i in 80:
		twin._physics_process(1.0 / 60.0)
	t.check(is_instance_valid(twin) and not twin.is_queued_for_deletion(),
		"mine twin: arms and sits — never triggers, never frees itself")
	t.check(float(twin._age) > 1.0, "mine twin: the arm blink still runs on local age")
	t.root.remove_child(twin)
	twin.free()