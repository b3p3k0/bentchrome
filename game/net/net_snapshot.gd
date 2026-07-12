class_name NetSnapshot
extends RefCounted
## Wire codecs — StreamPeerBuffer over var_to_bytes for explicit byte widths,
## no per-element Variant tags, and testable round-trips. Two payloads: the
## client->host INTENT FRAME (7 bytes @ 60Hz) and the host->all STATE
## SNAPSHOT (~25 bytes/car + events @ snapshot_hz). Rows ride in fixed actor
## order — the seat table IS the index, no per-row ids. Format changes bump
## NetProtocol.PROTOCOL_VERSION.

const Proto := preload("res://game/net/net_protocol.gd")

# Row flags — puppet-facing state bits.
const F_ALIVE := 1
const F_BOOST := 2
const F_HANDBRAKE := 4
const F_BURN := 8
const F_SHIELD := 16
const F_MG_LOCKED := 32
const F_BRAKE := 64

const AMMO_SLOTS := 7  # WeaponRack's fixed loadout width
const EV_PROJECTILE := 1
const EV_HIT := 2
const EV_IMPACT := 3
const NO_TARGET := 255

const INPUT_FRAME_SIZE := 7  # u32 tick | i8 throttle | i8 steer | u8 buttons

const BTN_FIRE_MG := 1
const BTN_FIRE_SELECTED := 2
const BTN_HANDBRAKE := 4
const BTN_BOOST := 8

## Intent axes quantize to i8 hundredths — analog sticks keep their feel.
static func pack_input(tick: int, intent: Dictionary) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(tick)
	buf.put_8(int(clampf(float(intent.get("throttle", 0.0)), -1.0, 1.0) * 100.0))
	buf.put_8(int(clampf(float(intent.get("steer", 0.0)), -1.0, 1.0) * 100.0))
	var buttons := 0
	if intent.get("fire_mg", false):
		buttons |= BTN_FIRE_MG
	if intent.get("fire_selected", false):
		buttons |= BTN_FIRE_SELECTED
	if intent.get("handbrake", false):
		buttons |= BTN_HANDBRAKE
	if intent.get("boost", false):
		buttons |= BTN_BOOST
	buf.put_u8(buttons)
	return buf.data_array

