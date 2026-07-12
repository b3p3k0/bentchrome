class_name NetEvents
extends RefCounted
## Host-side event tap for things that aren't per-tick state — projectile
## births, later booms and jingles. Dependency-free and dormant: projectile-
## side code calls in (never naming Vehicle, per the combat.gd pattern), the
## MP shell arms it on the HOST only and drains the queue into each snapshot.
## Client processes never arm it, so visual-only mirrors never re-emit.

static var armed := false
static var queue: Array = []
static var _next_shot_id := 1

static func projectile_spawned(scene_path: String, pos: Vector2, dir: Vector2,
		speed: float, lifetime: float, turn_rate: float, target: Node2D) -> int:
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

static func drain() -> Array:
	var out := queue
	queue = []
	return out

static func reset() -> void:
	armed = false
	queue = []
	_next_shot_id = 1
