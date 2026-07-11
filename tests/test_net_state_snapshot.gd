extends RefCounted
## The state-snapshot wire format: rows round-trip within quantization
## tolerance, flags survive as booleans, events carry their spawn orders,
## and junk parses to nothing. A format change that breaks these = a
## PROTOCOL_VERSION bump, on purpose.

const Snap := preload("res://game/net/net_snapshot.gd")

var t

func _init(runner) -> void:
	t = runner

func _row_a() -> Dictionary:
	return {
		"pos": Vector2(-1234, 2500), "vel": Vector2(410, -220),
		"heading": 2.35, "height": 42.0, "floor": 2, "hp": 87.5,
		"alive": true, "boost": true, "handbrake": false, "brake": true, "burn": true,
		"shield": false, "mg_locked": true,
		"heat": 0.66, "boost_fuel": 73.0, "slot": 3,
		"ammo": [2, 5, 0, 1, 4, 3, 0], "recharge": 0.4,
	}

func test_rows_round_trip() -> void:
	var dead := {"alive": false, "hp": 0.0}
	var bytes: PackedByteArray = Snap.pack_snapshot(99, [_row_a(), dead], [])
	var back: Dictionary = Snap.unpack_snapshot(bytes)
	t.check(not back.is_empty() and int(back.tick) == 99, "snap: header survives")
	t.check(back.rows.size() == 2, "snap: row count survives")
	var a: Dictionary = back.rows[0]
	t.check(a.pos == Vector2(-1234, 2500), "snap: position exact at 1px")
	t.check(a.vel == Vector2(410, -220), "snap: velocity exact at 1px/s")
	t.check(absf(float(a.heading) - 2.35) < 0.001, "snap: heading within u16 grain")
	t.check(is_equal_approx(float(a.hp), 87.5), "snap: hp keeps 0.1 precision")
	t.check(int(a.floor) == 2 and is_equal_approx(float(a.height), 42.0),
		"snap: floor and height survive")
	t.check(a.alive and a.boost and a.burn and a.mg_locked
			and a.brake and not a.handbrake and not a.shield, "snap: flag bits survive")
	t.check(absf(float(a.heat) - 0.66) < 0.005 and is_equal_approx(float(a.boost_fuel), 73.0),
		"snap: HUD mirrors survive")
	t.check(int(a.slot) == 3 and a.ammo == [2, 5, 0, 1, 4, 3, 0],
		"snap: rack mirror survives")
	t.check(absf(float(a.recharge) - 0.4) < 0.005, "snap: recharge survives")
	var d: Dictionary = back.rows[1]
	t.check(not d.alive and float(d.hp) == 0.0, "snap: dead rows stay dead")

func test_events_round_trip() -> void:
	var ev := {
		"path": "res://weapons/missile.tscn", "pos": Vector2(100, -50),
		"dir": Vector2.RIGHT.rotated(1.1), "speed": 900.0,
		"lifetime": 2.4, "turn_rate": 3.5, "target_actor": 2,
	}
	var back: Dictionary = Snap.unpack_snapshot(Snap.pack_snapshot(7, [], [ev]))
	t.check(back.events.size() == 1, "snap: event count survives")
	var e: Dictionary = back.events[0]
	t.check(String(e.path) == "res://weapons/missile.tscn", "snap: scene path survives")
	t.check(e.pos == Vector2(100, -50), "snap: event origin survives")
	t.check(absf((e.dir as Vector2).angle() - 1.1) < 0.001, "snap: direction survives")
	t.check(is_equal_approx(float(e.speed), 900.0), "snap: speed survives")
	t.check(absf(float(e.lifetime) - 2.4) < 0.002, "snap: lifetime survives")
	t.check(absf(float(e.turn_rate) - 3.5) < 0.002, "snap: homing rate survives")
	t.check(int(e.target_actor) == 2, "snap: target actor survives")

func test_junk_rejected() -> void:
	t.check(Snap.unpack_snapshot(PackedByteArray([9, 9])).is_empty(),
		"snap: truncated header parses to nothing")
	var good: PackedByteArray = Snap.pack_snapshot(1, [_row_a()], [])
	good[0] = 250  # wrong protocol byte
	t.check(Snap.unpack_snapshot(good).is_empty(), "snap: wrong proto rejected")
	var cut: PackedByteArray = Snap.pack_snapshot(1, [_row_a()], []).slice(0, 12)
	t.check(Snap.unpack_snapshot(cut).is_empty(), "snap: truncated row rejected")
