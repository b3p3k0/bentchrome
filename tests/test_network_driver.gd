extends RefCounted
## NetworkDriver + the intent-frame codec: hold-last across gaps, stale-tick
## drops, exactly-once weapon cycling (dedupe + one edge per tick), and the
## 7-byte round-trip that refuses junk.

const ND := preload("res://vehicles/drivers/network_driver.gd")
const Snap := preload("res://game/net/net_snapshot.gd")

var t

func _init(runner) -> void:
	t = runner

func test_codec_round_trip() -> void:
	var intent := {"throttle": -0.62, "steer": 1.0, "fire_mg": true,
		"fire_selected": false, "handbrake": true, "boost": false}
	var bytes: PackedByteArray = Snap.pack_input(41, intent)
	t.check(bytes.size() == Snap.INPUT_FRAME_SIZE, "codec: frame is 7 bytes")
	var back: Dictionary = Snap.unpack_input(bytes)
	t.check(int(back.tick) == 41, "codec: tick survives")
	t.check(absf(float(back.throttle) + 0.62) < 0.011, "codec: negative axis survives")
	t.check(is_equal_approx(float(back.steer), 1.0), "codec: full-lock steer survives")
	t.check(back.fire_mg and back.handbrake and not back.fire_selected and not back.boost,
		"codec: button bits survive")
	t.check(not back.weapon_prev and not back.weapon_next,
		"codec: edges never ride the unreliable frame")
	t.check(Snap.unpack_input(PackedByteArray([1, 2, 3])).is_empty(),
		"codec: junk sizes parse to nothing")

func test_hold_last_and_stale_drop() -> void:
	var d = ND.new()
	d.feed_frame(Snap.unpack_input(Snap.pack_input(5, {"throttle": 0.8, "boost": true})))
	var a: Dictionary = d.get_intent(null, 0.016)
	t.check(is_equal_approx(float(a.throttle), 0.8) and a.boost,
		"driver: replays the newest frame")
	var b: Dictionary = d.get_intent(null, 0.016)
	t.check(is_equal_approx(float(b.throttle), 0.8) and b.boost,
		"driver: a gap holds the last frame — held triggers stay held")
	d.feed_frame(Snap.unpack_input(Snap.pack_input(3, {"throttle": -1.0})))
	var c: Dictionary = d.get_intent(null, 0.016)
	t.check(is_equal_approx(float(c.throttle), 0.8),
		"driver: a stale tick (out-of-order arrival) is ignored")
	d.feed_frame(Snap.unpack_input(Snap.pack_input(6, {"throttle": 0.0})))
	var e: Dictionary = d.get_intent(null, 0.016)
	t.check(is_equal_approx(float(e.throttle), 0.0), "driver: newer tick applies")
	d.free()  # Driver is a Node — RefCounted rules don't apply

func test_weapon_cycle_exactly_once() -> void:
	var d = ND.new()
	d.feed_cycle(1, 1)
	d.feed_cycle(2, 1)
	d.feed_cycle(2, 1)   # hostile replay of a used seq
	d.feed_cycle(3, -1)
	d.feed_cycle(1, -1)  # ancient seq
	var first: Dictionary = d.get_intent(null, 0.016)
	t.check(first.weapon_next and not first.weapon_prev, "cycle: first edge fires next")
	var second: Dictionary = d.get_intent(null, 0.016)
	t.check(second.weapon_next, "cycle: queued edges drain one per tick")
	var third: Dictionary = d.get_intent(null, 0.016)
	t.check(third.weapon_prev and not third.weapon_next, "cycle: direction preserved in order")
	var fourth: Dictionary = d.get_intent(null, 0.016)
	t.check(not fourth.weapon_prev and not fourth.weapon_next,
		"cycle: replayed/stale seqs never double-fire — queue drains to quiet")
	d.free()