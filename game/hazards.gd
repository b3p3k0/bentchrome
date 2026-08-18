extends RefCounted
## Lethal-hazard geometry service, dependency-free ON PURPOSE — same contract
## as floors.gd: no class_name, no preloads, duck-typing only. Consumers
## preload by path (const Hazards := preload("res://game/hazards.gd")).
##
## Deep-water and pit zones join &"lethal_hazards" in their _ready and expose
## `size` + `global_position`; this file turns the group into queryable world
## rects so the AI can SEE what would kill it — the zones themselves live on
## collision_layer 0 and no raycast can ever hit them. Rects are the PAINTED
## extents (the kill shape is inset 24px/side), so every query is naturally
## conservative before margins are applied.
##
## Authoring contract: zones are axis-aligned (rotation is ignored — nothing
## authored rotates them, and slab math is the price of keeping this hot path
## raycast-free). Hazards are floor-agnostic lethal, exactly like the kill
## itself: zones poll collision_mask 1 and every grounded car carries bit 1
## on every floor. Airborne exemption is the CALLER's job (height > 0).

## Hard-guard inflation. Must stay under the zones' 24px/side kill inset or
## the guard fires on legally driveable rim (bridge lanes sit ~48px out).
static var GUARD_MARGIN := 20.0
## Detour/scoring inflation. Must keep the 320px bridge gaps open as a
## corridor (320 - 2*72 = 176px ≥ any car width).
static var PLAN_MARGIN := 72.0
## Waypoint offset past a blocking rect's end — lands mid-gap at Capital.
static var DETOUR_CLEARANCE := 128.0

## Clear sentinel for segment_entry_t (any value > 1.0 means "no hit").
const CLEAR := 2.0

# One rect build per physics frame TOTAL across every driver. Keyed on frame
# AND group count so a zone entering/leaving the tree mid-frame (scene swaps,
# test fixtures) invalidates without anyone having to remember to.
static var _cache_frame := -1
static var _cache_count := -1
static var _cache_rects: Array[Rect2] = []

static func rects(tree: SceneTree) -> Array[Rect2]:
	if tree == null:
		return []
	var frame := Engine.get_physics_frames()
	var count := tree.get_node_count_in_group(&"lethal_hazards")
	if frame == _cache_frame and count == _cache_count:
		return _cache_rects
	var out: Array[Rect2] = []
	for zone in tree.get_nodes_in_group(&"lethal_hazards"):
		if not is_instance_valid(zone):
			continue
		var sz: Variant = zone.get("size")
		if sz is Vector2 and zone is Node2D:
			out.append(Rect2((zone as Node2D).global_position - (sz as Vector2) * 0.5, sz))
	_cache_frame = frame
	_cache_count = count
	_cache_rects = out
	return out

static func point_inside(tree: SceneTree, p: Vector2, margin := 0.0) -> bool:
	for r in rects(tree):
		if r.grow(margin).has_point(p):
			return true
	return false

## Liang-Barsky slab test of one segment against one (margin-grown) rect.
## Returns the entry fraction t in [0, 1] (0 = `from` already inside), or
## CLEAR (2.0) when the segment misses.
static func segment_entry_t(rect: Rect2, from: Vector2, to: Vector2, margin := 0.0) -> float:
	var r := rect.grow(margin)
	var d := to - from
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var p: float = d[axis]
		var lo: float = r.position[axis] - from[axis]
		var hi: float = lo + r.size[axis]
		if absf(p) < 0.0001:
			if lo > 0.0 or hi < 0.0:
				return CLEAR
		else:
			var ta := lo / p
			var tb := hi / p
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return CLEAR
	return t0

## Index (into rects()) of the FIRST rect the segment enters, or -1.
static func segment_hit(tree: SceneTree, from: Vector2, to: Vector2, margin := 0.0) -> int:
	var best := -1
	var best_t := CLEAR
	var all := rects(tree)
	for i in all.size():
		var t := segment_entry_t(all[i], from, to, margin)
		if t < best_t:
			best_t = t
			best = i
	return best

static func segment_blocked(tree: SceneTree, from: Vector2, to: Vector2, margin := 0.0) -> bool:
	return segment_hit(tree, from, to, margin) >= 0

## Where to drive AROUND the first rect blocking from->to. Returns [] when the
## beeline is clear; otherwise up to two candidates past the blocking rect's
## long-axis ends, each {point: Vector2, normal: Vector2, clear_from: bool}.
## `normal` is the short-axis direction back toward the approach side (the
## caller's bridgehead axis). Chained rects (Capital's river is three, gapped
## at the bridges) are handled by filtering: an end that pokes into a
## NEIGHBOR rect is not a gap and is dropped, so the surviving candidate IS
## the bridge. Ordering: clear-approach candidates first, then shortest total
## path from -> C -> to.
static func detour_candidates(tree: SceneTree, from: Vector2, to: Vector2,
		margin := PLAN_MARGIN) -> Array[Dictionary]:
	var idx := segment_hit(tree, from, to, margin)
	if idx < 0:
		return []
	var r: Rect2 = rects(tree)[idx]
	var center := r.get_center()
	var long_dir := Vector2.RIGHT if r.size.x >= r.size.y else Vector2.DOWN
	var half_long: float = maxf(r.size.x, r.size.y) * 0.5
	var short_dir := Vector2.DOWN if r.size.x >= r.size.y else Vector2.RIGHT
	var side := signf(short_dir.dot(from - center))
	var normal := short_dir * (side if side != 0.0 else 1.0)
	var reach := half_long + margin + DETOUR_CLEARANCE
	var out: Array[Dictionary] = []
	for s: float in [-1.0, 1.0]:
		var c := center + long_dir * (reach * s)
		if point_inside(tree, c, margin * 0.5):
			continue  # this end pokes into a chained neighbor — not a gap
		out.append({
			"point": c,
			"normal": normal,
			"clear_from": not segment_blocked(tree, from, c, margin * 0.5),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["clear_from"] != b["clear_from"]:
			return a["clear_from"]
		var pa: Vector2 = a["point"]
		var pb: Vector2 = b["point"]
		return from.distance_to(pa) + pa.distance_to(to) \
			< from.distance_to(pb) + pb.distance_to(to))
	return out
