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

## The zones' kill shape sits this far inside the painted rect, per side.
const KILL_INSET := 24.0
## Hard-guard inflation. Must stay under KILL_INSET or the guard fires on
## legally driveable rim (bridge lanes sit ~48px out).
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

# One shared slab pass keeps this per-frame path allocation-free. Returns the
# entry fraction, entry axis, or exit fraction according to the flags.
static func _segment_entry(rect: Rect2, from: Vector2, to: Vector2,
		margin: float, axis_only: bool, exit_only := false) -> float:
	var r := rect.grow(margin)
	var d := to - from
	var t0 := 0.0
	var t1 := 1.0
	var entry_axis := -1
	for axis in 2:
		var p: float = d[axis]
		var lo: float = r.position[axis] - from[axis]
		var hi: float = lo + r.size[axis]
		if absf(p) < 0.0001:
			if lo > 0.0 or hi < 0.0:
				return -1.0 if axis_only else CLEAR
		else:
			var ta := lo / p
			var tb := hi / p
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			if ta > t0:
				entry_axis = axis
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return -1.0 if axis_only else CLEAR
	if axis_only:
		return float(entry_axis)
	return t1 if exit_only else t0

## Liang-Barsky slab test of one segment against one (margin-grown) rect.
## Returns the entry fraction t in [0, 1] (0 = `from` already inside), or
## CLEAR (2.0) when the segment misses.
static func segment_entry_t(rect: Rect2, from: Vector2, to: Vector2, margin := 0.0) -> float:
	return _segment_entry(rect, from, to, margin, false)

## Axis of the face crossed on entry: 0 = west/east, 1 = north/south.
## Returns -1 on a miss or when `from` is already inside the grown rect.
static func segment_entry_axis(rect: Rect2, from: Vector2, to: Vector2, margin := 0.0) -> int:
	return int(_segment_entry(rect, from, to, margin, true))

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

static func _escape_safe(all: Array[Rect2], from: Vector2, endpoint: Vector2,
		reach: float, margin: float) -> bool:
	for rect: Rect2 in all:
		var grown := rect.grow(margin)
		if grown.has_point(endpoint):
			return false
		if grown.has_point(from):
			var exit_t := _segment_entry(rect, from, endpoint, margin, false, true)
			if exit_t * reach > margin + KILL_INSET:
				return false
		elif _segment_entry(rect, from, endpoint, margin, false) < CLEAR:
			return false
	return true

## Picks a hazard-safe world direction for a committed escape. A car already
## on a forgiveness band may cross that band only long enough to leave it;
## every landing must finish outside every grown rect.
static func escape_direction(tree: SceneTree, from: Vector2, dir: Vector2,
		reach: float, margin := GUARD_MARGIN) -> Vector2:
	var all := rects(tree)
	if all.is_empty():
		return dir
	if dir.length_squared() <= 0.0001 or reach <= 0.0:
		return Vector2.ZERO
	var requested := dir.normalized()
	var band_idx := -1
	var face_axis := -1
	var face_dist := INF
	var outward := Vector2.ZERO
	for i in all.size():
		var rect: Rect2 = all[i]
		if not rect.grow(margin).has_point(from):
			continue
		var offset := from - rect.get_center()
		var half := rect.size * 0.5
		var axis := 0
		if absf(offset.x) <= half.x and absf(offset.y) > half.y:
			axis = 1
		elif not (absf(offset.x) > half.x and absf(offset.y) <= half.y):
			axis = 0 if absf(absf(offset.x) - half.x) \
				<= absf(absf(offset.y) - half.y) else 1
		var dist := absf(absf(offset[axis]) - half[axis])
		var normal := Vector2.ZERO
		normal[axis] = 1.0 if offset[axis] >= 0.0 else -1.0
		if dist < face_dist - 0.001:
			face_dist = dist
			band_idx = i
			face_axis = axis
			outward = normal
		elif absf(dist - face_dist) <= 0.001:
			outward += normal
	if outward != Vector2.ZERO:
		outward = outward.normalized()
	if band_idx < 0:
		band_idx = segment_hit(tree, from, from + requested * reach, margin)
		if band_idx >= 0:
			face_axis = segment_entry_axis(all[band_idx], from,
				from + requested * reach, margin)
	var tangent := Vector2.DOWN if face_axis == 0 else Vector2.RIGHT
	if tangent.dot(requested) < 0.0:
		tangent = -tangent
	var candidates: Array[Vector2] = [requested]
	if outward != Vector2.ZERO:
		candidates.append(outward)
	candidates.append_array([tangent, -tangent, -requested])
	for candidate: Vector2 in candidates:
		var endpoint := from + candidate * reach
		if _escape_safe(all, from, endpoint, reach, margin):
			return candidate
	return Vector2.ZERO

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
