extends Node
## NetSession (autoload "Net"): peer lifecycle for LAN multiplayer. Owns the
## ENet peer, runs the pre-admit auth handshake (banlist -> nonce challenge ->
## proof/checksum verdict via NetAuth), maintains the admitted-peer table, and
## beacons the session card while hosting. Dormant until host()/join() — boot,
## tests, and single-player never touch a socket.
##
## Control-plane RPCs live here (reliable, channel 0). The state/input planes
## (snapshots, intents) arrive with the match shell in later cards.

const Proto := preload("res://game/net/net_protocol.gd")
const Auth := preload("res://game/net/net_auth.gd")
const Manifest := preload("res://game/net/net_manifest.gd")
const Banlist := preload("res://game/net/net_banlist.gd")
const Discovery := preload("res://game/net/net_discovery.gd")
const Roster := preload("res://game/net/net_roster.gd")
const Config := preload("res://game/net/match_config.gd")
const Snapshot := preload("res://game/net/net_snapshot.gd")
const LoaderScript := preload("res://levels/level_loader.gd")

signal session_changed()
signal peers_changed()
signal lobby_changed()
signal match_started()
signal snapshot_arrived(data: Dictionary)
signal match_status_changed()
signal kill_feed(text: String)
signal fx_event(ev: Dictionary)
signal actor_swapped(actor_idx: int, peer: int, car: String, name: String)
signal match_ended(result: Dictionary)
signal join_failed(reason: String)
signal kicked(reason: String)

enum Mode { OFF, HOSTING, JOINING, JOINED }

var mode: int = Mode.OFF
var peers := {}  # peer_id -> {name, modded, ip} — ip is host-side only ("" on clients)
var game_port: int = 0
var roster: RefCounted = null  # NetRoster — host-authoritative, clients mirror
var match_config := {}         # MatchConfig-normalized; host edits, all mirror
var _notice := ""              # one-shot message for the next menu screen

var _enet: ENetMultiplayerPeer = null
var _discovery: RefCounted = null  # NetDiscovery beacon while hosting
var _banlist: RefCounted = null    # NetBanlist, host-side
var _password := ""
var _strict_mods := false
var _server_name := ""
var _nonces := {}    # peer_id -> single-use challenge nonce
var _verdicts := {}  # peer_id -> admit verdict, held until peer_connected
var _join_password := ""
var _last_reject := ""  # client: reason from a pre-disconnect reject packet
var _last_kick := ""    # client: reason from a kick notice
var _net_drivers := {}  # host, mid-match: peer_id -> NetworkDriver
var _input_tick := 0    # client: outgoing frame counter (stale-drop on host)
var _cycle_seq := 0     # client: outgoing weapon-cycle sequence
var match_actors: Array = []  # [{peer, car, name}] — row order IS wire order
var match_live := false      # gates late joins (v1: lobby-join only)
var match_scores := {}       # mirrored from the host's MatchDirector
var match_remaining := -1.0  # seconds on the clock (-1 = no clock)
var match_eliminated: Array = []  # peers out of lives (rig handoff cue)
var last_result := {}        # the previous match's verdict, for the lobby
var _last_snap_tick := 0     # client: stale-snapshot guard

func _ready() -> void:
	set_process(false)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var sm := multiplayer as SceneMultiplayer
	if sm:
		sm.auth_callback = _on_auth_packet
		sm.auth_timeout = 8.0
		sm.peer_authenticating.connect(_on_peer_authenticating)
		sm.peer_authentication_failed.connect(_on_peer_auth_failed)

func _process(delta: float) -> void:
	if _discovery:
		_discovery.beacon_tick(delta)

func is_host() -> bool:
	return mode == Mode.HOSTING

func is_active() -> bool:
	return mode != Mode.OFF

func my_id() -> int:
	return multiplayer.get_unique_id() if is_active() else 0

