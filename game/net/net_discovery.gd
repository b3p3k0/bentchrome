class_name NetDiscovery
extends RefCounted
## LAN server discovery over UDP broadcast — NAT-free by construction. A host
## beacons its session card (~1/s) at 255.255.255.255:discovery_port; a
## browsing client binds that port and collects cards, expiring silence after
## ENTRY_TTL. Direct IP:port always works without any of this. One browser per
## box (the port bind is exclusive) — the join screen says so when it loses.

const Proto := preload("res://game/net/net_protocol.gd")

const BEACON_INTERVAL := 1.0
const ENTRY_TTL := 3.0

var _udp: PacketPeerUDP = null
var _mode := &""  # &"beacon" | &"browse"
var _beacon_info := {}
var _beacon_clock := 0.0
var _found := {}  # ip -> {info: Dictionary, seen: ticks_msec}

func start_beacon(info: Dictionary) -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.set_dest_address("255.255.255.255", Proto.discovery_port) != OK:
		stop()
		return false
	_mode = &"beacon"
	_beacon_info = info
	_beacon_clock = BEACON_INTERVAL  # first tick fires immediately
	return true

## Hosts refresh the card when its facts change (player count, map).
func update_beacon(info: Dictionary) -> void:
	_beacon_info = info

func beacon_tick(delta: float) -> void:
	if _mode != &"beacon" or _udp == null:
		return
	_beacon_clock += delta
	if _beacon_clock < BEACON_INTERVAL:
		return
	_beacon_clock = 0.0
	_udp.put_packet(JSON.stringify(_beacon_info).to_utf8_buffer())

func start_browse() -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	if _udp.bind(Proto.discovery_port, "*") != OK:
		stop()
		return false
	_mode = &"browse"
	return true

## Drains arrived beacons and expires stale ones. Returns [{ip, info}] sorted
## by ip so the list doesn't shuffle under the cursor.
func browse_poll() -> Array:
	if _mode != &"browse" or _udp == null:
		return []
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var json := JSON.new()
		if json.parse(bytes.get_string_from_utf8()) != OK:
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			continue
		_found[ip] = {"info": json.data, "seen": Time.get_ticks_msec()}
	var now := Time.get_ticks_msec()
	var out := []
	for ip in _found.keys():
		if now - int(_found[ip].seen) > ENTRY_TTL * 1000.0:
			_found.erase(ip)
		else:
			out.append({"ip": ip, "info": _found[ip].info})
	out.sort_custom(func(a, b) -> bool: return String(a.ip) < String(b.ip))
	return out

func is_browsing() -> bool:
	return _mode == &"browse"

func stop() -> void:
	if _udp:
		_udp.close()
	_udp = null
	_mode = &""
	_found.clear()
