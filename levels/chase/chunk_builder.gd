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
const JumpPadScript := preload("res://environment/jump_pad.gd")

const STEP := 175.0        # geometry sample spacing along the chunk
const SHOULDER_W := 90.0   # drivable verge outside the asphalt (grip penalty)
const EMBANK_W := 130.0    # painted slope width; the wall runs its inner edge
const TAPER := 300.0       # must match chase_course.TAPER

const ASPHALT := Color(0.17, 0.17, 0.19)
const SHOULDER_VIS := {
	&"grass": Color(0.25, 0.5, 0.22, 0.5),
	&"dirt": Color(0.5, 0.36, 0.2, 0.5),
}
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
	var shoulder: StringName = def.get("shoulder", &"grass")
	for side in [-1.0, 1.0]:
		_build_shoulder(root, ds, cx, half, side, shoulder)
		_build_embankment(root, ds, cx, half, side, shoulder)
	_build_medians(root, entry)
	_place_props(root, entry)
	_place_pickups(root, entry)
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
	asphalt.polygon = _strip(left, right)
	asphalt.z_index = -1
	root.add_child(asphalt)
	_add_marks(root, "CenterLine", center, &"dashed_yellow")
	_add_marks(root, "EdgeL", edge_l, &"dashed_white")
	_add_marks(root, "EdgeR", edge_r, &"dashed_white")

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
## rect Col per segment. Shoulders and medians share it.
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
	vis.color = SHOULDER_VIS.get(kind, SHOULDER_VIS[&"grass"])
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

## Local road direction at d (north = -y), for aligning rail segments.
static func _road_angle(entry: Dictionary, d: float) -> float:
	var behind := _center_x(entry, maxf(d - 40.0, 0.0))
	var ahead := _center_x(entry, d + 40.0)
	return Vector2(ahead - behind, -80.0).angle()

## The impassable rim: an opaque painted slope with a layer-2 wall under its
## inner edge — "floor 2 but no way up", so nothing feels invisible.
static func _build_embankment(root: Node2D, ds: Array, cx: Array, half: Array, side: float, shoulder: StringName) -> void:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var crest := PackedVector2Array()
	for i in ds.size():
		var y: float = -ds[i]
		var e: float = cx[i] + side * (half[i] + SHOULDER_W)
		inner.append(Vector2(e, y))
		outer.append(Vector2(e + side * EMBANK_W, y))
		crest.append(Vector2(e + side * EMBANK_W * 0.62, y))
	var wall := StaticBody2D.new()
	wall.name = "EmbankL" if side < 0.0 else "EmbankR"
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
			&"pothole":
				_pothole(root, pos, rng)
			&"jump":
				# The arena launch pad, highway edition: airborne clears the
				# logs and potholes — and the wall doesn't care where you land.
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
		else:
			var ammo := AmmoScene.instantiate()
			ammo.position = pos
			ammo.kind = String(kind)
			root.add_child(ammo)

## Pothole: a cracked pale lip around a dark pit (pure paint) over a small
## dirt TerrainZone — hitting one costs grip for a beat; airtime clears it.
static func _pothole(root: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var r := 36.0
	var lip := PackedVector2Array()
	var pit := PackedVector2Array()
	var n := 10
	for i in n:
		var a := TAU * float(i) / float(n)
		var rad := r * rng.randf_range(0.75, 1.05)
		var spoke := Vector2(cos(a) * 1.25, sin(a) * 0.85)
		lip.append(pos + spoke * (rad + 7.0))
		pit.append(pos + spoke * rad)
	var lip_poly := Polygon2D.new()
	lip_poly.polygon = lip
	lip_poly.color = Color(0.28, 0.27, 0.28)
	lip_poly.z_index = -1
	root.add_child(lip_poly)
	var pit_poly := Polygon2D.new()
	pit_poly.polygon = pit
	pit_poly.color = Color(0.09, 0.09, 0.1)
	pit_poly.z_index = -1
	root.add_child(pit_poly)
	var zone := Area2D.new()
	zone.set_script(TerrainZoneScript)
	zone.name = "Pothole"
	zone.collision_layer = 128
	zone.collision_mask = 0
	zone.terrain_type = &"dirt"
	zone.position = pos
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	col.shape = shape
	zone.add_child(col)
	root.add_child(zone)

static func _strip(forward: PackedVector2Array, back: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append_array(forward)
	for i in range(back.size() - 1, -1, -1):
		out.append(back[i])
	return out