## Opens the garage doors. Returns "" on success, a human reason otherwise.
func host(port: int, password: String, server_name: String, strict_mods: bool) -> String:
	leave()
	_enet = ENetMultiplayerPeer.new()
	# max clients = budget minus the host's own seat at the table.
	if _enet.create_server(port, Proto.MAX_PEERS - 1, Proto.ENET_CHANNELS) != OK:
		_enet = null
		return "port %d refused — already in use?" % port
	multiplayer.multiplayer_peer = _enet
	mode = Mode.HOSTING
	game_port = port
	_password = password
	_strict_mods = strict_mods
	_server_name = server_name
	_banlist = Banlist.new()
	peers = {1: {"name": display_name(), "modded": false, "ip": "local"}}
	roster = Roster.new(Proto.MAX_PLAYERS)
	match_config = Config.defaults()
	# The host always drives by default: SEAT 1 is theirs until they stand up.
	roster.claim_seat(1, 0)
	roster.set_pick(1, _default_pick(1))
	_discovery = Discovery.new()
	_discovery.start_beacon(_beacon_info())
	set_process(true)
	session_changed.emit()
	peers_changed.emit()
	return ""

## Dials a host. Async: success lands as session_changed (mode JOINED),
## failure as join_failed(reason). Returns "" unless the dial itself failed.
func join(ip: String, port: int, password: String) -> String:
	leave()
	_enet = ENetMultiplayerPeer.new()
	if _enet.create_client(ip, port, Proto.ENET_CHANNELS) != OK:
		_enet = null
		return "could not dial %s:%d" % [ip, port]
	multiplayer.multiplayer_peer = _enet
	mode = Mode.JOINING
	_join_password = password
	_last_reject = ""
	_last_kick = ""
	session_changed.emit()
	return ""

## Hangs up whatever this session was — host or client — and goes dark.
func leave() -> void:
	if _discovery:
		_discovery.stop()
		_discovery = null
	if _enet:
		_enet.close()
		_enet = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var was_active := mode != Mode.OFF
	mode = Mode.OFF
	peers = {}
	game_port = 0
	roster = null
	match_config = {}
	_banlist = null
	_nonces.clear()
	_verdicts.clear()
	_net_drivers.clear()
	_input_tick = 0
	_cycle_seq = 0
	match_actors = []
	match_live = false
	match_scores = {}
	match_remaining = -1.0
	match_eliminated = []
	last_result = {}
	_last_snap_tick = 0
	_password = ""
	_join_password = ""
	set_process(false)
	if was_active:
		session_changed.emit()
		peers_changed.emit()

## Host boots a peer. peer_disconnect_later flushes the queued reason first,
## then cuts the line — no timers, no race.
func kick(id: int, reason := "kicked by host") -> void:
	if mode != Mode.HOSTING or id == 1 or not peers.has(id):
		return
	_notify_kick.rpc_id(id, reason)
	_drop_peer(id)

## Kick + remember the IP. The ban outlives the session (user://banlist.json).
func ban(id: int, reason := "banned by host") -> void:
	if mode != Mode.HOSTING or id == 1 or not peers.has(id):
		return
	if _banlist:
		_banlist.ban(String(peers[id].get("ip", "")))
	kick(id, reason)

func banned_ips() -> Array:
	return _banlist.all() if _banlist else []

func unban_ip(ip: String) -> void:
	if _banlist:
		_banlist.unban(ip)

func display_name() -> String:
	var gs := get_node_or_null(^"/root/GameState")
	var n: String = String(gs.player_name) if gs else ""
	n = n.strip_edges()
	return n if not n.is_empty() else "Wastelander"

## One-shot notice (kick reason, session end) for whichever menu loads next.
func take_notice() -> String:
	var n := _notice
	_notice = ""
	return n

# -------------------------------------------------------------- lobby plane
# One public request_* per verb: the host applies directly, clients relay to
# peer 1. Hosts validate every relayed request against the peers table — a
# fuzzing client can't seat ghosts, pick off-roster cars, or queue twice.

func request_claim_seat(idx: int) -> void:
	if is_host():
		_apply_claim_seat(1, idx)
	elif mode == Mode.JOINED:
		rpc_claim_seat.rpc_id(1, idx)

