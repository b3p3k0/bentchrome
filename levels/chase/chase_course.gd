extends RefCounted
## The pre-rolled Buzzard Run: a seeded plan of chunk_defs entries long enough
## that a top-speed run can't outrun it (190s x 640 px/s, plus margin). The
## whole future is known at boot — the GPS reads turns ahead, the streamer
## instantiates only a window. Course distance d = -world_y (north is up).
## sample(d) is the single geometry authority: centerline x and half-width,
## with widths TAPERed across chunk seams so narrows never step.

const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

static var TARGET_LEN := 130000.0
static var PICKUP_EVERY := 9000.0   # max px between pickup chunks
static var SPINE_BOUND := 800.0     # meander: curves must bend back inside this
static var RARE_SPACING := 15000.0  # min px between landmark set pieces
const TAPER := 300.0                # width blend distance past a chunk seam

var plan: Array = []      # {name, def, start_d, entry_x, exit_x, entry_half_w, stations}
var total_len := 0.0
var seed_used := 0

func pre_roll(seed_val: int) -> void:
	plan.clear()
	total_len = 0.0
	seed_used = seed_val
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_append(&"straight")   # calm launch — the horde spawns into these
	_append(&"straight")
	var since_pickup := total_len  # the launch counts toward the first crate
	var since_rare := RARE_SPACING * 0.5  # first landmark lands mid-early
	while total_len < TARGET_LEN:
		var name := _pick(rng, since_pickup, since_rare)
		_append(name)
		var picked_def: Dictionary = ChunkDefs.DEFS[name]
		var picked_len: float = picked_def["len"]
		since_pickup = 0.0 if name == &"pickup" else since_pickup + picked_len
		since_rare = 0.0 if name in ChunkDefs.RARE else since_rare + picked_len

func _append(name: StringName) -> void:
	var def: Dictionary = ChunkDefs.DEFS[name]
	var entry_x := 0.0
	var entry_half: float = def["half_w"]
	if not plan.is_empty():
		var prev: Dictionary = plan[plan.size() - 1]
		entry_x = prev["exit_x"]
		var prev_def: Dictionary = prev["def"]
		entry_half = prev_def["half_w"]
	# Stations: centerline control points in chunk-local (d, x_off), endpoints
	# implied — every def gets [0,0] and [len, exit_dx] bookends here.
	var stations: Array = [Vector2.ZERO]
	if def.has("path"):
		for pt in def["path"]:
			stations.append(Vector2(pt[0], pt[1]))
	stations.append(Vector2(def["len"], def["exit_dx"]))
	plan.append({
		"name": name,
		"def": def,
		"start_d": total_len,
		"entry_x": entry_x,
		"exit_x": entry_x + def["exit_dx"],
		"entry_half_w": entry_half,
		"stations": stations,
	})
	total_len += def["len"]

func _pick(rng: RandomNumberGenerator, since_pickup: float, since_rare: float) -> StringName:
	if since_pickup > PICKUP_EVERY:
		return &"pickup"
	var prev_name: StringName = plan[plan.size() - 1]["name"]
	var exit_x: float = plan[plan.size() - 1]["exit_x"]
	var pool: Array = []
	var weight_sum := 0.0
	for name in ChunkDefs.WEIGHTS:
		if name == prev_name and name in ChunkDefs.NO_REPEAT:
			continue
		if name in ChunkDefs.RARE and since_rare < RARE_SPACING:
			continue  # landmarks stay landmarks — one per stretch
		if name == &"curve_l" and exit_x < -SPINE_BOUND:
			continue  # already far left — bend back toward the spine
		if name == &"curve_r" and exit_x > SPINE_BOUND:
			continue
		pool.append(name)
		weight_sum += ChunkDefs.WEIGHTS[name]
	var roll := rng.randf() * weight_sum
	for name in pool:
		roll -= ChunkDefs.WEIGHTS[name]
		if roll <= 0.0:
			return name
	return pool[pool.size() - 1]

func chunk_index_at(d: float) -> int:
	if plan.is_empty() or d <= 0.0:
		return 0
	var lo := 0
	var hi := plan.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		var mid_start: float = plan[mid]["start_d"]
		if mid_start <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo

## The geometry authority: centerline x and drivable half-width at distance d.
func sample(d: float) -> Dictionary:
	d = clampf(d, 0.0, total_len - 0.001)
	var entry: Dictionary = plan[chunk_index_at(d)]
	var local: float = d - entry["start_d"]
	var stations: Array = entry["stations"]
	var off: float = stations[stations.size() - 1].y
	for i in stations.size() - 1:
		var a: Vector2 = stations[i]
		var b: Vector2 = stations[i + 1]
		if local <= b.x:
			var t := 0.0 if b.x <= a.x else (local - a.x) / (b.x - a.x)
			off = lerpf(a.y, b.y, t)
			break
	var def: Dictionary = entry["def"]
	var entry_x: float = entry["entry_x"]
	var entry_half: float = entry["entry_half_w"]
	var own_half: float = def["half_w"]
	var half := lerpf(entry_half, own_half, clampf(local / TAPER, 0.0, 1.0))
	return {"x": entry_x + off, "half_w": half}

## First bend at or past d — the GPS's "next turn" arrow.
func next_turn_after(d: float) -> Dictionary:
	var i := chunk_index_at(d)
	while i < plan.size():
		var entry: Dictionary = plan[i]
		var def: Dictionary = entry["def"]
		var start: float = entry["start_d"]
		var dx: float = def["exit_dx"]
		if absf(dx) > 100.0 and start > d:
			return {"dist": start - d, "dir": signf(dx)}
		i += 1
	return {"dist": INF, "dir": 0.0}
