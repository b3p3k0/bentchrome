class_name MatchDirector
extends Node
## Host-only rules engine for MP matches: death tallies with attribution
## (last_attacker within a recency window; pit-shoves count, ancient grudges
## don't), the four formats' end conditions (pure static truth table —
## end_check), the got-next rotation on the unified seat-fill rule, and the
## respawn loop. Net-free by design: the shell relays signals to the wire, so
## every rule here runs headless. Match-end BEATS rotation: the killing blow
## that ends a match seats nobody.

const Roster := preload("res://game/net/net_roster.gd")

signal status_changed()                # scores/lives moved — sync the wire
signal feed_line(text: String)         # one kill-feed sentence
signal seat_swap(actor_idx: int, from_peer: int, to_peer: int, car_id: String)
signal ended(result: Dictionary)       # {reason, winners: [peer ids], scores}

static var RESPAWN_DELAY := 1.6
static var SHIELD_TIME := 2.0
static var ATTRIBUTION_MS := 10000     # kill credit window after the last hit
static var STATUS_SYNC_S := 1.0        # timer heartbeat to the clients

const WASTELAND := 0  # the AI's shared scoreboard row

var config := {}
var actors: Array = []       # [{peer, car, name}] — SHARED with Net.match_actors
var actor_cars: Array = []   # actor idx -> Vehicle — SHARED with the shell
var roster: RefCounted = null  # host's NetRoster (rotation writes through it)
var spawns: Array = []
var scores := {}             # peer id (WASTELAND = AI) -> {kills, deaths, name}
var lives_left := {}         # LIVES format: peer -> remaining
var eliminated := {}         # peer -> true (no respawn, roster locked)
var finished := false

var _prev_alive := {}
var _pending := {}           # actor idx -> respawn timer live
var _elapsed := 0.0
var _status_accum := 0.0

func setup(p_config: Dictionary, p_actors: Array, p_cars: Array,
		p_roster: RefCounted, p_spawns: Array) -> void:
	config = p_config
	actors = p_actors
	actor_cars = p_cars
	roster = p_roster
	spawns = p_spawns
	scores = {WASTELAND: {"kills": 0, "deaths": 0, "name": "THE WASTELAND"}}
	for actor in actors:
		var peer := int(actor.peer)
		if peer > 0:
			scores[peer] = {"kills": 0, "deaths": 0, "name": String(actor.name)}
			if _format() == &"lives":
				lives_left[peer] = int(config.get("lives", 3))
	for i in actors.size():
		_prev_alive[i] = true

func time_remaining() -> float:
	match _format():
		&"timed":
			return maxf(float(int(config.get("time_limit", 300))) - _elapsed, 0.0)
		&"brawl":
			var cap := int(config.get("brawl_time_cap", 0))
			return maxf(float(cap) - _elapsed, 0.0) if cap > 0 else -1.0
	return -1.0

## The host's own exit (rotation brawl runs until somebody calls it).
func force_end(reason: String) -> void:
	if not finished:
		_finish({"reason": reason, "winners": _leaders()})

## Current kill leaders (joint on ties) — the capless-brawl verdict.
func _leaders() -> Array:
	var verdict := _clock_win(scores, "")
	return verdict.get("winners", [])

func _physics_process(delta: float) -> void:
	if finished:
		return
	_elapsed += delta
	# 1) Collect this tick's death edges in actor order — deterministic.
	var batch: Array = []
	for i in actor_cars.size():
		var alive := _alive(i)
		if bool(_prev_alive.get(i, true)) and not alive:
			batch.append(i)
		_prev_alive[i] = alive
	# 2) Tally every death (kills, deaths, lives, feed) BEFORE any verdict.
	var batch_out: Array = []  # peers eliminated in this batch (lives)
	for idx in batch:
		var out_peer := _tally_death(idx)
		if out_peer > 0:
			batch_out.append(out_peer)
	# 3) End check — beats rotation and respawns, always.
	var verdict := end_check(config, scores, _alive_humans(), _total_humans(),
		batch_out, _elapsed)
	if not verdict.is_empty():
		_finish(verdict)
		return
	# 4) Survivor logistics: rotation (unified seat-fill) or plain respawn.
	for idx in batch:
		_after_death(idx)
	if not batch.is_empty():
		status_changed.emit()
	_status_accum += delta
	if _status_accum >= STATUS_SYNC_S:
		_status_accum = 0.0
		status_changed.emit()