func request_leave_seat() -> void:
	if is_host():
		_apply_leave_seat(1)
	elif mode == Mode.JOINED:
		rpc_leave_seat.rpc_id(1)

func request_set_pick(car: String) -> void:
	if is_host():
		_apply_set_pick(1, car)
	elif mode == Mode.JOINED:
		rpc_set_pick.rpc_id(1, car)

## on=true joins the got-next queue with a locked car pick; opting in while
## already queued is the pick change — structurally the back of the line.
func request_opt_next(on: bool, car: String) -> void:
	if is_host():
		_apply_opt_next(1, on, car)
	elif mode == Mode.JOINED:
		rpc_opt_next.rpc_id(1, on, car)

## Host-only: patch + normalize + broadcast the ruleset.
func set_match_config(patch: Dictionary) -> void:
	if mode != Mode.HOSTING:
		return
	var merged := match_config.duplicate()
	for k in patch:
		merged[k] = patch[k]
	match_config = Config.normalize(merged, SceneFlow.MP_MAPS.size())
	_lobby_dirty()

@rpc("any_peer", "call_remote", "reliable")
func rpc_claim_seat(idx: int) -> void:
	if mode == Mode.HOSTING:
		_apply_claim_seat(multiplayer.get_remote_sender_id(), idx)

