extends RefCounted
## Flattened-remains painter for destroyed world props: deterministic seeded
## debris/scorch descriptors in the prop's local space, drawn by the dying
## node's own _draw dead branch (the flatten-in-place death state — visible,
## collisionless, driven over with zero gameplay effect). Same three render
## kinds as vehicles/paint/wear.gd so draw_marks stays a tiny match:
##   {"kind": &"stroke", "points": PackedVector2Array, "width": float, "color": Color}
##   {"kind": &"poly",   "points": PackedVector2Array, "color": Color}
##   {"kind": &"blob",   "pos": Vector2, "radius": float, "color": Color}
## No class_name — preload by path. Never references any prop class.

const SPILL := 1.1        # debris may spill to 1.1x the footprint half-size
const REF_AREA := 9216.0  # 96x96 block = mark-count scale 1.0
const COUNT_MIN := 0.35
const COUNT_MAX := 1.5
const SOOT := Color(0.05, 0.05, 0.06, 0.85)
const SHADOW := Color(0.0, 0.0, 0.0, 0.18)

## The statics-never-move position hash (derelict palette idiom): same prop,
## same rubble, every run and every LAN peer.
static func remains_seed(position: Vector2, salt: int = 0) -> int:
	return int(absf(position.x * 7.0 + position.y * 13.0)) + salt

## PURE: same args -> identical descriptor list.
static func generate(half_size: Vector2, flavor: StringName, base: Color,
		dark: Color, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := clampf(4.0 * half_size.x * half_size.y / REF_AREA, COUNT_MIN, COUNT_MAX)
	var out: Array = []
	# Every flavor sits on a settled ground-shadow patch — the "something
	# happened here" read even at overview zoom.
	out.append(_patch(rng, half_size * 0.9, SHADOW))
	match flavor:
		&"scorch":
			_scorch(rng, out, half_size, base, dark)
		&"splinter":
			_splinter(rng, out, half_size, base, dark, k)
		&"crumple":
			_crumple(rng, out, half_size, base, dark)
		_:
			_debris(rng, out, half_size, base, dark, k)
	return out

static func draw_marks(c: CanvasItem, marks: Array) -> void:
	for m in marks:
		match m.kind:
			&"stroke":
				c.draw_polyline(m.points, m.color, m.width)
			&"poly":
				c.draw_colored_polygon(m.points, m.color)
			&"blob":
				c.draw_circle(m.pos, m.radius, m.color)

static func _clamp_pt(p: Vector2, half: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -half.x * SPILL, half.x * SPILL),
		clampf(p.y, -half.y * SPILL, half.y * SPILL))

## Irregular 6-vert patch roughly filling `extent` — ground shadow, slab, soot disc.
static func _patch(rng: RandomNumberGenerator, extent: Vector2, color: Color) -> Dictionary:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.25, 0.25)
		pts.append(Vector2(cos(a) * extent.x, sin(a) * extent.y) * rng.randf_range(0.8, 1.0))
	return {"kind": &"poly", "points": pts, "color": color}

## Small angular shard polygon at pos.
static func _shard(rng: RandomNumberGenerator, half: Vector2, pos: Vector2,
		radius: float, color: Color) -> Dictionary:
	var pts := PackedVector2Array()
	var verts := 3 + (rng.randi() % 2)  # 3-4 — jagged chunks, never neat
	for i in verts:
		var a := TAU * i / verts + rng.randf_range(-0.4, 0.4)
		pts.append(_clamp_pt(pos + Vector2.RIGHT.rotated(a) * radius
			* rng.randf_range(0.6, 1.0), half))
	return {"kind": &"poly", "points": pts, "color": color}

static func _spot(rng: RandomNumberGenerator, half: Vector2) -> Vector2:
	return Vector2(rng.randf_range(-0.85, 0.85) * half.x,
		rng.randf_range(-0.85, 0.85) * half.y)

## Default rubble: angular chunks in the prop's palette plus dark flecks.
static func _debris(rng: RandomNumberGenerator, out: Array, half: Vector2,
		base: Color, dark: Color, k: float) -> void:
	var chunk_r := clampf(minf(half.x, half.y) * 0.28, 3.0, 9.0)
	for i in maxi(2, roundi(8.0 * k)):
		var color := base if rng.randf() < 0.6 else dark
		out.append(_shard(rng, half, _spot(rng, half),
			chunk_r * rng.randf_range(0.6, 1.2), color))
	for i in maxi(2, roundi(4.0 * k)):
		out.append({"kind": &"blob", "pos": _spot(rng, half),
			"radius": rng.randf_range(1.2, 2.6), "color": dark})

