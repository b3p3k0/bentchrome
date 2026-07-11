class_name NetEvents
extends RefCounted
## Host-side event tap for things that aren't per-tick state — projectile
## births, later booms and jingles. Dependency-free and dormant: projectile-
## side code calls in (never naming Vehicle, per the combat.gd pattern), the
## MP shell arms it on the HOST only and drains the queue into each snapshot.
## Client processes never arm it, so visual-only mirrors never re-emit.

static var armed := false
static var queue: Array = []

static func projectile_spawned(scene_path: String, pos: Vector2, dir: Vector2,
		speed: float, lifetime: float, turn_rate: float, target: Node2D) -> void:
	if not armed:
		return
	queue.append({
		"kind": &"projectile",
		"path": scene_path,
		"pos": pos,
		"dir": dir,
		"speed": speed,
		"lifetime": lifetime,
		"turn_rate": turn_rate,
		"target": target,  # resolved to an actor index at drain time
	})

static func drain() -> Array:
	var out := queue
	queue = []
	return out

static func reset() -> void:
	armed = false
	queue = []