@rpc("any_peer", "call_remote", "reliable")
func rpc_leave_seat() -> void:
	if mode == Mode.HOSTING:
		_apply_leave_seat(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func rpc_set_pick(car: String) -> void:
	if mode == Mode.HOSTING:
		_apply_set_pick(multiplayer.get_remote_sender_id(), car)

@rpc("any_peer", "call_remote", "reliable")
func rpc_opt_next(on: bool, car: String) -> void:
	if mode == Mode.HOSTING:
		_apply_opt_next(multiplayer.get_remote_sender_id(), on, car)

func _apply_claim_seat(id: int, idx: int) -> void:
	if roster == null or not peers.has(id):
		return
	if roster.claim_seat(id, idx):
		# A stale or newly-conflicting pick re-rolls to the first free ride.
		var pick: String = roster.pick_of(id)
		if pick.is_empty() or taken_cars(id).has(pick):
			roster.set_pick(id, _default_pick(id))
		_lobby_dirty()

func _apply_leave_seat(id: int) -> void:
	if roster and roster.leave_seat(id):
		_lobby_dirty()

func _apply_set_pick(id: int, car: String) -> void:
	if roster == null or not peers.has(id) or not roster.seated(id):
		return
	if not Config.car_ids().has(car) or taken_cars(id).has(car):
		return  # off-roster or already claimed — first come, first serve
	roster.set_pick(id, car)
	_lobby_dirty()

func _apply_opt_next(id: int, on: bool, car: String) -> void:
	if roster == null or not peers.has(id) or roster.seated(id):
		return
	if on:
		if not Config.car_ids().has(car) or taken_cars(id).has(car):
			return  # the queue reserves rides too — no rotation collisions
		roster.opt_in(id, car)
	elif not roster.opt_out(id):
		return
	_lobby_dirty()

# -------------------------------------------------------------- match plane

## Host: freeze the ruleset, build the actor table (seats first, then Grand
## Melee AI backfill to the map's authored car count), broadcast, roll
## everyone into the arena. The table's ORDER is the snapshot wire order.
func start_match() -> void:
	if mode != Mode.HOSTING or roster == null:
		return
	var actors: Array = []
	for id_v in roster.seated_ids():
		var id := int(id_v)
		actors.append({"peer": id, "car": roster.pick_of(id),
			"name": String(peers.get(id, {}).get("name", "?"))})
	if StringName(String(match_config.get("mode", &"melee"))) == &"melee":
		var idx := clampi(int(match_config.get("map", 0)), 0, SceneFlow.MP_MAPS.size() - 1)
		var want := int(SceneFlow.MP_MAPS[idx].get("cars", actors.size())) - actors.size()
		if want > 0:
			# Host-only RNG: under host authority the table IS the truth. The
			# AI pool excludes every claimed ride (seats + queue) — the pool
			# running short means FEWER bots, never a duplicate car.
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			for pick in LoaderScript.pick_cars(want, "", rng, taken_cars(0)):
				actors.append({"peer": 0, "car": String(pick),
					"name": Config.car_name(String(pick))})
	rpc_start_match.rpc(match_config, actors)
	_apply_match_start(match_config, actors)

@rpc("authority", "call_remote", "reliable")
func rpc_start_match(cfg: Dictionary, actors: Array) -> void:
	_apply_match_start(cfg, actors)

func _apply_match_start(cfg: Dictionary, actors: Array) -> void:
	match_config = cfg
	match_actors = actors
	match_live = true
	_last_snap_tick = 0
	match_started.emit()
	# Headless -s harnesses have no current scene to swap; they instantiate
	# the shell themselves. Every real boot path always has one.
	if get_tree().current_scene != null:
		SceneFlow.to_mp_match()

## Host relays from the MatchDirector — scores/clock, feed lines, rotation
## swaps, and the final verdict. Each applies locally AND broadcasts.
func push_match_status(scores: Dictionary, remaining: float, eliminated: Array) -> void:
	if mode != Mode.HOSTING:
		return
	rpc_match_status.rpc(scores, remaining, eliminated)
	match_scores = scores
	match_remaining = remaining
	match_eliminated = eliminated
	match_status_changed.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_match_status(scores: Dictionary, remaining: float, eliminated: Array) -> void:
	match_scores = scores
	match_remaining = remaining
	match_eliminated = eliminated
	match_status_changed.emit()

func push_kill_feed(text: String) -> void:
	if mode != Mode.HOSTING:
		return
	rpc_kill_feed.rpc(text)
	kill_feed.emit(text)

## Reliable FX plane (beams, pulse rings, mines): stateful/one-shot visuals
## that must never vanish to a dropped packet. Host renders its own real FX,
## so this is broadcast-only — no local emit.
func push_fx(ev: Dictionary) -> void:
	if mode == Mode.HOSTING:
		rpc_fx.rpc(ev)

@rpc("authority", "call_remote", "reliable")
func rpc_fx(ev: Dictionary) -> void:
	fx_event.emit(ev)

@rpc("authority", "call_remote", "reliable")
func rpc_kill_feed(text: String) -> void:
	kill_feed.emit(text)

## Got-next rotation landed: actor_idx changes hands. The host stamps the
## real callsign, updates the shared table, and tells everyone (the roster
## change itself rides the usual lobby broadcast).
func notify_actor_swap(actor_idx: int, peer: int, car: String) -> void:
	if mode != Mode.HOSTING or actor_idx < 0 or actor_idx >= match_actors.size():
		return
	var name := String(peers.get(peer, {}).get("name", ""))
	if name.is_empty():
		# Ghost slots (peer 0) keep the departed driver's frozen callsign.
		name = String(match_actors[actor_idx].get("name", "?"))
	match_actors[actor_idx] = {"peer": peer, "car": car, "name": name}
	rpc_actor_swap.rpc(actor_idx, peer, car, name)
	actor_swapped.emit(actor_idx, peer, car, name)
	_lobby_dirty()

@rpc("authority", "call_remote", "reliable")
func rpc_actor_swap(actor_idx: int, peer: int, car: String, name: String) -> void:
	if actor_idx >= 0 and actor_idx < match_actors.size():
		match_actors[actor_idx] = {"peer": peer, "car": car, "name": name}
	actor_swapped.emit(actor_idx, peer, car, name)

func end_match(result: Dictionary) -> void:
	if mode != Mode.HOSTING:
		return
	rpc_match_end.rpc(result)
	_apply_match_end(result)

@rpc("authority", "call_remote", "reliable")
func rpc_match_end(result: Dictionary) -> void:
	_apply_match_end(result)

func _apply_match_end(result: Dictionary) -> void:
	match_live = false
	last_result = result
	match_ended.emit(result)
	# Same -s guard as match start; real boots always have a scene.
	if get_tree().current_scene != null:
		SceneFlow.to_mp_scoreboard()

## Host rolls everyone from the scoreboard back to the garage.
func return_to_lobby() -> void:
	if mode != Mode.HOSTING:
		return
	rpc_return_to_lobby.rpc()
	_apply_return()

@rpc("authority", "call_remote", "reliable")
func rpc_return_to_lobby() -> void:
	_apply_return()

func _apply_return() -> void:
	if get_tree().current_scene != null:
		SceneFlow.to_mp_lobby()

# -------------------------------------------------------------- state plane

## Host: one packed snapshot to every peer (unreliable, latest-wins).
func broadcast_snapshot(bytes: PackedByteArray) -> void:
	if mode == Mode.HOSTING:
		rpc_snapshot.rpc(bytes)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func rpc_snapshot(bytes: PackedByteArray) -> void:
	var data: Dictionary = Snapshot.unpack_snapshot(bytes)
	if data.is_empty():
		return
	if int(data.tick) <= _last_snap_tick:
		return  # stale straggler
	_last_snap_tick = int(data.tick)
	snapshot_arrived.emit(data)

# -------------------------------------------------------------- input plane
# Client PlayerDriver intent -> 7-byte frames at the physics rate (unreliable
# ordered, latest-wins on the host's NetworkDriver); weapon-cycle edges ride
# the reliable channel with a sequence so they land exactly once. The MP
# match shell registers one NetworkDriver per remote seat.

func register_net_driver(peer_id: int, driver: Node) -> void:
	if mode == Mode.HOSTING:
		_net_drivers[peer_id] = driver

func unregister_net_driver(peer_id: int) -> void:
	_net_drivers.erase(peer_id)

## Client: ship this tick's sampled intent to the host.
func send_input(intent: Dictionary) -> void:
	if mode != Mode.JOINED:
		return
	_input_tick += 1
	rpc_input_frame.rpc_id(1, Snapshot.pack_input(_input_tick, intent))

## Client: one weapon-wheel click, guaranteed delivery.
func send_weapon_cycle(dir: int) -> void:
	if mode != Mode.JOINED or dir == 0:
		return
	_cycle_seq += 1
	rpc_weapon_cycle.rpc_id(1, _cycle_seq, signi(dir))

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func rpc_input_frame(bytes: PackedByteArray) -> void:
	if mode != Mode.HOSTING:
		return
	var driver: Node = _net_drivers.get(multiplayer.get_remote_sender_id())
	if driver == null:
		return
	var frame: Dictionary = Snapshot.unpack_input(bytes)
	if not frame.is_empty():
		driver.feed_frame(frame)

@rpc("any_peer", "call_remote", "reliable")
func rpc_weapon_cycle(seq: int, dir: int) -> void:
	if mode != Mode.HOSTING:
		return
	var driver: Node = _net_drivers.get(multiplayer.get_remote_sender_id())
	if driver:
		driver.feed_cycle(seq, dir)

## Host: rebroadcast the lobby truth (and refresh the beacon card).
func _lobby_dirty() -> void:
	if mode == Mode.HOSTING:
		_sync_lobby.rpc({"roster": roster.to_dict(), "config": match_config})
	lobby_changed.emit()
	if _discovery:
		_discovery.update_beacon(_beacon_info())

@rpc("authority", "call_remote", "reliable")
func _sync_lobby(state: Dictionary) -> void:
	if roster == null:
		roster = Roster.new(Proto.MAX_PLAYERS)
	roster.from_dict(state.get("roster", {}))
	match_config = state.get("config", {})
	lobby_changed.emit()

# ---------------------------------------------------------------- handshake

func _on_peer_authenticating(id: int) -> void:
	var sm := multiplayer as SceneMultiplayer
	if sm == null:
		return
	if mode == Mode.HOSTING:
		var ip := _peer_ip(id)
		if _banlist and _banlist.is_banned(ip):
			_reject_peer(id, "banned")
			return
		var nonce: PackedByteArray = Auth.make_nonce()
		_nonces[id] = nonce
		sm.send_auth(id, Auth.pack(Auth.challenge(nonce, not _password.is_empty())))
	# Clients wait for the challenge packet; _on_auth_packet answers it.

func _on_auth_packet(id: int, bytes: PackedByteArray) -> void:
	var sm := multiplayer as SceneMultiplayer
	if sm == null:
		return
	var msg: Dictionary = Auth.unpack(bytes)
	if mode == Mode.HOSTING:
		if not _nonces.has(id):
			_reject_peer(id, "no challenge outstanding")
			return
		var ctx := {
			"nonce": _nonces[id],
			"password": _password,
			"needs_password": not _password.is_empty(),
			"host_checksum": Manifest.cached(),
			"strict_mods": _strict_mods,
			"peers": peers.size(),
			"max_peers": _effective_cap(),
			"match_live": match_live,  # v1: lobby-join only
		}
		_nonces.erase(id)  # single-use, replay-proof
		var verdict: Dictionary = Auth.decide(msg, ctx)
		if not bool(verdict.admit):
			_reject_peer(id, String(verdict.reason))
			return
		_verdicts[id] = verdict
		sm.complete_auth(id)
	else:
		if msg.has("reject"):
			# The server is about to cut the line; act on the reason now.
			_last_reject = String(msg.reject)
			_fail_join(_last_reject)
			return
		if msg.has("nonce"):
			# The challenge carries the host's protocol — diagnose a mismatch
			# HERE, locally, and name who needs the newer build (lower = older).
			var host_proto := int(msg.get("proto", -1))
			if host_proto != Proto.PROTOCOL_VERSION:
				var who := "THEY need" if host_proto < Proto.PROTOCOL_VERSION else "YOU need"
				_fail_join("the host runs build v%d — yours is v%d. %s the newer build."
					% [host_proto, Proto.PROTOCOL_VERSION, who])
				return
			var resp: Dictionary = Auth.response(
				msg, _join_password, display_name(), Manifest.cached())
			sm.send_auth(1, Auth.pack(resp))
			sm.complete_auth(1)

func _reject_peer(id: int, reason: String) -> void:
	var sm := multiplayer as SceneMultiplayer
	if sm:
		sm.send_auth(id, Auth.pack({"reject": reason}))
	_nonces.erase(id)
	_drop_peer(id)

## Flush-then-cut disconnect via the ENet peer handle (works mid-auth, when
## the peer isn't in multiplayer.get_peers() yet).
func _drop_peer(id: int) -> void:
	if _enet == null:
		return
	var pp: ENetPacketPeer = _enet.get_peer(id)
	if pp and pp.get_state() != ENetPacketPeer.STATE_DISCONNECTED:
		pp.peer_disconnect_later()

func _on_peer_auth_failed(id: int) -> void:
	if mode == Mode.HOSTING:
		_nonces.erase(id)
		_verdicts.erase(id)
	elif id == 1:
		_fail_join(_last_reject if not _last_reject.is_empty() else "handshake failed")

# ------------------------------------------------------------------- peers

func _on_peer_connected(id: int) -> void:
	if mode != Mode.HOSTING:
		return  # clients learn the table via _sync_peers
	var verdict: Dictionary = _verdicts.get(id, {})
	_verdicts.erase(id)
	var name := String(verdict.get("name", ""))
	if name.is_empty():
		name = "Wastelander %d" % id
	var taken := []
	for pid in peers:
		taken.append(String(peers[pid].name))
	name = Roster.unique_name(name, taken)  # second Hotrod -> "Hotrod #2"
	peers[id] = {
		"name": name,
		"modded": bool(verdict.get("modded", false)),
		"ip": _peer_ip(id),
	}
	_broadcast_peers()
	# Newcomers get the lobby truth directly; everyone else already has it.
	if roster:
		_sync_lobby.rpc_id(id, {"roster": roster.to_dict(), "config": match_config})

func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.HOSTING:
		return
	peers.erase(id)
	if roster:
		roster.drop_peer(id)  # no place-holding: seat freed, queue spot gone
		_lobby_dirty()
	_broadcast_peers()

func _broadcast_peers() -> void:
	# Clients get names and mod flags; IPs stay the host's business.
	var pub := {}
	for id in peers:
		pub[id] = {"name": peers[id].name, "modded": peers[id].modded, "ip": ""}
	_sync_peers.rpc(pub)
	peers_changed.emit()
	if _discovery:
		_discovery.update_beacon(_beacon_info())

@rpc("authority", "call_remote", "reliable")
func _sync_peers(pub: Dictionary) -> void:
	peers = pub
	peers_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _notify_kick(reason: String) -> void:
	_last_kick = reason

# ---------------------------------------------------------- client outcomes

func _on_connected_ok() -> void:
	mode = Mode.JOINED
	session_changed.emit()

func _on_connection_failed() -> void:
	_fail_join(_last_reject if not _last_reject.is_empty() else "no answer at that address")

func _on_server_disconnected() -> void:
	# Deferred: fires from inside a multiplayer callback — tearing the peer
	# down mid-callback is how you core-dump on exit.
	_settle_server_gone.call_deferred()

func _settle_server_gone() -> void:
	if mode == Mode.OFF:
		return
	var kick_reason := _last_kick
	leave()
	_notice = ("you got the boot: " + kick_reason) if not kick_reason.is_empty() \
		else "the host closed the garage"
	if not kick_reason.is_empty():
		kicked.emit(kick_reason)
	# Wherever the session died under us — lobby, match, scoreboard — the
	# front door shows the notice. (-s harnesses have no scene to swap.)
	if get_tree().current_scene != null:
		SceneFlow.to_mp_menu()

func _fail_join(reason: String) -> void:
	# Same deferral rule as above; reject-packet and auth-failed can both fire
	# for one doomed join — the settle guard keeps it to a single emit.
	_settle_fail.call_deferred(reason)

func _settle_fail(reason: String) -> void:
	if mode != Mode.JOINING:
		return
	leave()
	join_failed.emit(reason)

# ------------------------------------------------------------------ helpers

## The connection budget honors the observers rule: no bench = seats only.
func _effective_cap() -> int:
	return Proto.MAX_PEERS if bool(match_config.get("observers", true)) else Proto.MAX_PLAYERS

## Every claimed ride — seated picks plus queue picks — minus exclude_peer's
## own. ONE of each car on the battlefield is the law; the queue pre-reserves
## so a rotation can never collide.
func taken_cars(exclude_peer := 0) -> Array:
	var taken: Array = []
	if roster == null:
		return taken
	for id_v in roster.seated_ids():
		var id := int(id_v)
		if id != exclude_peer:
			var pick: String = roster.pick_of(id)
			if not pick.is_empty():
				taken.append(pick)
	for entry in roster.queue:
		if int(entry.id) != exclude_peer and not String(entry.car).is_empty():
			taken.append(String(entry.car))
	return taken

## A fresh seat inherits the SP picker's car when it's a real, UNCLAIMED
## roster slug; otherwise the first free ride on the floor.
func _default_pick(for_peer: int) -> String:
	var taken := taken_cars(for_peer)
	var gs := get_node_or_null(^"/root/GameState")
	var pick: String = String(gs.selected_vehicle_id) if gs else ""
	var ids: Array = Config.car_ids()
	if not pick.is_empty() and ids.has(pick) and not taken.has(pick):
		return pick
	for id in ids:
		if not taken.has(String(id)):
			return String(id)
	return ""

func _peer_ip(id: int) -> String:
	if _enet == null:
		return ""
	var pp: ENetPacketPeer = _enet.get_peer(id)
	return pp.get_remote_address() if pp else ""

func _beacon_info() -> Dictionary:
	var label := _server_name.strip_edges()
	if label.is_empty():
		label = display_name() + "'s garage"
	var map_name := "lobby"
	var map_idx := int(match_config.get("map", -1))
	if map_idx >= 0 and map_idx < SceneFlow.MP_MAPS.size():
		map_name = String(SceneFlow.MP_MAPS[map_idx].name)
	return {
		"name": label,
		"proto": Proto.PROTOCOL_VERSION,
		"players": peers.size(),
		"max": _effective_cap(),
		"has_password": not _password.is_empty(),
		"game_port": game_port,
		"map": map_name,
	}