## Explosive footprint: soot crater, charred ring, radiating burn streaks,
## a couple of surviving painted shards so the wreck keeps its identity.
static func _scorch(rng: RandomNumberGenerator, out: Array, half: Vector2,
		base: Color, dark: Color) -> void:
	var r := minf(half.x, half.y)
	out.append(_patch(rng, Vector2(r, r) * 0.75, SOOT))
	var ring := PackedVector2Array()
	for i in 17:  # closed jagged ring at the blast rim
		var a := TAU * i / 16.0
		ring.append(_clamp_pt(Vector2.RIGHT.rotated(a) * r
			* rng.randf_range(0.82, 1.02), half))
	out.append({"kind": &"stroke", "points": ring, "width": 1.6,
		"color": Color(SOOT.r, SOOT.g, SOOT.b, 0.55)})
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector2.RIGHT.rotated(a)
		out.append({"kind": &"stroke", "points": PackedVector2Array([
			_clamp_pt(dir * r * 0.4, half),
			_clamp_pt(dir * r * rng.randf_range(0.95, 1.08), half)]),
			"width": rng.randf_range(1.4, 2.4), "color": SOOT})
	for i in 3:
		out.append(_shard(rng, half, _spot(rng, half) * 0.6,
			rng.randf_range(2.5, 4.5), dark))
	for i in 2:
		out.append(_shard(rng, half, _spot(rng, half) * 0.7,
			rng.randf_range(2.0, 3.5), base))

## Wood: pale shards strewn along the long axis plus snapped-plank strokes.
static func _splinter(rng: RandomNumberGenerator, out: Array, half: Vector2,
		base: Color, dark: Color, k: float) -> void:
	var long_x := half.x >= half.y
	for i in maxi(3, roundi(10.0 * k)):
		var pos := _spot(rng, half)
		var length := rng.randf_range(4.0, 10.0) * clampf(maxf(half.x, half.y) / 48.0, 0.5, 1.4)
		var a := (0.0 if long_x else PI / 2.0) + rng.randf_range(-0.5, 0.5)
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal() * rng.randf_range(0.8, 1.6)
		out.append({"kind": &"poly", "points": PackedVector2Array([
			_clamp_pt(pos - dir * length * 0.5, half),
			_clamp_pt(pos + side, half),
			_clamp_pt(pos + dir * length * 0.5, half),
			_clamp_pt(pos - side, half)]),
			"color": base if rng.randf() < 0.7 else dark})
	for i in maxi(1, roundi(3.0 * k)):
		var pos := _spot(rng, half)
		var a := (0.0 if long_x else PI / 2.0) + rng.randf_range(-0.35, 0.35)
		var dir := Vector2.RIGHT.rotated(a)
		var mid := pos + dir.orthogonal() * rng.randf_range(1.0, 2.5)
		out.append({"kind": &"stroke", "points": PackedVector2Array([
			_clamp_pt(pos - dir * 7.0, half), _clamp_pt(mid, half),
			_clamp_pt(pos + dir * 7.0, half)]),
			"width": 1.4, "color": dark})

## Metal: one flattened buckled slab with fold lines and torn-edge shards.
static func _crumple(rng: RandomNumberGenerator, out: Array, half: Vector2,
		base: Color, dark: Color) -> void:
	var slab := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		slab.append(_clamp_pt(corner * half * 0.85
			+ Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)), half))
	out.append({"kind": &"poly", "points": slab, "color": base})
	for i in 4:
		var t := rng.randf_range(-0.6, 0.6)
		var across := half.x >= half.y
		var p_a := Vector2(-half.x * 0.7, t * half.y) if across \
			else Vector2(t * half.x, -half.y * 0.7)
		var p_b := Vector2(half.x * 0.7, t * half.y + rng.randf_range(-6.0, 6.0)) if across \
			else Vector2(t * half.x + rng.randf_range(-6.0, 6.0), half.y * 0.7)
		out.append({"kind": &"stroke", "points": PackedVector2Array([
			_clamp_pt(p_a, half),
			_clamp_pt((p_a + p_b) * 0.5 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), half),
			_clamp_pt(p_b, half)]),
			"width": 1.5, "color": dark})
	for i in 3:
		out.append(_shard(rng, half, _spot(rng, half),
			rng.randf_range(2.5, 5.0), dark))
