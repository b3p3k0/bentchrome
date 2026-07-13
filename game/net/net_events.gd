class_name NetEvents
extends RefCounted
## Host-side event tap for things that aren't per-tick state — projectile
## births, later booms and jingles. Dependency-free and dormant: projectile-
## side code calls in (never naming Vehicle, per the combat.gd pattern), the
## MP shell arms it on the HOST only and drains the queue into each snapshot.
## Client processes never arm it, so visual-only mirrors never re-emit.

static var armed := false
static var queue: Array = []      # snapshot plane: droppable cosmetics (tracers)
static var fx: Array = []         # RELIABLE plane: beams, pulse rings, mines —
								  # a lost packet must never mean an invisible mine
static var _next_shot_id := 1
static var _next_mine_id := 1

static func projectile_spawned(scene_path: String, pos: Vector2, dir: Vector2,
		speed: float, lifetime: float, turn_rate: float, target: Node2D,
		tint := Color.WHITE, z := 0) -> int:
	if not armed:
		return 0
	var shot_id := _next_shot_id
	_next_shot_id = (_next_shot_id + 1) & 0xffffffff
	if _next_shot_id == 0:
		_next_shot_id = 1
	queue.append({
		"kind": &"projectile",
		"shot_id": shot_id,
		"path": scene_path,
		"pos": pos,
		"dir": dir,
		"speed": speed,
		"lifetime": lifetime,
		"turn_rate": turn_rate,
		"target": target,  # resolved to an actor index at drain time
		"tint": tint,      # the mount stamped modulate before setup — protocol 9
		"z": z,            # shooter draw order (floor-3 shots over deck paint)
	})
	return shot_id

static func projectile_impact(shot_id: int, pos: Vector2, style: int,
		terminal: bool) -> void:
	if not armed or shot_id <= 0:
		return
	queue.append({
		"kind": &"impact", "shot_id": shot_id, "pos": pos,
		"style": style, "terminal": terminal,
	})

static func hit_landed(attacker: Node2D, victim: Node2D) -> void:
	if not armed or not is_instance_valid(attacker) or not is_instance_valid(victim):
		return
	queue.append({"kind": &"hit", "attacker": attacker, "victim": victim})

# ------------------------------------------------------ reliable FX plane
# Node references resolve to actor indices at drain time, same as targets.

static func beam_on(shooter: Node2D, target: Node2D) -> void:
	if armed:
		fx.append({"kind": &"beam_on", "shooter": shooter, "target": target})

static func beam_off(shooter: Node2D) -> void:
	if armed:
		fx.append({"kind": &"beam_off", "shooter": shooter})

static func pulse(pos: Vector2, range_px: float, duration: float) -> void:
	if armed:
		fx.append({"kind": &"pulse", "pos": pos, "range": range_px,
			"duration": duration})

static func mine_drop(id: int, path: String, pos: Vector2, floor_i: int, jump: bool) -> void:
	if armed and id > 0:
		fx.append({"kind": &"mine_drop", "id": id, "path": path, "pos": pos,
			"floor": floor_i, "jump": jump})

static func mine_clear(id: int, exploded: bool, pos: Vector2, jump: bool) -> void:
	if armed and id > 0:
		fx.append({"kind": &"mine_clear", "id": id, "exploded": exploded,
			"pos": pos, "jump": jump})

## 0 while disarmed — an id-less mine emits nothing, by design.
static func next_mine_id() -> int:
	if not armed:
		return 0
	var id := _next_mine_id
	_next_mine_id += 1
	return id

static func drain() -> Array:
	var out := queue
	queue = []
	return out

static func drain_fx() -> Array:
	var out := fx
	fx = []
	return out

static func reset() -> void:
	armed = false
	queue = []
	fx = []
	_next_shot_id = 1
	_next_mine_id = 1