## {} on junk — a fuzzed frame must parse to nothing, never to half a frame.
## weapon_prev/next are always false here: edges ride the reliable plane.
static func unpack_input(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != INPUT_FRAME_SIZE:
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var tick := buf.get_u32()
	var throttle := clampf(buf.get_8() / 100.0, -1.0, 1.0)
	var steer := clampf(buf.get_8() / 100.0, -1.0, 1.0)
	var buttons := buf.get_u8()
	return {
		"tick": tick,
		"throttle": throttle,
		"steer": steer,
		"fire_mg": (buttons & BTN_FIRE_MG) != 0,
		"fire_selected": (buttons & BTN_FIRE_SELECTED) != 0,
		"handbrake": (buttons & BTN_HANDBRAKE) != 0,
		"boost": (buttons & BTN_BOOST) != 0,
		"weapon_prev": false,
		"weapon_next": false,
	}

# ------------------------------------------------------------ state snapshot

## rows: one Dictionary per actor, fixed order. events: NetEvents drainage
## with targets already resolved to actor indices (NO_TARGET = none).
static func pack_snapshot(tick: int, rows: Array, events: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(Proto.PROTOCOL_VERSION)
	buf.put_u32(tick)
	buf.put_u8(rows.size())
	for row in rows:
		var flags := 0
		if row.get("alive", true):
			flags |= F_ALIVE
		if row.get("boost", false):
			flags |= F_BOOST
		if row.get("handbrake", false):
			flags |= F_HANDBRAKE
		if row.get("burn", false):
			flags |= F_BURN
		if row.get("shield", false):
			flags |= F_SHIELD
		if row.get("mg_locked", false):
			flags |= F_MG_LOCKED
		if row.get("brake", false):
			flags |= F_BRAKE
		buf.put_u8(flags)
		buf.put_8(int(row.get("floor", -1)))
		var pos: Vector2 = row.get("pos", Vector2.ZERO)
		buf.put_16(clampi(roundi(pos.x), -32768, 32767))
		buf.put_16(clampi(roundi(pos.y), -32768, 32767))
		buf.put_u16(int(wrapf(float(row.get("heading", 0.0)), 0.0, TAU) / TAU * 65535.0))
		var vel: Vector2 = row.get("vel", Vector2.ZERO)
		buf.put_16(clampi(roundi(vel.x), -32768, 32767))
		buf.put_16(clampi(roundi(vel.y), -32768, 32767))
		buf.put_u16(clampi(roundi(float(row.get("hp", 0.0)) * 10.0), 0, 65535))
		buf.put_u8(clampi(roundi(float(row.get("height", 0.0))), 0, 255))
		buf.put_u8(clampi(roundi(float(row.get("heat", 0.0)) * 255.0), 0, 255))
		buf.put_u8(clampi(roundi(float(row.get("boost_fuel", 0.0))), 0, 255))
		buf.put_u8(clampi(int(row.get("slot", 0)), 0, 255))
		var ammo: Array = row.get("ammo", [])
		for i in AMMO_SLOTS:
			buf.put_u8(clampi(int(ammo[i]) if i < ammo.size() else 0, 0, 255))
		buf.put_u8(clampi(roundi(float(row.get("recharge", 1.0)) * 255.0), 0, 255))
	buf.put_u8(mini(events.size(), 255))
	for i in mini(events.size(), 255):
		var ev: Dictionary = events[i]
		var kind: StringName = ev.get("kind", &"projectile")
		if kind == &"hit":
			buf.put_u8(EV_HIT)
			buf.put_u8(clampi(int(ev.get("attacker_actor", NO_TARGET)), 0, 255))
			buf.put_u8(clampi(int(ev.get("victim_actor", NO_TARGET)), 0, 255))
		elif kind == &"impact":
			buf.put_u8(EV_IMPACT)
			buf.put_u32(int(ev.get("shot_id", 0)))
			var impact_pos: Vector2 = ev.get("pos", Vector2.ZERO)
			buf.put_16(clampi(roundi(impact_pos.x), -32768, 32767))
			buf.put_16(clampi(roundi(impact_pos.y), -32768, 32767))
			buf.put_u8(clampi(int(ev.get("style", 0)), 0, 255))
			buf.put_u8(1 if ev.get("terminal", false) else 0)
		else:
			buf.put_u8(EV_PROJECTILE)
			buf.put_u32(int(ev.get("shot_id", 0)))
			buf.put_utf8_string(String(ev.get("path", "")))
			var epos: Vector2 = ev.get("pos", Vector2.ZERO)
			buf.put_16(clampi(roundi(epos.x), -32768, 32767))
			buf.put_16(clampi(roundi(epos.y), -32768, 32767))
			var dir: Vector2 = ev.get("dir", Vector2.RIGHT)
			buf.put_u16(int(wrapf(dir.angle(), 0.0, TAU) / TAU * 65535.0))
			buf.put_u16(clampi(roundi(float(ev.get("speed", 0.0))), 0, 65535))
			buf.put_u16(clampi(roundi(float(ev.get("lifetime", 0.0)) * 1000.0), 0, 65535))
			buf.put_u16(clampi(roundi(float(ev.get("turn_rate", 0.0)) * 1000.0), 0, 65535))
			buf.put_u8(clampi(int(ev.get("target_actor", NO_TARGET)), 0, 255))
	return buf.data_array

## {} on junk (bad proto, truncated). Rows come back as apply_net_state-ready
## dictionaries; events as spawn orders with target_actor indices.
static func unpack_snapshot(bytes: PackedByteArray) -> Dictionary:
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	if buf.get_size() < 6:
		return {}
	if buf.get_u8() != Proto.PROTOCOL_VERSION:
		return {}
	var tick := buf.get_u32()
	var row_count := buf.get_u8()
	var rows: Array = []
	for r in row_count:
		if buf.get_available_bytes() < 19 + AMMO_SLOTS:
			return {}
		var flags := buf.get_u8()
		var floor_i := buf.get_8()
		var px := buf.get_16()
		var py := buf.get_16()
		var heading := float(buf.get_u16()) / 65535.0 * TAU
		var vx := buf.get_16()
		var vy := buf.get_16()
		var hp := float(buf.get_u16()) / 10.0
		var height := float(buf.get_u8())
		var heat := float(buf.get_u8()) / 255.0
		var boost_fuel := float(buf.get_u8())
		var slot := buf.get_u8()
		var ammo: Array = []
		for i in AMMO_SLOTS:
			ammo.append(buf.get_u8())
		var recharge := float(buf.get_u8()) / 255.0
		rows.append({
			"pos": Vector2(px, py), "vel": Vector2(vx, vy),
			"heading": heading, "height": height, "floor": floor_i, "hp": hp,
			"alive": (flags & F_ALIVE) != 0, "boost": (flags & F_BOOST) != 0,
			"handbrake": (flags & F_HANDBRAKE) != 0, "burn": (flags & F_BURN) != 0,
			"shield": (flags & F_SHIELD) != 0, "mg_locked": (flags & F_MG_LOCKED) != 0,
			"brake": (flags & F_BRAKE) != 0,
			"heat": heat, "boost_fuel": boost_fuel, "slot": slot, "ammo": ammo,
			"recharge": recharge,
		})
	if buf.get_available_bytes() < 1:
		return {}
	var ev_count := buf.get_u8()
	var events: Array = []
	for e in ev_count:
		if buf.get_available_bytes() < 1:
			return {}
		var kind := buf.get_u8()
		if kind == EV_HIT:
			if buf.get_available_bytes() < 2:
				return {}
			events.append({"kind": EV_HIT, "attacker_actor": buf.get_u8(),
				"victim_actor": buf.get_u8()})
			continue
		if kind == EV_IMPACT:
			if buf.get_available_bytes() < 10:
				return {}
			events.append({
				"kind": EV_IMPACT, "shot_id": buf.get_u32(),
				"pos": Vector2(buf.get_16(), buf.get_16()),
				"style": buf.get_u8(), "terminal": buf.get_u8() != 0,
			})
			continue
		if kind != EV_PROJECTILE:
			return {}
		if buf.get_available_bytes() < 4:
			return {}
		var shot_id := buf.get_u32()
		var path := buf.get_utf8_string()
		if buf.get_available_bytes() < 13:
			return {}
		var ex := buf.get_16()
		var ey := buf.get_16()
		var angle := float(buf.get_u16()) / 65535.0 * TAU
		var speed := float(buf.get_u16())
		var lifetime := float(buf.get_u16()) / 1000.0
		var turn_rate := float(buf.get_u16()) / 1000.0
		var target := buf.get_u8()
		events.append({
			"kind": EV_PROJECTILE, "shot_id": shot_id, "path": path, "pos": Vector2(ex, ey),
			"dir": Vector2.RIGHT.rotated(angle), "speed": speed,
			"lifetime": lifetime, "turn_rate": turn_rate, "target_actor": target,
		})
	return {"tick": tick, "rows": rows, "events": events}
