extends RefCounted
## Turns a chase_course plan entry into live geometry: asphalt + lane paint,
## drivable grass/dirt verges (TerrainZone strips), opaque embankment slopes
## backed by layer-2 walls (the "steep hill, no way up" read), props, and
## pickups. Everything is a child of one chunk root so the streamer frees a
## whole segment in one call. Chunk-local: root sits at (0, -start_d); child
## x is world x (root x = 0), child y = -(d into chunk).

const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const RoadMarksScript := preload("res://environment/road_marks.gd")
const DerelictScene := preload("res://environment/derelict_car.tscn")
const BlockScene := preload("res://environment/destructible_block.tscn")
const ClutterScene := preload("res://environment/clutter.tscn")
const AmmoScene := preload("res://environment/ammo_pickup.tscn")
const HealScene := preload("res://environment/heal_pickup.tscn")
const BoostScene := preload("res://environment/boost_pickup.tscn")
const JumpPadScript := preload("res://environment/jump_pad.gd")
const StreetDecoScript := preload("res://environment/street_deco.gd")
const DeepWaterScene := preload("res://environment/deep_water_zone.tscn")
const LightKit := preload("res://environment/light_kit.gd")
const HighwayDecoScript := preload("res://levels/chase/highway_deco.gd")
const SurfacePaint := preload("res://levels/chase/surface_paint.gd")   # the arenas' surface dress
const SIGN_EVERY := 1400.0        # course px between highway signs (sides alternate)
const BILLBOARD_EVERY := 4300.0   # course px between billboards

const STEP := 175.0        # geometry sample spacing along the chunk
const FUNNEL_LEN := 260.0  # px a mouth's resuming embankment chamfers over (its inner corner trails its outer)
const SHOULDER_W := 90.0   # drivable verge outside the asphalt (grip penalty)
const EMBANK_W := 130.0    # painted slope width; the wall runs its inner edge
const TAPER := 300.0       # must match chase_course.TAPER

const ChunkDefs := preload("res://levels/chase/chunk_defs.gd")

# Driveable surfaces are painted by surface_paint.gd — the arenas' colours
# and speckle — so the road, the verges and every bed read as the surfaces
# the player already knows. Only structures and accents keep flat tones here.
const ASPHALT := SurfacePaint.ASPHALT
const DECK := Color(0.2, 0.2, 0.23)
const DECK_RAIL := Color(0.3, 0.3, 0.34)
const REBAR := Color(0.45, 0.28, 0.16)
const SLOPE_FILL := {
	&"grass": Color(0.2, 0.29, 0.16),
	&"dirt": Color(0.4, 0.3, 0.18),
}

static func build(entry: Dictionary) -> Node2D:
	var def: Dictionary = entry["def"]
	var start_d: float = entry["start_d"]
	var root := Node2D.new()
	root.name = "Chunk%d" % int(start_d)
	root.position = Vector2(0.0, -start_d)
	# Sample stations along the chunk once; every band hangs off them.
	var len: float = def["len"]
	var n := maxi(int(ceilf(len / STEP)), 2)
	var ds: Array = []          # d into chunk
	var cx: Array = []          # centerline world x
	var half: Array = []        # asphalt half-width (seam-tapered)
	for i in n + 1:
		var d := len * float(i) / float(n)
		ds.append(d)
		cx.append(_center_x(entry, d))
		half.append(_half_w(entry, d))
	_paint_road(root, ds, cx, half)
	_road_wear(root, entry, ds, cx, half)
	var shoulder: StringName = def.get("shoulder", &"grass")
	_build_cutoff(root, entry)   # before the walls: its clearing paints UNDER the embankment
	for side in [-1.0, 1.0]:
		_build_shoulder(root, ds, cx, half, side, shoulder)
		_build_embankment(root, entry, side, shoulder)
	_build_cutoff_trail(root, entry)   # after the shoulders: the trail paints OVER the verge at the mouths
	_build_medians(root, entry)
	_build_washout(root, entry)
	_place_props(root, entry)
	_place_pickups(root, entry)
	_roadside_flair(root, entry, ds, cx, half)
	_highway_dressing(root, entry, ds, cx, half)
	match def.get("set_piece", &""):
		&"overpass":
			_overpass(root, entry)
		&"truckstop":
			_truckstop(root, entry)
		&"bridge_out":
			_bridge_out(root, entry)
		&"tollbooth":
			_tollbooth(root, entry)
		&"jackknife":
			_jackknife(root, entry)
	return root

## Centerline x at d — same stations math as chase_course.sample().
static func _center_x(entry: Dictionary, d: float) -> float:
	var stations: Array = entry["stations"]
	var entry_x: float = entry["entry_x"]
	var off: float = stations[stations.size() - 1].y
	for i in stations.size() - 1:
		var a: Vector2 = stations[i]
		var b: Vector2 = stations[i + 1]
		if d <= b.x:
			var t := 0.0 if b.x <= a.x else (d - a.x) / (b.x - a.x)
			off = lerpf(a.y, b.y, t)
			break
	return entry_x + off

static func _half_w(entry: Dictionary, d: float) -> float:
	var def: Dictionary = entry["def"]
	var entry_half: float = entry["entry_half_w"]
	var own_half: float = def["half_w"]
	return lerpf(entry_half, own_half, clampf(d / TAPER, 0.0, 1.0))

static func _paint_road(root: Node2D, ds: Array, cx: Array, half: Array) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var center := PackedVector2Array()
	var edge_l := PackedVector2Array()
	var edge_r := PackedVector2Array()
	for i in ds.size():
		var y: float = -ds[i]
		var c: float = cx[i]
		var h: float = half[i]
		left.append(Vector2(c - h, y))
		right.append(Vector2(c + h, y))
		center.append(Vector2(c, y))
		edge_l.append(Vector2(c - h + 26.0, y))
		edge_r.append(Vector2(c + h - 26.0, y))
	var asphalt := Polygon2D.new()
	asphalt.name = "Asphalt"
	asphalt.color = ASPHALT
	asphalt.material = SurfacePaint.asphalt_material()   # the arenas' worn-tarmac grain
	asphalt.polygon = _strip(left, right)
	asphalt.z_index = -1
	root.add_child(asphalt)
	# The arenas' survey grid, clipped to the road — the same faint 128px
	# lines under every arena's asphalt, world-anchored so seams don't show.
	var grid := SurfacePaint.RoadGrid.new()
	grid.name = "RoadGrid"
	grid.ds = ds
	grid.cx = cx
	grid.half = half
	grid.start_d = -root.position.y
	grid.z_index = -1
	root.add_child(grid)
	_add_marks(root, "CenterLine", center, &"dashed_yellow")
	_add_marks(root, "EdgeL", edge_l, &"dashed_white")
	_add_marks(root, "EdgeR", edge_r, &"dashed_white")