## The formats' truth table — pure and static, no nodes, fully unit-tested.
## Returns {} to keep rolling, else {reason, winners: [peer ids]} (winners
## empty = THE WASTELAND took it).
static func end_check(cfg: Dictionary, p_scores: Dictionary, alive_humans: int,
		total_humans: int, batch_out: Array, elapsed: float) -> Dictionary:
	match StringName(String(cfg.get("format", &"brawl"))):
		&"frag":
			return _frag_win(p_scores, int(cfg.get("frag_target", 10)))
		&"brawl":
			var cap := int(cfg.get("brawl_frag_cap", 0))
			if cap > 0:
				var win := _frag_win(p_scores, cap)
				if not win.is_empty():
					return win
			var tcap := int(cfg.get("brawl_time_cap", 0))
			if tcap > 0 and elapsed >= float(tcap):
				return _clock_win(p_scores, "the time cap")
			return {}
		&"timed":
			if elapsed >= float(int(cfg.get("time_limit", 300))):
				return _clock_win(p_scores, "the horn")
			return {}
		&"lives":
			if alive_humans == 1 and total_humans > 1:
				# The instance (which knows the roster) resolves the survivor.
				return {"reason": "last one standing", "winners": [], "resolve_survivor": true}
			if alive_humans == 0:
				if batch_out.size() >= 2:
					return {"reason": "mutual destruction", "winners": batch_out.duplicate()}
				return {"reason": "THE WASTELAND WINS", "winners": []}
			return {}
	return {}

static func _frag_win(p_scores: Dictionary, target: int) -> Dictionary:
	for peer in p_scores:
		if int(peer) > 0 and int(p_scores[peer].kills) >= target:
			return {"reason": "first to %d" % target, "winners": [int(peer)]}
	return {}

static func _clock_win(p_scores: Dictionary, what: String) -> Dictionary:
	var best := -1
	var winners: Array = []
	for peer in p_scores:
		if int(peer) <= 0:
			continue
		var k := int(p_scores[peer].kills)
		if k > best:
			best = k
			winners = [int(peer)]
		elif k == best:
			winners.append(int(peer))  # joint winners — no sudden death (v1)
	return {"reason": "most wrecks at %s" % what, "winners": winners}

# ---------------------------------------------------------------- internals

func _format() -> StringName:
	return StringName(String(config.get("format", &"brawl")))

func _alive(i: int) -> bool:
	var car: Node = actor_cars[i] if is_instance_valid(actor_cars[i]) else null
	return car != null and car.get_hp() > 0.0

func _alive_humans() -> int:
	var n := 0
	for i in actors.size():
		if int(actors[i].peer) > 0 and not eliminated.get(int(actors[i].peer), false) \
				and (_alive(i) or _pending.has(i)):
			n += 1
	return n

func _total_humans() -> int:
	var n := 0
	for actor in actors:
		if int(actor.peer) > 0:
			n += 1
	return n

## Tallies one death; returns the peer eliminated by it (0 = none).
func _tally_death(idx: int) -> int:
	var victim: Dictionary = actors[idx]
	var vpeer := int(victim.peer)
	var killer_idx := _attribute(idx)
	var line: String
	if killer_idx >= 0:
		var kpeer := int(actors[killer_idx].peer)
		var krow: Dictionary = scores[kpeer if kpeer > 0 else WASTELAND]
		krow.kills += 1
		line = "%s wrecked %s" % [String(actors[killer_idx].name), String(victim.name)]
	else:
		line = "%s fed the wasteland" % String(victim.name)
	var out_peer := 0
	if vpeer > 0 and scores.has(vpeer):
		scores[vpeer].deaths += 1
		if _format() == &"lives":
			lives_left[vpeer] = int(lives_left.get(vpeer, 1)) - 1
			if int(lives_left[vpeer]) <= 0:
				eliminated[vpeer] = true
				out_peer = vpeer
				line += " — OUT!"
	feed_line.emit(line)
	return out_peer

