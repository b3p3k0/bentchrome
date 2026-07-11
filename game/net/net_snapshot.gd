class_name NetSnapshot
extends RefCounted
## Wire codecs — StreamPeerBuffer over var_to_bytes for explicit byte widths,
## no per-element Variant tags, and testable round-trips. This card carries
## the client->host INTENT FRAME (7 bytes @ 60Hz); the host->all state
## snapshot joins it in C8b. Format changes bump NetProtocol.PROTOCOL_VERSION.

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