## The road has been driven on: seeded skid marks (pairs, some veering for
## the verge), tar patches over old holes, cracks, an oil stain, the odd
## splat — pure paint at z -1 over the marks, never a collider. Every chunk
## gets a little; junk and bad-road chunks get more.
static func _road_wear(root: Node2D, entry: Dictionary, ds: Array, cx: Array, half: Array) -> void:
	var def: Dictionary = entry["def"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 4242
	var chunk_len: float = def["len"]
	var busy: bool = def["kind"] in [&"bad_road", &"log_run", &"convoy", &"chicane", &"slalom"]
	var count := rng.randi_range(3, 5) + (3 if busy else 0)
	for i in count:
		var d := rng.randf_range(80.0, chunk_len - 80.0)
		var si := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
		var c: float = cx[si]
		var h: float = half[si]
		var x := c + rng.randf_range(-h + 60.0, h - 60.0)
		match rng.randi() % 6:
			0, 1:   # a skid: two dark streaks, sometimes veering
				var length := rng.randf_range(90.0, 260.0)
				var veer := rng.randf_range(-0.35, 0.35)
				for lane in [-16.0, 16.0]:
					var streak := Polygon2D.new()
					var a := Vector2(x + lane, -d)
					var b := a + Vector2(veer * length, -length)
					var w := rng.randf_range(3.0, 5.0)
					streak.polygon = PackedVector2Array([a + Vector2(-w, 0), a + Vector2(w, 0), b + Vector2(w * 0.6, 0), b + Vector2(-w * 0.6, 0)])
					streak.color = Color(0.08, 0.08, 0.09, rng.randf_range(0.45, 0.7))
					streak.z_index = -1
					root.add_child(streak)
			2:   # a tar patch: a darker blob of fresher asphalt
				var patch := Polygon2D.new()
				patch.polygon = _chunk_of_road(Vector2(x, -d), rng.randf_range(30.0, 60.0), 0.6, 7, rng)
				patch.color = ASPHALT.darkened(0.4)   # fresh tar: flat and darker than the grain
				patch.z_index = -1
				root.add_child(patch)
			3:   # cracks: a short jagged run
				var pts := PackedVector2Array()
				var at := Vector2(x, -d)
				for k in rng.randi_range(4, 7):
					pts.append(at)
					at += Vector2(rng.randf_range(-14.0, 14.0), -rng.randf_range(12.0, 30.0))
				var crack := Line2D.new()
				crack.points = pts
				crack.width = 2.0
				crack.default_color = Color(0.09, 0.09, 0.1, 0.8)
				crack.z_index = -1
				root.add_child(crack)
			4:   # an old stain: oil that dried where something sat
				var stain := Polygon2D.new()
				stain.polygon = _chunk_of_road(Vector2(x, -d), rng.randf_range(14.0, 26.0), 0.7, 8, rng)
				stain.color = Color(0.1, 0.09, 0.08, 0.6)
				stain.z_index = -1
				root.add_child(stain)
			5:   # a splat: something didn't make it across
				var splat := Polygon2D.new()
				splat.polygon = _chunk_of_road(Vector2(x, -d), rng.randf_range(9.0, 16.0), 0.55, 9, rng)
				splat.color = Color(0.42, 0.12, 0.1, 0.7)
				splat.z_index = -1
				root.add_child(splat)
				var smear := Polygon2D.new()
				smear.polygon = PackedVector2Array([
					Vector2(x - 4, -d), Vector2(x + 4, -d), Vector2(x + 2, -d - rng.randf_range(20.0, 44.0)), Vector2(x - 2, -d - rng.randf_range(20.0, 44.0)),
				])
				smear.color = Color(0.42, 0.12, 0.1, 0.45)
				smear.z_index = -1
				root.add_child(smear)

static func _add_marks(root: Node2D, mark_name: String, pts: PackedVector2Array, style: StringName) -> void:
	var marks := Node2D.new()
	marks.set_script(RoadMarksScript)
	marks.name = mark_name
	marks.points = pts
	marks.style = style
	marks.z_index = -1
	root.add_child(marks)

## Drivable verge: TerrainZone strip from the asphalt edge outward — grass
## slows a dodge, dirt loosens it; the wall waits past it.
static func _build_shoulder(root: Node2D, ds: Array, cx: Array, half: Array, side: float, shoulder: StringName) -> void:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in ds.size():
		var y: float = -ds[i]
		var e: float = cx[i] + side * half[i]
		inner.append(Vector2(e, y))
		outer.append(Vector2(e + side * SHOULDER_W, y))
	root.add_child(_zone_strip("ShoulderL" if side < 0.0 else "ShoulderR", shoulder, inner, outer))

## A TerrainZone between two edge polylines: painted strip + one rotated
## rect Col per segment. Shoulders and medians share it. The Vis wears the
## arena's colour + speckle for the surface (surface_paint.dress).
static func _zone_strip(zone_name: String, kind: StringName, edge_a: PackedVector2Array, edge_b: PackedVector2Array) -> Area2D:
	var zone := Area2D.new()
	zone.set_script(TerrainZoneScript)
	zone.name = zone_name
	zone.collision_layer = 128
	zone.collision_mask = 0
	zone.terrain_type = kind
	zone.z_index = -1
	var vis := Polygon2D.new()
	vis.name = "Vis"
	SurfacePaint.dress(vis, kind)
	vis.polygon = _strip(edge_a, edge_b)
	zone.add_child(vis)
	for i in edge_a.size() - 1:
		var mid_a := (edge_a[i] + edge_b[i]) * 0.5
		var mid_b := (edge_a[i + 1] + edge_b[i + 1]) * 0.5
		var seg := mid_b - mid_a
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(seg.length() + 6.0, edge_a[i].distance_to(edge_b[i]))
		col.shape = shape
		col.position = (mid_a + mid_b) * 0.5
		col.rotation = seg.angle()
		zone.add_child(col)
	return zone

## A zone whose paint is a torn-edged bed laid separately: strip the Vis of
## its dress (the speckle material paints whatever the colour says, so both
## have to go) and leave the Col alone.
static func _bare(zone: Area2D) -> void:
	var vis := zone.get_node(^"Vis") as Polygon2D
	vis.color = Color(0, 0, 0, 0)
	vis.material = null

## Median runs along the centerline: grass/dirt grip islands or crumple-rail
## guardrails (the Freeway Loop's) — the road diet that forces a line choice.
static func _build_medians(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("median"):
		return
	var idx := 0
	for m in def["median"]:
		var kind: StringName = m["kind"]
		var from_d: float = m["from"]
		var to_d: float = m["to"]
		if kind == &"rail":
			var d := from_d
			while d <= to_d:
				var rail := BlockScene.instantiate()
				rail.position = Vector2(_center_x(entry, d), -d)
				rail.rotation = _road_angle(entry, d)
				rail.size = Vector2(110, 18)
				rail.max_hp = 20.0
				rail.deco = &"rail"
				root.add_child(rail)
				d += 150.0
		else:
			var w: float = m["half_w"]
			var a := PackedVector2Array()
			var b := PackedVector2Array()
			var n := maxi(int(ceilf((to_d - from_d) / STEP)), 1)
			for i in n + 1:
				var d2 := from_d + (to_d - from_d) * float(i) / float(n)
				var c := _center_x(entry, d2)
				a.append(Vector2(c - w, -d2))
				b.append(Vector2(c + w, -d2))
			root.add_child(_zone_strip("Median%d" % idx, kind, a, b))
		idx += 1

## Washout: the asphalt crumbles to dirt edge to edge, except for the
## surviving paved ribbon (chunk_defs.washout_lane). Two dirt TerrainZones —
## one each side of the ribbon — under an opaque dirt bed whose edge against
## the ribbon is torn, with slabs of the old road scattered across it.
static func _build_washout(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("washout"):
		return
	var w: Dictionary = def["washout"]
	var from_d: float = w["from"]
	var to_d: float = w["to"]
	var lane_half: float = float(w["lane_w"]) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 313
	var n := maxi(int(ceilf((to_d - from_d) / 90.0)), 2)
	for side in [-1.0, 1.0]:
		var outer := PackedVector2Array()   # the road edge
		var inner := PackedVector2Array()   # the ribbon's edge (the zone's true boundary)
		var torn := PackedVector2Array()    # the painted edge: torn, never ruled
		for i in n + 1:
			var d := lerpf(from_d, to_d, float(i) / float(n))
			var c := _center_x(entry, d)
			var lane := c + ChunkDefs.washout_lane(def, d)
			outer.append(Vector2(c + side * _half_w(entry, d), -d))
			inner.append(Vector2(lane + side * lane_half, -d))
			torn.append(Vector2(lane + side * (lane_half + rng.randf_range(-16.0, 12.0)), -d))
		# The bed: both ends break off in ragged teeth instead of a saw cut.
		var bed_pts := PackedVector2Array()
		bed_pts.append_array(outer)
		var teeth := 5
		for k in range(1, teeth):
			var f := float(k) / float(teeth)
			bed_pts.append(outer[n].lerp(torn[n], f) + Vector2(0.0, (-46.0 if k % 2 == 1 else 18.0) * rng.randf_range(0.6, 1.0)))
		for i in range(n, -1, -1):
			bed_pts.append(torn[i])
		for k in range(teeth - 1, 0, -1):
			var f := float(k) / float(teeth)
			bed_pts.append(outer[0].lerp(torn[0], f) + Vector2(0.0, (46.0 if k % 2 == 1 else -18.0) * rng.randf_range(0.6, 1.0)))
		var bed := Polygon2D.new()
		bed.name = "WashoutBedL" if side < 0.0 else "WashoutBedR"
		bed.polygon = bed_pts
		SurfacePaint.dress(bed, &"dirt")   # the bed IS the arena's dirt, torn edge and all
		bed.z_index = -1
		root.add_child(bed)
		# Texture: darker damp patches, pale wheel ruts, and slabs of the old road.
		var dirt: Color = SurfacePaint.tone(&"dirt")
		for i in n:
			var a := outer[i].lerp(inner[i], rng.randf_range(0.15, 0.8))
			var span := outer[i].distance_to(inner[i])
			if span < 70.0:
				continue
			var patch := Polygon2D.new()
			patch.polygon = _chunk_of_road(a + Vector2(0.0, -rng.randf_range(10.0, 70.0)), rng.randf_range(26.0, 54.0), 0.55, 8, rng)
			patch.color = dirt.darkened(rng.randf_range(0.1, 0.22))
			patch.color.a = 0.7
			patch.z_index = -1
			root.add_child(patch)
			var rut := Polygon2D.new()
			var rx := outer[i].lerp(inner[i], rng.randf_range(0.2, 0.85)).x
			var ry := outer[i].y - rng.randf_range(0.0, 60.0)
			var rl := rng.randf_range(50.0, 120.0)
			rut.polygon = PackedVector2Array([
				Vector2(rx - 2.5, ry), Vector2(rx + 2.5, ry),
				Vector2(rx + 2.5 + rng.randf_range(-8.0, 8.0), ry - rl), Vector2(rx - 2.5 + rng.randf_range(-8.0, 8.0), ry - rl),
			])
			rut.color = dirt.lightened(0.14)
			rut.color.a = 0.8
			rut.z_index = -1
			root.add_child(rut)
			# Slabs: more of the old road survives near the ribbon than out by the verge.
			for k in 2:
				var near := rng.randf() < 0.65
				var at := outer[i].lerp(inner[i], rng.randf_range(0.72, 0.97) if near else rng.randf_range(0.08, 0.7))
				at.y -= rng.randf_range(0.0, 85.0)
				var slab := Polygon2D.new()
				slab.polygon = _chunk_of_road(at, rng.randf_range(9.0, 24.0) if near else rng.randf_range(6.0, 14.0), 0.5, 5, rng)
				slab.color = ASPHALT.lightened(rng.randf_range(0.08, 0.22))   # paler than the grain: road that survived
				slab.z_index = -1
				root.add_child(slab)
		var zone := _zone_strip("WashoutL" if side < 0.0 else "WashoutR", &"dirt", outer, inner)
		_bare(zone)   # the bed is the paint
		root.add_child(zone)

## Toll plaza: a painted apron, three booths spanning the road with a lane
## between each pair, a striped arm dropped across every lane (destructible:
## smash one), and a CASH ONLY sign overhead.
static func _tollbooth(root: Node2D, entry: Dictionary) -> void:
	var d := 640.0
	var c := _center_x(entry, d)
	var half: float = entry["def"]["half_w"]
	# The plaza is poured concrete out to the embankment's foot — pavement
	# (road handling) that outranks the dirt shoulder it covers, so the paint
	# and the feel agree.
	var plaza := _pavement("Plaza",
		PackedVector2Array([Vector2(c - half - SHOULDER_W, -(d - 160)), Vector2(c - half - SHOULDER_W, -(d + 160))]),
		PackedVector2Array([Vector2(c + half + SHOULDER_W, -(d - 160)), Vector2(c + half + SHOULDER_W, -(d + 160))]))
	root.add_child(plaza)
	# Four booths, three lanes: booths at the edges and at ±1/3.
	var booth_x: Array = [c - half + 10.0, c - half / 3.0, c + half / 3.0, c + half - 10.0]
	for i in booth_x.size():
		var booth := BlockScene.instantiate()
		booth.name = "Booth%d" % i
		booth.position = Vector2(booth_x[i], -d)
		booth.size = Vector2(44, 90)
		booth.max_hp = 60.0
		booth.deco = &"booth"
		root.add_child(booth)
	for i in booth_x.size() - 1:
		var arm := BlockScene.instantiate()
		arm.name = "Arm%d" % i
		arm.position = Vector2((float(booth_x[i]) + float(booth_x[i + 1])) * 0.5, -(d - 10.0))
		arm.size = Vector2(float(booth_x[i + 1]) - float(booth_x[i]) - 50.0, 14)
		arm.max_hp = 25.0
		arm.deco = &"barrier"
		root.add_child(arm)
	var sign := Node2D.new()
	sign.set_script(HighwayDecoScript)
	sign.kind = &"sign"
	sign.side = 1.0
	sign.copy_seed = 66601   # dealt copy; the plaza's own line comes from the table
	sign.position = Vector2(c + half + SHOULDER_W + 46.0, -(d - 300.0))
	root.add_child(sign)
	for lx in [c - half - 60.0, c + half + 60.0]:
		var pool := LightKit.make_light(240.0, 0.6, Color(1.0, 0.92, 0.75))
		pool.name = "PlazaLight"
		pool.position = Vector2(lx, -d)
		root.add_child(pool)

## Poured pavement: a road-handling TerrainZone in Ground Floor Gore's
## concrete, outranking whatever verge it lies over (paint = feel).
static func _pavement(zone_name: String, edge_a: PackedVector2Array, edge_b: PackedVector2Array) -> Area2D:
	var zone := _zone_strip(zone_name, &"road", edge_a, edge_b)
	zone.terrain_priority = 1
	zone.soften_visual = false   # poured slabs are formed straight
	var vis := zone.get_node(^"Vis") as Polygon2D
	vis.color = SurfacePaint.CONCRETE
	vis.material = SurfacePaint.concrete_material()
	return zone

## Jackknife: the trailer across two lanes, angled, with its tractor nosed
## into the verge — the open lane is the line.
static func _jackknife(root: Node2D, entry: Dictionary) -> void:
	var d := 640.0
	var c := _center_x(entry, d)
	var half: float = entry["def"]["half_w"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 313
	var side := 1.0 if rng.randf() < 0.5 else -1.0   # which two lanes it took
	var trailer := BlockScene.instantiate()
	trailer.name = "Trailer"
	trailer.position = Vector2(c + side * half * 0.3, -d)
	trailer.rotation = side * rng.randf_range(0.5, 0.75)
	trailer.size = Vector2(230, 72)
	trailer.max_hp = 90.0
	trailer.deco = &"trailer"
	root.add_child(trailer)
	var cab := DerelictScene.instantiate()
	cab.position = Vector2(c + side * (half - 30.0), -(d + 110.0))
	cab.rotation = -PI / 2.0 + side * 1.1
	root.add_child(cab)
	# Skids where the rig came round.
	for lane in [-14.0, 14.0]:
		var skid := Polygon2D.new()
		var a := Vector2(c + side * 40.0 + lane, -(d - 260.0))
		var b := Vector2(c + side * (half * 0.3) + lane, -(d + 20.0))
		skid.polygon = PackedVector2Array([a + Vector2(-4, 0), a + Vector2(4, 0), b + Vector2(4, 0), b + Vector2(-4, 0)])
		skid.color = Color(0.07, 0.07, 0.08, 0.7)
		skid.z_index = -1
		root.add_child(skid)
	var glass := Polygon2D.new()   # a glitter of windscreen on the asphalt
	glass.polygon = _chunk_of_road(Vector2(c + side * (half - 60.0), -(d + 60.0)), 26.0, 0.6, 9, rng)
	glass.color = Color(0.7, 0.8, 0.9, 0.35)
	glass.z_index = -1
	root.add_child(glass)

## The dressing along the mile: the SIGNAGE on course-wide cadences — green
## highway signs (sides alternate), white speed-limit signs, mile markers on
## the RIGHT verge every MILE_PX (95 at d 0, +1 a mile — the odometer), a
## billboard now and then — plus buzzards wheeling over the wreck-strewn
## chunks and the odd tumbleweed crossing an empty straight. All of it
## highway_deco.gd: paint and FX, nothing to hit.
static func _highway_dressing(root: Node2D, entry: Dictionary, ds: Array, cx: Array, half: Array) -> void:
	var def: Dictionary = entry["def"]
	var start: float = entry["start_d"]
	var chunk_len: float = def["len"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start) + 555
	var trail_side: float = float(def["cutoff"]["side"]) if def.has("cutoff") else 0.0
	var river: bool = def.has("river")
	# Signs: one for every multiple of SIGN_EVERY that falls in this chunk,
	# nudged off the seams (chunk lengths and the cadence share factors).
	var m := ceilf(start / SIGN_EVERY)
	if m * SIGN_EVERY < start:
		m += 1.0
	while m * SIGN_EVERY < start + chunk_len:
		var d := clampf(m * SIGN_EVERY - start, 120.0, chunk_len - 120.0)
		var side := -1.0 if int(m) % 2 == 0 else 1.0
		if not is_equal_approx(side, trail_side) and not (river and d > 500.0 and d < 1800.0):
			var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
			var sign := Node2D.new()
			sign.set_script(HighwayDecoScript)
			sign.kind = &"highway_sign"
			sign.side = side
			sign.copy_seed = int(m) * 31 + 7
			sign.position = Vector2(cx[i] + side * (half[i] + SHOULDER_W + 46.0), -d)
			root.add_child(sign)
		m += 1.0
	# Speed limits: the same dance on their own cadence (even multiples go
	# LEFT, so they never share a post with a mile marker), same skips.
	var speed_every: float = HighwayDecoScript.SPEED_SIGN_EVERY
	var k := ceilf(start / speed_every)
	if k * speed_every < start:
		k += 1.0
	while k * speed_every < start + chunk_len:
		var d := clampf(k * speed_every - start, 120.0, chunk_len - 120.0)
		var side := -1.0 if int(k) % 2 == 0 else 1.0
		if not is_equal_approx(side, trail_side) and not (river and d > 500.0 and d < 1800.0):
			var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
			var limit := Node2D.new()
			limit.set_script(HighwayDecoScript)
			limit.kind = &"speed_sign"
			limit.side = side
			limit.copy_seed = int(k) * 13 + 5
			limit.position = Vector2(cx[i] + side * (half[i] + SHOULDER_W + 38.0), -d)
			root.add_child(limit)
		k += 1.0
	# Mile markers: EXACT cadence, right verge only — d = n × MILE_PX, number
	# MILE_START + n (the number is dealt from the unnudged n, so a nudged
	# post still says the truth). Skipped where the right verge isn't a
	# verge: a right-hand cutoff's trail mouths, the river.
	var mile_px: float = HighwayDecoScript.MILE_PX
	var n := ceilf(start / mile_px)
	if n * mile_px < start:
		n += 1.0
	while n * mile_px < start + chunk_len:
		var raw := n * mile_px - start
		var d := clampf(raw, 120.0, chunk_len - 120.0)
		var blocked := river and d > 500.0 and d < 1800.0
		if trail_side > 0.0:
			for gap in def["cutoff"]["gaps"]:
				if d >= float(gap[0]) - 60.0 and d <= float(gap[1]) + 60.0:
					blocked = true
		if not blocked:
			var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
			var marker := Node2D.new()
			marker.set_script(HighwayDecoScript)
			marker.kind = &"mile_marker"
			marker.side = 1.0
			marker.mile_number = HighwayDecoScript.MILE_START + int(n)
			marker.position = Vector2(cx[i] + half[i] + SHOULDER_W + 26.0, -d)
			root.add_child(marker)
		n += 1.0
	# Billboards: rarer, out on the embankment where the board clears the road.
	var b := ceilf(start / BILLBOARD_EVERY)
	if b * BILLBOARD_EVERY < start:
		b += 1.0
	while b * BILLBOARD_EVERY < start + chunk_len:
		var d := clampf(b * BILLBOARD_EVERY - start, 200.0, chunk_len - 200.0)
		var side := 1.0 if int(b) % 2 == 0 else -1.0
		if not is_equal_approx(side, trail_side) and not river:
			var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
			var board := Node2D.new()
			board.set_script(HighwayDecoScript)
			board.kind = &"billboard"
			board.side = side
			board.copy_seed = int(b) * 17 + 3
			board.position = Vector2(cx[i] + side * (half[i] + SHOULDER_W + 40.0), -d)   # on the verge, board over the shoulder: it has to be READ
			root.add_child(board)
		b += 1.0
	# Buzzards over the wrecks; a tumbleweed on an empty straight.
	if def["kind"] in [&"convoy", &"log_run", &"jackknife"] or (def.get("props", []).size() >= 3 and rng.randf() < 0.4):
		var i := ds.size() / 2
		var flock := Node2D.new()
		flock.set_script(HighwayDecoScript)
		flock.kind = &"vultures"
		flock.position = Vector2(cx[i] + rng.randf_range(-120.0, 120.0), -chunk_len * 0.5)
		root.add_child(flock)
	elif def["kind"] == &"straight" and rng.randf() < 0.3:
		var d := rng.randf_range(300.0, chunk_len - 300.0)
		var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
		var weed := Node2D.new()
		weed.set_script(HighwayDecoScript)
		weed.kind = &"tumbleweed"
		weed.position = Vector2(cx[i], -d)
		root.add_child(weed)

## The cutoff: a clearing beside the road with a dirt-bike trail through it,
## a ditch between the trail and the embankment's foot, and a treeline
## fencing the far side — solid pines on a layer-2 body, so the trail is a
## corridor you stay in or scrape. The mouths are the embankment's gaps
## (_build_embankment); the trail's zone outranks the grass shoulder where
## they meet. Two phases: the ground (clearing, woods) goes down before the
## walls so the slope paints over it; the trail (_build_cutoff_trail) goes
## down after the shoulders so its bed paints over the verge at the mouths —
## sibling order is draw order, and the paint has to agree with the zones.
static func _build_cutoff(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("cutoff"):
		return
	var cf: Dictionary = def["cutoff"]
	var side: float = cf["side"]
	var entry_x: float = entry["entry_x"]
	var pts: Array = cf["trail"]
	var d_from: float = pts[0][0]
	var d_to: float = pts[pts.size() - 1][0]
	var trees_x: float = entry_x + float(cf["trees_x"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 1213
	# The clearing: real grass (a zone, the arena's dress) from the shoulder's
	# edge out past the treeline, over the whole cutoff, so the gaps open onto
	# ground that slows you like grass does everywhere else, not the void.
	var n := maxi(int(ceilf((d_to - d_from + 200.0) / 90.0)), 2)
	var near := PackedVector2Array()
	for i in n + 1:
		var d := lerpf(d_from - 100.0, d_to + 100.0, float(i) / float(n))
		near.append(Vector2(_center_x(entry, d) + side * (_half_w(entry, d) + SHOULDER_W - 4.0), -d))
	var far := PackedVector2Array()
	for p in near:
		far.append(Vector2(trees_x + side * 120.0, p.y))
	var clearing := _zone_strip("Clearing", &"grass", near, far)
	clearing.soften_visual = false   # its near edge already follows the road's bend
	root.add_child(clearing)
	# Past the treeline the ground darkens into the woods instead of ending
	# on a hard edge: two bands, each a little darker and a little ragged.
	var prev := far
	for band in 2:
		var next := PackedVector2Array()
		for p in prev:
			next.append(Vector2(p.x + side * (110.0 + rng.randf_range(-20.0, 20.0)), p.y))
		var woods := Polygon2D.new()
		woods.name = "Woods%d" % band
		woods.polygon = _strip(prev, next)
		woods.color = SLOPE_FILL[&"grass"].darkened(0.25 + 0.3 * float(band))
		woods.z_index = -1
		root.add_child(woods)
		prev = next
	# A second, sparser row of scrub and pines beyond the fence: paint only.
	var dd := d_from - 40.0
	while dd < d_to + 40.0:
		var at := Vector2(trees_x + side * rng.randf_range(70.0, 150.0), -dd)
		var r := rng.randf_range(16.0, 34.0)
		var crown := Polygon2D.new()
		crown.polygon = _blob(at, r, rng)
		crown.color = Color(0.1, 0.2, 0.1).darkened(rng.randf_range(0.0, 0.3))
		root.add_child(crown)
		dd += rng.randf_range(90.0, 170.0)

## The cutoff's second phase — see _build_cutoff.
static func _build_cutoff_trail(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("cutoff"):
		return
	var cf: Dictionary = def["cutoff"]
	var side: float = cf["side"]
	var width: float = cf["width"]
	var entry_x: float = entry["entry_x"]
	var pts: Array = cf["trail"]
	var d_from: float = pts[0][0]
	var d_to: float = pts[pts.size() - 1][0]
	var gaps: Array = cf["gaps"]
	var trees_x: float = entry_x + float(cf["trees_x"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 1214
	# The ditch: a mud rut between the embankment's foot and the trail,
	# along the straight where the two run side by side. Mud: stray and
	# stick. It outranks the clearing's grass under it.
	var ditch_a := PackedVector2Array()
	var ditch_b := PackedVector2Array()
	var d0: float = gaps[0][1]
	var d1: float = gaps[1][0]
	var m := maxi(int(ceilf((d1 - d0) / 90.0)), 2)
	for i in m + 1:
		var d := lerpf(d0, d1, float(i) / float(m))
		var foot: float = _center_x(entry, d) + side * (_half_w(entry, d) + SHOULDER_W + EMBANK_W)
		var trail_edge: float = entry_x + ChunkDefs.cutoff_x(def, d) - side * width * 0.5
		ditch_a.append(Vector2(foot, -d))
		ditch_b.append(Vector2(trail_edge - side * 10.0, -d))
	var ditch := _zone_strip("Ditch", &"mud", ditch_a, ditch_b)
	ditch.terrain_priority = 1
	root.add_child(ditch)
	# The trail: a torn-edged dirt bed and its zone, which outranks the
	# grass shoulder at the mouths.
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var torn_in := PackedVector2Array()
	var torn_out := PackedVector2Array()
	var k := maxi(int(ceilf((d_to - d_from) / 60.0)), 2)
	for i in k + 1:
		var d := lerpf(d_from, d_to, float(i) / float(k))
		var tx: float = entry_x + ChunkDefs.cutoff_x(def, d)
		inner.append(Vector2(tx - side * width * 0.5, -d))
		outer.append(Vector2(tx + side * width * 0.5, -d))
		torn_in.append(Vector2(tx - side * (width * 0.5 + rng.randf_range(-6.0, 14.0)), -d))
		torn_out.append(Vector2(tx + side * (width * 0.5 + rng.randf_range(-6.0, 14.0)), -d))
	var bed := Polygon2D.new()
	bed.name = "TrailBed"
	bed.polygon = _strip(torn_in, torn_out)
	SurfacePaint.dress(bed, &"dirt")   # the arena's dirt, torn edge and all
	bed.z_index = -1
	root.add_child(bed)
	var dirt: Color = SurfacePaint.tone(&"dirt")
	for i in range(0, k, 2):   # twin ruts the bikes wore in
		for lane in [-0.28, 0.28]:
			var rut := Polygon2D.new()
			var a: Vector2 = inner[i].lerp(outer[i], 0.5 + lane)
			var b: Vector2 = inner[i + 1].lerp(outer[i + 1], 0.5 + lane) if i + 1 <= k else a
			rut.polygon = PackedVector2Array([a + Vector2(-3, 0), a + Vector2(3, 0), b + Vector2(3, 0), b + Vector2(-3, 0)])
			rut.color = dirt.darkened(0.22)
			rut.color.a = 0.8
			rut.z_index = -1
			root.add_child(rut)
	var trail := _zone_strip("Trail", &"dirt", inner, outer)
	_bare(trail)   # the bed is the paint
	trail.terrain_priority = 1
	root.add_child(trail)
	# The treeline: solid pines along the far side of the trail, close enough
	# together that nothing drives between them.
	var trees := StaticBody2D.new()
	trees.name = "Treeline"
	trees.collision_layer = 2
	trees.collision_mask = 0
	var d := d_from - 60.0
	while d < d_to + 60.0:
		var at := Vector2(trees_x + rng.randf_range(-25.0, 25.0), -d)
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 26.0
		col.shape = shape
		col.position = at
		trees.add_child(col)
		var crown_r := rng.randf_range(30.0, 42.0)
		var shade := Polygon2D.new()
		shade.polygon = _blob(at + Vector2(side * 8.0, 10.0), crown_r * 1.05, rng)
		shade.color = Color(0.05, 0.08, 0.04, 0.55)
		trees.add_child(shade)
		var crown := Polygon2D.new()
		crown.polygon = _blob(at, crown_r, rng)
		crown.color = Color(0.12, 0.26, 0.12).darkened(rng.randf_range(0.0, 0.2))
		trees.add_child(crown)
		var crown2 := Polygon2D.new()
		crown2.polygon = _blob(at + Vector2(-side * 6.0, -8.0), crown_r * 0.6, rng)
		crown2.color = Color(0.18, 0.34, 0.16).darkened(rng.randf_range(0.0, 0.15))
		trees.add_child(crown2)
		d += rng.randf_range(78.0, 92.0)
	root.add_child(trees)

## An irregular, squashed n-gon: a damp patch, or a slab of the old road.
static func _chunk_of_road(center: Vector2, r: float, squash: float, n: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.2, 0.2)
		out.append(center + Vector2(cos(a), sin(a) * squash).rotated(rng.randf_range(-0.1, 0.1)) * r * rng.randf_range(0.65, 1.1))
	return out

## Local road direction at d (north = -y), for aligning rail segments.
static func _road_angle(entry: Dictionary, d: float) -> float:
	var behind := _center_x(entry, maxf(d - 40.0, 0.0))
	var ahead := _center_x(entry, d + 40.0)
	return Vector2(ahead - behind, -80.0).angle()

## The impassable rim: an opaque painted slope with a layer-2 wall under its
## inner edge — "floor 2 but no way up", so nothing feels invisible. A
## cutoff's trail side is built in runs, leaving its mouths open.
static func _build_embankment(root: Node2D, entry: Dictionary, side: float, shoulder: StringName) -> void:
	var def: Dictionary = entry["def"]
	var chunk_len: float = def["len"]
	var runs: Array = [[0.0, chunk_len]]
	if def.has("cutoff") and is_equal_approx(float(def["cutoff"]["side"]), side):
		runs = []
		var d := 0.0
		for g in def["cutoff"]["gaps"]:
			runs.append([d, float(g[0])])
			d = float(g[1])
		runs.append([d, chunk_len])
	for k in runs.size():
		var suffix := "" if runs.size() == 1 else str(k)
		# A run that begins at a mouth starts with a CHAMFERED end: its outer
		# corner leads and its inner corner trails by FUNNEL_LEN, so a car
		# that missed the mouth is deflected back onto the road by a slanted
		# face instead of stopped dead by a square one.
		_embank_run(root, entry, side, shoulder, float(runs[k][0]), float(runs[k][1]),
			("EmbankL" if side < 0.0 else "EmbankR") + suffix, k > 0)

static func _embank_run(root: Node2D, entry: Dictionary, side: float, shoulder: StringName,
		d0: float, d1: float, wall_name: String, chamfer := false) -> void:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var crest := PackedVector2Array()
	var n := maxi(int(ceilf((d1 - d0) / STEP)), 1)
	var ds_run: Array = []
	for i in n + 1:
		ds_run.append(lerpf(d0, d1, float(i) / float(n)))
	if chamfer and d0 + FUNNEL_LEN < d1:
		ds_run.append(d0 + FUNNEL_LEN)
		ds_run.sort()
	for d in ds_run:
		var y: float = -d
		var e: float = _center_x(entry, d) + side * (_half_w(entry, d) + SHOULDER_W)
		var out_e: float = e + side * EMBANK_W
		outer.append(Vector2(out_e, y))
		if chamfer and d < d0 + FUNNEL_LEN - 0.5:
			continue   # the inner edge starts FUNNEL_LEN in: the diagonal is the face
		inner.append(Vector2(e, y))
		crest.append(Vector2(e + (out_e - e) * 0.62, y))
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 2
	wall.collision_mask = 0
	var col := CollisionPolygon2D.new()
	col.polygon = _strip(inner, outer)
	wall.add_child(col)
	var fill_color: Color = SLOPE_FILL.get(shoulder, SLOPE_FILL[&"grass"])
	var slope := Polygon2D.new()
	slope.name = "Slope"
	slope.color = fill_color
	slope.polygon = _strip(inner, outer)
	slope.z_index = -1
	wall.add_child(slope)
	var ridge := Polygon2D.new()
	ridge.name = "Ridge"
	ridge.color = fill_color.darkened(0.4)
	ridge.polygon = _strip(crest, outer)
	ridge.z_index = -1
	wall.add_child(ridge)
	root.add_child(wall)

static func _place_props(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("props"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 101
	for prop in def["props"]:
		var d: float = prop["at"][0]
		var side: float = prop["at"][1]
		var pos := Vector2(_center_x(entry, d) + side, -d)
		var kind: StringName = prop["kind"]
		match kind:
			&"derelict":
				var wreck := DerelictScene.instantiate()
				wreck.position = pos
				# Highway wrecks face along the road, roughly.
				wreck.rotation = -PI / 2.0 + (PI if rng.randf() < 0.35 else 0.0) \
					+ rng.randf_range(-0.4, 0.4)
				root.add_child(wreck)
				if rng.randf() < 0.33:   # one wreck in three still burns
					var fire := Node2D.new()
					fire.set_script(HighwayDecoScript)
					fire.kind = &"wreck_fire"
					fire.position = pos + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-14.0, 4.0))
					root.add_child(fire)
					var glow := LightKit.make_light(110.0, 0.5, Color(1.0, 0.55, 0.2))
					glow.name = "FireGlow"
					glow.position = fire.position
					root.add_child(glow)
			&"barrel":
				var barrel := BlockScene.instantiate()
				barrel.position = pos
				barrel.size = Vector2(44, 44)
				barrel.max_hp = 30.0
				barrel.deco = &"barrel"
				root.add_child(barrel)
			&"barrier":
				var barrier := BlockScene.instantiate()
				barrier.position = pos
				barrier.size = Vector2(120, 32)
				barrier.max_hp = 25.0
				barrier.deco = &"barrier"
				root.add_child(barrier)
			&"cone":
				var cone := ClutterScene.instantiate()
				cone.position = pos
				cone.kind = &"cone"
				cone.footprint = 22.0
				root.add_child(cone)
			&"log":
				var log_block := BlockScene.instantiate()
				log_block.position = pos
				log_block.rotation = rng.randf_range(-0.35, 0.35)  # never square to the road
				log_block.size = Vector2(140, 26)
				log_block.max_hp = 15.0
				log_block.deco = &"log"
				root.add_child(log_block)
			&"junk":
				var junk := BlockScene.instantiate()
				junk.position = pos
				junk.size = Vector2(70, 50)
				junk.max_hp = 20.0
				junk.deco = &"junk"
				root.add_child(junk)
			&"pump":
				var pump := BlockScene.instantiate()
				pump.position = pos
				pump.size = Vector2(64, 64)
				pump.max_hp = 40.0
				pump.deco = &"pump"
				root.add_child(pump)
			&"slick":
				_slick(root, pos, rng)
			&"pothole":
				_pothole(root, pos, rng)
			&"jump":
				# The arena launch pad, highway edition: airborne clears the
				# logs and oil slicks — and the wall doesn't care where you land.
				var pad := Area2D.new()
				pad.set_script(JumpPadScript)
				pad.name = "JumpPad"
				pad.collision_layer = 0
				pad.collision_mask = 1
				pad.position = pos
				var pad_col := CollisionShape2D.new()
				pad_col.name = "Col"
				var pad_shape := RectangleShape2D.new()
				pad_shape.size = Vector2(224, 224)
				pad_col.shape = pad_shape
				pad.add_child(pad_col)
				root.add_child(pad)

static func _place_pickups(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	if not def.has("pickups"):
		return
	for pick in def["pickups"]:
		var d: float = pick["at"][0]
		var side: float = pick["at"][1]
		var pos := Vector2(_center_x(entry, d) + side, -d)
		var kind: StringName = pick["kind"]
		if kind == &"heal":
			var heal := HealScene.instantiate()
			heal.position = pos
			root.add_child(heal)
		elif kind == &"boost":
			var boost := BoostScene.instantiate()
			boost.position = pos
			root.add_child(boost)
		else:
			var ammo := AmmoScene.instantiate()
			ammo.position = pos
			ammo.kind = String(kind)
			root.add_child(ammo)

## Roadside flair: seeded paint on the embankments whipping by for the speed
## read — bushes, marker posts, rocks. Pure Polygon2D beyond the walls; no
## collision, no feelers, no radar. Every chunk gets a stream.
static func _roadside_flair(root: Node2D, entry: Dictionary, ds: Array, cx: Array, half: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 707
	var def: Dictionary = entry["def"]
	var chunk_len: float = def["len"]
	var d := rng.randf_range(80.0, 240.0)
	var side := 1.0
	var river: Dictionary = def.get("river", {})
	var trail_side: float = float(def["cutoff"]["side"]) if def.has("cutoff") else 0.0
	while d < chunk_len - 60.0:
		if not river.is_empty() and d > float(river["bank"]) - 60.0 and d < float(river["shallow_to"]):
			d = float(river["shallow_to"]) + 40.0   # no bushes growing out of the river
			continue
		if is_equal_approx(side, trail_side):
			side = -side   # the trail side is the trail's to dress
			continue
		var i := clampi(int(d / chunk_len * float(ds.size() - 1)), 0, ds.size() - 1)
		var base_x: float = cx[i] + side * (half[i] + SHOULDER_W + 60.0 + rng.randf_range(0.0, 50.0))
		var pos := Vector2(base_x, -d)
		match rng.randi() % 3:
			0:  # scrub bush — two offset blobs
				var bush := Polygon2D.new()
				bush.polygon = _blob(pos, rng.randf_range(9.0, 16.0), rng)
				bush.color = Color(0.24, 0.34, 0.18)
				root.add_child(bush)
				var bush2 := Polygon2D.new()
				bush2.polygon = _blob(pos + Vector2(10, 6), rng.randf_range(6.0, 10.0), rng)
				bush2.color = Color(0.3, 0.4, 0.22)
				root.add_child(bush2)
			1:  # mile-marker post
				var post := Polygon2D.new()
				post.polygon = PackedVector2Array([
					pos + Vector2(-3, -14), pos + Vector2(3, -14),
					pos + Vector2(3, 14), pos + Vector2(-3, 14),
				])
				post.color = Color(0.2, 0.42, 0.28)
				root.add_child(post)
				var cap := Polygon2D.new()
				cap.polygon = PackedVector2Array([
					pos + Vector2(-4, -18), pos + Vector2(4, -18),
					pos + Vector2(4, -12), pos + Vector2(-4, -12),
				])
				cap.color = Color(0.85, 0.87, 0.9)
				root.add_child(cap)
			2:  # roadside rock
				var rock := Polygon2D.new()
				rock.polygon = _blob(pos, rng.randf_range(8.0, 14.0), rng)
				rock.color = Color(0.38, 0.37, 0.36)
				root.add_child(rock)
		side = -side
		d += rng.randf_range(200.0, 340.0)

static func _blob(center: Vector2, r: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * float(i) / 7.0
		pts.append(center + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.75, 1.15))
	return pts

## Overpass: a concrete deck crossing OVER the road (z 1 paint — cars pass
## under; the terrace z-order trick, no FloorZones, pure dressing) with a
## shadow band beneath and two smashable pillars forcing a line through.
static func _overpass(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	var mid: float = def["len"] * 0.5
	var c := _center_x(entry, mid)
	var span: float = def["half_w"] + SHOULDER_W + EMBANK_W + 160.0
	var shadow := Polygon2D.new()
	shadow.name = "OverShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(c - span, -mid + 150), Vector2(c + span, -mid + 150),
		Vector2(c + span, -mid - 150), Vector2(c - span, -mid - 150),
	])
	shadow.color = Color(0.0, 0.0, 0.0, 0.3)
	shadow.z_index = -1
	root.add_child(shadow)
	var deck := Polygon2D.new()
	deck.name = "OverDeck"
	deck.polygon = PackedVector2Array([
		Vector2(c - span, -mid + 110), Vector2(c + span, -mid + 110),
		Vector2(c + span, -mid - 110), Vector2(c - span, -mid - 110),
	])
	deck.color = Color(0.32, 0.32, 0.35)
	deck.z_index = 1
	root.add_child(deck)
	for edge in [-96.0, 96.0]:
		var rail := Polygon2D.new()
		rail.polygon = PackedVector2Array([
			Vector2(c - span, -mid + edge + 8), Vector2(c + span, -mid + edge + 8),
			Vector2(c + span, -mid + edge - 8), Vector2(c - span, -mid + edge - 8),
		])
		rail.color = Color(0.22, 0.22, 0.25)
		rail.z_index = 1
		root.add_child(rail)
	# The pillars are destructibles like everything else on this road: a car
	# smashes through one (smash_and_pass) instead of stopping dead under the
	# deck. Heaviest thing on the course — the momentum bite is real.
	for side in [-1.0, 1.0]:
		var pillar := BlockScene.instantiate()
		pillar.name = "PillarL" if side < 0.0 else "PillarR"
		pillar.position = Vector2(c + side * 300.0, -mid)
		pillar.size = Vector2(56, 56)
		pillar.max_hp = 60.0
		pillar.deco = &"pillar"
		root.add_child(pillar)

## Truckstop dressing: dirt apron paint, a flickering neon sign and light
## pools off the shoulder (street_deco — non-colliding by design).
static func _truckstop(root: Node2D, entry: Dictionary) -> void:
	var c := _center_x(entry, 620.0)
	# The forecourt: poured concrete from the road's edge lane to the
	# embankment's foot (it used to paint past the foot, over the slope), a
	# road-handling zone over the dirt shoulder it covers.
	var half: float = entry["def"]["half_w"]
	var apron := _pavement("Apron",
		PackedVector2Array([Vector2(c + 250, -380), Vector2(c + 250, -880)]),
		PackedVector2Array([Vector2(c + half + SHOULDER_W, -380), Vector2(c + half + SHOULDER_W, -880)]))
	root.add_child(apron)
	var neon := Node2D.new()
	neon.set_script(StreetDecoScript)
	neon.kind = &"neon"
	neon.position = Vector2(c + 430, -840)
	root.add_child(neon)
	# The lot: a diner board on the apron, a dumpster round the back, and two
	# rigs that parked here a long time ago.
	var diner := Node2D.new()
	diner.set_script(HighwayDecoScript)
	diner.kind = &"billboard"
	diner.side = 1.0
	diner.copy_seed = HighwayDecoScript.DINER_SEED
	diner.position = Vector2(c + 560.0, -980.0)
	root.add_child(diner)
	var bin := BlockScene.instantiate()
	bin.name = "Dumpster"
	bin.position = Vector2(c + 500.0, -420.0)
	bin.size = Vector2(70, 40)
	bin.max_hp = 40.0
	bin.deco = &"crate"
	root.add_child(bin)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 808
	for k in 2:
		var parked := DerelictScene.instantiate()
		parked.position = Vector2(c + 340.0 + float(k) * 90.0, -(560.0 + float(k) * 250.0))
		parked.rotation = -PI / 2.0 + rng.randf_range(-0.2, 0.2)
		root.add_child(parked)
	# Real light under the paint: once the sky goes, the stop is the one lit
	# thing on the road (the Coliseum's tower idiom).
	var glow := LightKit.make_light(150.0, 0.55, Color(1.0, 0.45, 0.7))
	glow.name = "NeonGlow"
	glow.position = neon.position
	root.add_child(glow)
	for d in [460.0, 800.0]:
		var lamp := Node2D.new()
		lamp.set_script(StreetDecoScript)
		lamp.kind = &"street_light"
		lamp.position = Vector2(c + 440, -d)
		root.add_child(lamp)
		var pool := LightKit.make_light(210.0, 0.7, Color(1.0, 0.92, 0.7))
		pool.name = "LampPool"
		pool.position = lamp.position + Vector2(-40.0, 0.0)
		root.add_child(pool)

## The two road hazards read as a pair: an OIL SLICK is TRUE BLACK with a
## smooth, curvy spill edge and one bright light reflection (a sky glint —
## the wet read); a POTHOLE is JAGGED dark grey, a hair lighter than the
## oil, with a cracked pale rim and loose rubble (the broken read). Both are
## pure paint over a small sensor, never HP, and airtime clears both — but
## they FEEL different: oil is an oil_slick.gd Area2D over an ice zone (the
## nose kicks off the line and the tires ride ice for a second — the car
## keeps going where it was going), a pothole is a dirt TerrainZone (a bump
## that bleeds speed). Each zone's Vis wears the arena's surface under the
## paint: the pothole sits in a disc of the arena's dirt (its rubble apron),
## and the slick keeps its black pool — the arena's ice tint would grey it
## out — showing only as a thin icy RIM around the spill (SLICK_RIM), where
## the sheen reads without the black losing. The zones go down first so
## their dress paints under the hazard.
const OIL := Color(0.01, 0.01, 0.015)
const POTHOLE := Color(0.095, 0.095, 0.1)
const SLICK_RIM := 1.16   # the ice rim's outline, as a scale of the pool's

static func _slick(root: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var r := 44.0
	# A curvy edge: a smooth outline whose radius breathes on two slow waves
	# (no per-vertex jitter — that's the pothole's look).
	var w1 := rng.randf_range(0.10, 0.18)
	var w2 := rng.randf_range(0.05, 0.10)
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var pool := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * float(i) / float(n)
		var rad := r * (1.0 + w1 * sin(2.0 * a + ph1) + w2 * sin(3.0 * a + ph2))
		pool.append(pos + Vector2(cos(a) * 1.3, sin(a) * 0.8) * rad)
	var rim := PackedVector2Array()
	for p in pool:
		rim.append(pos + (p - pos) * SLICK_RIM)
	_hazard_zone(root, "SlickRim", pos, r, &"ice", rim, true)
	var pool_poly := Polygon2D.new()
	pool_poly.polygon = pool
	pool_poly.color = OIL
	pool_poly.z_index = -1
	root.add_child(pool_poly)
	# The light reflection: one soft pale glint off the wet surface, sitting
	# high on the spill where the sky would mirror, with a faint halo under it.
	var gx := pos.x + rng.randf_range(-r * 0.35, r * 0.15)
	var gy := pos.y - r * rng.randf_range(0.15, 0.35)
	var glen := rng.randf_range(22.0, 34.0)
	var halo := Polygon2D.new()
	halo.polygon = _ellipse(Vector2(gx + glen * 0.5, gy), glen * 0.75, 6.0, 12)
	halo.color = Color(0.5, 0.58, 0.7, 0.22)
	halo.z_index = -1
	root.add_child(halo)
	var glint := Polygon2D.new()
	glint.polygon = _ellipse(Vector2(gx + glen * 0.5, gy), glen * 0.5, 2.6, 12)
	glint.color = Color(0.86, 0.9, 0.96, 0.85)
	glint.z_index = -1
	root.add_child(glint)
	# A drip tail running south with the crown of the road.
	var drip := Polygon2D.new()
	var dx := pos.x + rng.randf_range(-r * 0.4, r * 0.4)
	drip.polygon = PackedVector2Array([
		Vector2(dx - 3.0, pos.y + r * 0.7), Vector2(dx + 3.0, pos.y + r * 0.7),
		Vector2(dx + 1.5, pos.y + r * 0.7 + rng.randf_range(16.0, 30.0)),
		Vector2(dx - 1.5, pos.y + r * 0.7 + rng.randf_range(16.0, 30.0)),
	])
	drip.color = OIL
	drip.z_index = -1
	root.add_child(drip)
	# Not a bare ice zone: the sensor under the spill kicks the nose and puts
	# the tires on ice for a second (oil_slick.gd owns the feel).
	var OilSlick := preload("res://levels/chase/oil_slick.gd")
	root.add_child(OilSlick.make(pos, r))

static func _pothole(root: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var r := 38.0
	# A jagged edge: few vertices, hard per-vertex radius jitter — broken
	# asphalt, not a spill.
	var hole := PackedVector2Array()
	var n := 9
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		var rad := r * rng.randf_range(0.62, 1.1)
		hole.append(pos + Vector2(cos(a) * 1.15, sin(a) * 0.85) * rad)
	# The cracked rim: a pale lip of crumbled asphalt around the hole.
	var lip := PackedVector2Array()
	for p in hole:
		lip.append(pos + (p - pos) * 1.16)
	_hazard_zone(root, "Pothole", pos, r, &"dirt", _chunk_of_road(pos, r * 1.5, 0.8, 10, rng))
	var lip_poly := Polygon2D.new()
	lip_poly.polygon = lip
	lip_poly.color = Color(0.36, 0.35, 0.33)
	lip_poly.z_index = -1
	root.add_child(lip_poly)
	var hole_poly := Polygon2D.new()
	hole_poly.polygon = hole
	hole_poly.color = POTHOLE
	hole_poly.z_index = -1
	root.add_child(hole_poly)
	# Depth: the near wall's shadow pooled toward the north-west of the pit.
	var deep := PackedVector2Array()
	for p in hole:
		deep.append(pos + (p - pos) * 0.62 + Vector2(-4.0, -4.0))
	var deep_poly := Polygon2D.new()
	deep_poly.polygon = deep
	deep_poly.color = Color(0.06, 0.06, 0.065)
	deep_poly.z_index = -1
	root.add_child(deep_poly)
	# Loose rubble: a few chips scattered downstream of the hole.
	for k in 4:
		var chip := Polygon2D.new()
		var c := pos + Vector2(rng.randf_range(-r * 0.9, r * 0.9), rng.randf_range(r * 0.5, r * 1.3))
		var cs := rng.randf_range(2.5, 5.0)
		chip.polygon = PackedVector2Array([
			c + Vector2(-cs, -cs * 0.6), c + Vector2(cs * 0.8, -cs), c + Vector2(cs, cs * 0.7), c + Vector2(-cs * 0.6, cs),
		])
		chip.color = Color(0.4, 0.39, 0.36)
		chip.z_index = -1
		root.add_child(chip)
	# Cracks radiating from the lip.
	for k in 3:
		var a := rng.randf() * TAU
		var crack := Polygon2D.new()
		var from := pos + Vector2(cos(a) * 1.15, sin(a) * 0.85) * r * 1.1
		var to := from + Vector2(cos(a + rng.randf_range(-0.5, 0.5)), sin(a + rng.randf_range(-0.5, 0.5))) * rng.randf_range(12.0, 24.0)
		var side := (to - from).orthogonal().normalized() * 1.2
		crack.polygon = PackedVector2Array([from + side, to + side * 0.4, to - side * 0.4, from - side])
		crack.color = Color(0.11, 0.11, 0.12)
		crack.z_index = -1
		root.add_child(crack)

static func _ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out

## A hazard's circle zone with a Vis in the arena's dress for its surface
## (`vis_poly` in chunk space; the zone sits at pos, so it is re-based).
## `dress_only` lays the arena surface paint without a live terrain zone —
## the slick's feel comes from its own sensor (oil_slick.gd), the icy rim is
## just how it looks.
static func _hazard_zone(root: Node2D, label: String, pos: Vector2, r: float, terrain: StringName, vis_poly: PackedVector2Array, dress_only := false) -> void:
	var zone := Area2D.new()
	zone.set_script(TerrainZoneScript)
	zone.name = "%s%d" % [label, root.get_child_count()]   # unique per chunk (a bare duplicate is renamed @Area2D@N)
	zone.collision_layer = 0 if dress_only else 128
	zone.collision_mask = 0
	zone.terrain_type = terrain
	zone.position = pos
	zone.z_index = -1
	zone.soften_visual = false   # the hazard's own outline is the shape
	var vis := Polygon2D.new()
	vis.name = "Vis"
	var local := PackedVector2Array()
	for p in vis_poly:
		local.append(p - pos)
	vis.polygon = local
	SurfacePaint.dress(vis, terrain)
	zone.add_child(vis)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	col.shape = shape
	zone.add_child(col)
	root.add_child(zone)

## The bridge is out (the finale's mile): a river across the whole corridor
## with a bridge deck that runs out from the near bank and breaks off at the
## brink. Child order is draw order at z -1 — the river first (the zone's own
## paint), the shallows, then the deck over them, then the launch lip. The
## deep channel is a real deep_water_zone: a grounded car that lands in it
## sinks; airborne ones sail over. The lip launches Buzzards only — the
## player pops at the brink under the finale driver, so the arc is exact.
static func _bridge_out(root: Node2D, entry: Dictionary) -> void:
	var def: Dictionary = entry["def"]
	var r: Dictionary = def["river"]
	var bank: float = r["bank"]
	var brink: float = r["brink"]
	var deep_to: float = r["deep_to"]
	var shallow_to: float = r["shallow_to"]
	var c := _center_x(entry, bank)
	var half: float = def["half_w"]
	var span := half + SHOULDER_W + EMBANK_W + 200.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry["start_d"]) + 919
	# The deep channel: size BEFORE add_child (its _ready builds the kill rect).
	var river = DeepWaterScene.instantiate()
	river.name = "River"
	river.size = Vector2(span * 2.0, deep_to - brink)
	river.position = Vector2(c, -(brink + deep_to) * 0.5)
	river.z_index = -1
	root.add_child(river)
	# Shallows: the far shore, and the pools either side of the deck. Real
	# water terrain (a crawl if you land short but dry), never lethal.
	var far_a := PackedVector2Array([Vector2(c - span, -deep_to), Vector2(c - span, -shallow_to)])
	var far_b := PackedVector2Array([Vector2(c + span, -deep_to), Vector2(c + span, -shallow_to)])
	var shore := _zone_strip("ShallowsFar", &"water", far_a, far_b)
	shore.soften_visual = false
	root.add_child(shore)
	for side in [-1.0, 1.0]:
		var edge: float = c + side * half
		var pool_a := PackedVector2Array([Vector2(edge, -(bank - 40.0)), Vector2(edge, -brink)])
		var pool_b := PackedVector2Array([Vector2(c + side * span, -(bank - 40.0)), Vector2(c + side * span, -brink)])
		var pool := _zone_strip("PoolL" if side < 0.0 else "PoolR", &"water", pool_a, pool_b)
		pool.soften_visual = false
		root.add_child(pool)
	# The deck: bank to brink, breaking off in jagged teeth, rebar sticking out.
	var deck_pts := PackedVector2Array()
	deck_pts.append(Vector2(c - half, -bank))
	deck_pts.append(Vector2(c + half, -bank))
	var teeth := 9
	for k in range(teeth, -1, -1):
		var x := c - half + half * 2.0 * float(k) / float(teeth)
		deck_pts.append(Vector2(x, -(brink + (rng.randf_range(-34.0, 6.0) if k % 2 == 1 else rng.randf_range(-6.0, 22.0)))))
	var deck := Polygon2D.new()
	deck.name = "Deck"
	deck.polygon = deck_pts
	deck.color = DECK
	deck.z_index = -1
	root.add_child(deck)
	for side in [-1.0, 1.0]:
		var rx: float = c + side * (half - 14.0)
		var rail := Polygon2D.new()
		rail.polygon = PackedVector2Array([
			Vector2(rx - 6.0, -bank), Vector2(rx + 6.0, -bank),
			Vector2(rx + 6.0, -(brink - 30.0)), Vector2(rx - 6.0, -(brink - 30.0)),
		])
		rail.color = DECK_RAIL
		rail.z_index = -1
		root.add_child(rail)
	_add_marks(root, "DeckLine", PackedVector2Array([Vector2(c, -bank), Vector2(c, -(brink - 40.0))]), &"dashed_yellow")
	for k in 7:
		var bar := Polygon2D.new()
		var bx := c - half + rng.randf_range(30.0, half * 2.0 - 30.0)
		var by := -(brink + rng.randf_range(-20.0, 10.0))
		var reach := rng.randf_range(18.0, 44.0)
		var lean := rng.randf_range(-10.0, 10.0)
		bar.polygon = PackedVector2Array([
			Vector2(bx - 2.0, by), Vector2(bx + 2.0, by), Vector2(bx + 2.0 + lean, by - reach), Vector2(bx - 2.0 + lean, by - reach),
		])
		bar.color = REBAR
		bar.z_index = -1
		root.add_child(bar)
	# Slabs of the old deck, drowned mid-channel.
	for k in 5:
		var slab := Polygon2D.new()
		slab.polygon = _chunk_of_road(Vector2(c + rng.randf_range(-half, half), -rng.randf_range(brink + 60.0, deep_to - 60.0)),
			rng.randf_range(16.0, 40.0), 0.5, 6, rng)
		slab.color = DECK.darkened(0.25)
		slab.z_index = -1
		root.add_child(slab)
	# The far stub: the other half of the bridge, breaking off toward us.
	var stub_pts := PackedVector2Array()
	for k in teeth + 1:
		var x := c - half + half * 2.0 * float(k) / float(teeth)
		stub_pts.append(Vector2(x, -(shallow_to - (rng.randf_range(0.0, 30.0) if k % 2 == 1 else rng.randf_range(20.0, 46.0)))))
	stub_pts.append(Vector2(c + half, -(shallow_to + 140.0)))
	stub_pts.append(Vector2(c - half, -(shallow_to + 140.0)))
	var stub := Polygon2D.new()
	stub.name = "FarDeck"
	stub.polygon = stub_pts
	stub.color = DECK
	stub.z_index = -1
	root.add_child(stub)
	# The launch lip: a jump pad the BIRDS take off from (the player is popped
	# at the brink by the finale driver — the pad must not launch it early).
	var pad := Area2D.new()
	pad.set_script(JumpPadScript)
	pad.name = "BrinkPad"
	pad.position = Vector2(c, -float(r["pad_d"]))
	pad.collision_layer = 0
	pad.collision_mask = 1
	pad.launch_player = false
	pad.visible = false   # the deck's own paint is the ramp read
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(224, 224)
	col.shape = shape
	pad.add_child(col)
	root.add_child(pad)

static func _strip(forward: PackedVector2Array, back: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(forward)
	for i in range(back.size() - 1, -1, -1):
		out.append(back[i])
	return out