## Kill credit: the last attacker, alive-or-not, within the recency window,
## never yourself. Anything else is the wasteland's.
func _attribute(idx: int) -> int:
	var car: Node = actor_cars[idx] if is_instance_valid(actor_cars[idx]) else null
	if car == null:
		return -1
	var atk: Node2D = car.last_attacker
	if atk == null or not is_instance_valid(atk) or atk == car:
		return -1
	if Time.get_ticks_msec() - int(car.last_attacker_ms) > ATTRIBUTION_MS:
		return -1
	return actor_cars.find(atk)

func _after_death(idx: int) -> void:
	if finished:
		return
	var peer := int(actors[idx].peer)
	if peer <= 0:
		return  # AI stay down — arena rules
	if eliminated.get(peer, false):
		var car: Node = actor_cars[idx]
		if is_instance_valid(car):
			car.visible = false  # off the floor; the rig takes their eyes (C10)
		return
	# Unified seat-fill: a death only rotates when someone is actually waiting.
	if _rotation_allowed() and roster and not roster.queue.is_empty():
		var freed: int = roster.rotate_out(peer)
		var next: Dictionary = roster.pop_next()
		if freed >= 0 and not next.is_empty():
			var to_peer := int(next.id)
			roster.claim_seat(to_peer, freed)
			roster.set_pick(to_peer, String(next.car))
			actors[idx] = {"peer": to_peer, "car": String(next.car),
				"name": String(actors[idx].name)}  # shell stamps the real name
			if not scores.has(to_peer):
				scores[to_peer] = {"kills": 0, "deaths": 0, "name": ""}
			seat_swap.emit(idx, peer, to_peer, String(next.car))
	_schedule_respawn(idx)

func _rotation_allowed() -> bool:
	return bool(config.get("gotnext", true)) and bool(config.get("observers", true)) \
		and Roster.mid_match_reseat(_format())

func _schedule_respawn(idx: int) -> void:
	if _pending.has(idx):
		return
	_pending[idx] = true
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(
		_respawn.bind(idx), CONNECT_ONE_SHOT)

func _respawn(idx: int) -> void:
	_pending.erase(idx)
	if finished:
		return
	var car: Node = actor_cars[idx] if is_instance_valid(actor_cars[idx]) else null
	if car == null:
		return
	var spot := farthest_spawn()
	if spot.is_empty():
		return
	car.respawn(spot.pos, spot.heading, SHIELD_TIME)
	_prev_alive[idx] = true

func _finish(verdict: Dictionary) -> void:
	finished = true
	var winners: Array = verdict.get("winners", [])
	if verdict.get("resolve_survivor", false):
		# Lives: the one seated human still breathing takes it.
		winners = []
		for i in actors.size():
			var peer := int(actors[i].peer)
			if peer > 0 and not eliminated.get(peer, false):
				winners.append(peer)
	ended.emit({"reason": String(verdict.get("reason", "")),
		"winners": winners, "scores": scores})

## The locked respawn rule: the derived spawn farthest from every living
## combatant — no spawning into someone's crosshairs.
func farthest_spawn() -> Dictionary:
	if spawns.is_empty():
		return {}
	var living: Array = []
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		if is_instance_valid(v) and v.get_hp() > 0.0:
			living.append(v)
	var best: Dictionary = spawns[0]
	var best_d := -1.0
	for spot in spawns:
		var nearest := INF
		for v in living:
			nearest = minf(nearest, (spot.pos as Vector2).distance_to(v.global_position))
		if living.is_empty():
			nearest = 0.0
		if nearest > best_d:
			best_d = nearest
			best = spot
	return best
