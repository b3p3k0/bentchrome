extends RefCounted
## A cutoff's corridor — the ground between the embankment's foot and the
## treeline — as three bands riding the trail's stations: a packed dirt
## TRACK down the middle and a long-grass SHOULDER each side of it. This
## script owns the band geometry (clipped so nothing spills onto the road)
## and the long-grass paint; chunk_builder._build_cutoff_trail samples the
## trail and turns the bands into zones. The design: the track is the fast
## line, the shoulders LOOK like uncut grass but RUN MUD underneath — in
## this game grass is faster than dirt (0.9 vs 0.85 top), so an honest grass
## shoulder would be the fast line and the track the trap; mud (0.6 top) is
## what bogs. Hold the track and you fly, blow it and the shoulder swallows
## your pace. That is the gamble.

const SAMPLE := 60.0        # px along the trail between band samples
const TEAR := [-6.0, 14.0]  # the bed's ragged lip: each edge torn outward by this much

const OVERLAY := Color(0.0, 0.08, 0.0, 0.48)   # over the arena grass: the uncut read (the zone's own grass dress brightens first; this wins)
const TUFT_DARK := Color(0.06, 0.15, 0.04, 0.95)
const TUFT_MID := Color(0.24, 0.42, 0.14, 0.9)
const TUFT_EVERY := 22.0    # px along the band between tuft rows
const TUFTS_PER_ROW := 3    # scattered across the band's width
const BLADE := [   # a three-blade tuft, base at the origin, 15px tall (8 on screen at the chase zoom)
	Vector2(-7.0, 1.5), Vector2(-6.5, -10.0), Vector2(-3.0, -3.0), Vector2(0.0, -15.0),
	Vector2(3.0, -3.0), Vector2(6.5, -11.0), Vector2(7.0, 1.5),
]

## The d's a corridor is sampled at: every SAMPLE px from the first station
## to the last, plus both sides of every mouth end that lies between (the
## corridor's floor steps there — sampled on both sides, the step is a clean
## notch, not a slant across the slope).
static func sample_ds(cf: Dictionary) -> Array:
	var pts: Array = cf["trail"]
	var d_from: float = pts[0][0]
	var d_to: float = pts[pts.size() - 1][0]
	var ds: Array = []
	var d := d_from
	while d < d_to:
		ds.append(d)
		d += SAMPLE
	ds.append(d_to)
	for g in cf["gaps"]:
		for edge in [float(g[0]), float(g[1])]:
			if edge > d_from and edge < d_to:
				ds.append(edge - 0.5)
				ds.append(edge + 0.5)
	ds.sort()
	return ds

## One band between two offsets from the trail's centre (positive = away
## from the road), as the edge pair chunk_builder._zone_strip takes.
## `samples` are Vector3(d, trail centre x, floor x) per sample_ds entry —
## the floor being the road-side limit of the corridor's ground (the wall's
## foot, the road's verge through a mouth). Every point is pushed out to the
## floor and samples the floor swallows whole are dropped, so a band STARTS
## as a wedge where it clears the verge, never on the road. An rng tears
## both edges outward (the bed's ragged lip) before the clip.
static func band(samples: Array, side: float, off_a: float, off_b: float, rng: RandomNumberGenerator) -> Array:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for s in samples:
		var d: float = s.x
		var tx: float = s.y
		var floor_x: float = s.z
		var tear_a: float = rng.randf_range(TEAR[0], TEAR[1]) if rng != null else 0.0
		var tear_b: float = rng.randf_range(TEAR[0], TEAR[1]) if rng != null else 0.0
		var xa: float = tx + side * (off_a - tear_a)
		var xb: float = tx + side * (off_b + tear_b)
		if side * (xa - floor_x) < 0.0:
			xa = floor_x
		if side * (xb - floor_x) < 0.0:
			xb = floor_x
		if side * (xb - xa) <= 2.0:
			continue
		a.append(Vector2(xa, -d))
		b.append(Vector2(xb, -d))
	return [a, b]

## A band zone's rects, tightened: _zone_strip sizes each segment's rect by
## the band's width at the segment's START, so where a band pinches toward
## the verge (the mouths' wedges) the rect's far end would overhang onto the
## verge. Each takes the NARROWER of its two ends instead — a sliver of the
## wedge goes unsensed, nothing of the road is.
static func tighten_rects(zone: Area2D, edge_a: PackedVector2Array, edge_b: PackedVector2Array) -> void:
	var i := 0
	for sub in zone.get_children():
		if not (sub is CollisionShape2D) or i + 1 >= edge_a.size():
			continue
		var shape := sub.shape as RectangleShape2D
		shape.size.y = minf(edge_a[i].distance_to(edge_b[i]), edge_a[i + 1].distance_to(edge_b[i + 1]))
		i += 1

## Long grass: the paint that makes a shoulder read as the uncut verge of a
## bike trail — darker than the mowed clearing beside it, tufty — laid OVER
## the arena grass dress the shoulder zone already wears. Paint only; the
## zone under it decides the handling. Two nodes per band however long it
## is: a darkening overlay and one Polygon2D per tone carrying every tuft as
## its own sub-polygon (the `polygons` index list), so a chunk's shoulders
## cost the streamer nothing to free.
static func long_grass(parent: Node2D, band_name: String, edge_a: PackedVector2Array, edge_b: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	if edge_a.size() < 2 or edge_a.size() != edge_b.size():
		return
	var overlay := Polygon2D.new()
	overlay.name = band_name + "Shade"
	overlay.color = OVERLAY
	overlay.polygon = _strip(edge_a, edge_b)
	overlay.z_index = -1
	parent.add_child(overlay)
	var verts: Array = [PackedVector2Array(), PackedVector2Array()]
	var polys: Array = [[], []]
	for i in edge_a.size() - 1:
		var seg_len: float = edge_a[i].distance_to(edge_a[i + 1])
		var rows := maxi(int(seg_len / TUFT_EVERY), 1)
		for r in rows:
			var t := (float(r) + rng.randf()) / float(rows)
			var a := edge_a[i].lerp(edge_a[i + 1], t)
			var b := edge_b[i].lerp(edge_b[i + 1], t)
			if a.distance_to(b) < 14.0:
				continue   # the band has pinched out (a mouth's wedge)
			for _k in TUFTS_PER_ROW:
				var at := a.lerp(b, rng.randf_range(0.08, 0.92))
				var tone := rng.randi() % 2
				var scale := rng.randf_range(0.8, 1.35)
				var rot := rng.randf_range(-0.35, 0.35)
				var base: int = verts[tone].size()
				var idx := PackedInt32Array()
				for p in BLADE:
					verts[tone].append(at + (p * scale).rotated(rot))
					idx.append(base)
					base += 1
				polys[tone].append(idx)
	for tone in 2:
		if polys[tone].is_empty():
			continue
		var tufts := Polygon2D.new()
		tufts.name = band_name + ("TuftsDark" if tone == 0 else "TuftsMid")
		tufts.color = TUFT_DARK if tone == 0 else TUFT_MID
		tufts.polygon = verts[tone]
		tufts.polygons = polys[tone]
		tufts.z_index = -1
		parent.add_child(tufts)

static func _strip(forward: PackedVector2Array, back: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(forward)
	for i in range(back.size() - 1, -1, -1):
		out.append(back[i])
	return out
