extends RefCounted
## The arena field manual's MUST, mechanized: "pits and deep water are
## hazard-curbed for AI" — every DeepWaterZone/PitZone rim in the master
## level list must be protected along its whole length. A rim sample counts
## as protected when a hazard curb covers it, a chained sibling zone
## continues it (composed river/quay rects), or a boundary wall closes the
## approach (water dying into the arena edge needs no rail). This would have
## caught Capital's 44px curb pockets at authoring time. Levels that build
## hazards at runtime (the chase) naturally contribute nothing un-treed.

const SpawnList := preload("res://tests/test_spawn_distance.gd")

const SAMPLE_STEP := 64.0
const CURB_TOL := 32.0   # sample within this of a curb rect = railed (Memorial
						 # is flush and Piers curbs sit INSIDE the rim; 32 is
						 # generous — Capital's 44px pockets were the disease)
const CHAIN_TOL := 8.0   # sample inside a sibling zone grown by this = chained
const WALL_TOL := 96.0   # sample within this of a wall solid = walled
const RUNWAY_FWD := 600.0    # authored jump/edge connector launch corridor...
const RUNWAY_HALF := 160.0   # ...length and half-width (pads are 224 wide)

var t

func _init(runner) -> void:
	t = runner

func _script_path(n: Node) -> String:
	var sc: Script = n.get_script() as Script
	return sc.resource_path if sc else ""

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

func _node_rect(n: Node2D) -> Rect2:
	var sz: Vector2 = n.get("size")
	return Rect2(n.global_position - sz * 0.5, sz)

func _rect_distance(p: Vector2, r: Rect2) -> float:
	var c := p.clamp(r.position, r.position + r.size)
	return p.distance_to(c)

## Wall geometry: authored StaticBody2D shapes (rects + polygons) on the wall
## bit or a floor bit (terrace retaining walls carry floor bits, not bit 2).
## Un-treed instantiate reads .tscn-authored layers, so script-set layers
## (destructible rails author base layer 4) correctly do NOT count as walls.
func _collect_walls(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		if not (n is StaticBody2D) or ((n as StaticBody2D).collision_layer & (2 | 8 | 16 | 32)) == 0:
			continue
		for child in n.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
				var shape := (child as CollisionShape2D).shape as RectangleShape2D
				out.append(Rect2((child as Node2D).global_position - shape.size * 0.5, shape.size))
			elif child is CollisionPolygon2D:
				var poly: PackedVector2Array = (child as CollisionPolygon2D).polygon
				var xf: Transform2D = (child as Node2D).get_global_transform()
				var world := PackedVector2Array()
				for v in poly:
					world.append(xf * v)
				out.append(world)
	return out

func _near_wall(p: Vector2, walls: Array) -> bool:
	for w in walls:
		if w is Rect2:
			if _rect_distance(p, w) <= WALL_TOL:
				return true
		elif w is PackedVector2Array:
			var poly := w as PackedVector2Array
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
			for i in poly.size():
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % poly.size()]
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= WALL_TOL:
					return true
	return false

## An authored FloorConnector launch corridor is a SANCTIONED crossing — the
## pier-end stunt jump's runway must never demand a curb across itself.
func _in_runway(p: Vector2, connectors: Array) -> bool:
	for c in connectors:
		var origin: Vector2 = c[0]
		var fwd: Vector2 = c[1]
		var rel := p - origin
		var along := rel.dot(fwd)
		if along >= -64.0 and along <= RUNWAY_FWD and absf(rel.cross(fwd)) <= RUNWAY_HALF:
			return true
	return false

func _protected(p: Vector2, zone_idx: int, zones: Array, curbs: Array,
		walls: Array, connectors: Array) -> bool:
	for c in curbs:
		if _rect_distance(p, c) <= CURB_TOL:
			return true
	for i in zones.size():
		if i != zone_idx and (zones[i] as Rect2).grow(CHAIN_TOL).has_point(p):
			return true
	if _in_runway(p, connectors):
		return true
	return _near_wall(p, walls)

func test_every_lethal_rim_is_protected() -> void:
	var linted := 0
	for path in SpawnList.CAMPAIGN:
		var tag: String = String(path).get_file()
		var lvl: Node = (load(path) as PackedScene).instantiate()
		var nodes: Array = []
		_walk(lvl, nodes)
		var zones: Array = []
		var zone_names: Array = []
		var curbs: Array = []
		var connectors: Array = []
		for n in nodes:
			var sp := _script_path(n)
			if sp.ends_with("deep_water_zone.gd") or sp.ends_with("pit_zone.gd"):
				zones.append(_node_rect(n))
				zone_names.append(n.name)
			elif sp.ends_with("hazard_curb.gd"):
				curbs.append(_node_rect(n))
			elif sp.ends_with("floor_connector.gd"):
				var fwd: Vector2 = (n.get("approach_dir") as Vector2).normalized()
				if fwd != Vector2.ZERO:
					connectors.append([(n as Node2D).global_position, fwd])
		if zones.is_empty():
			lvl.free()
			continue
		linted += 1
		var walls := _collect_walls(nodes)
		for zi in zones.size():
			var r: Rect2 = zones[zi]
			var holes := 0
			var first := Vector2.INF
			for edge in [[r.position, Vector2(r.size.x, 0)],
					[r.position + Vector2(0, r.size.y), Vector2(r.size.x, 0)],
					[r.position, Vector2(0, r.size.y)],
					[r.position + Vector2(r.size.x, 0), Vector2(0, r.size.y)]]:
				var origin: Vector2 = edge[0]
				var run: Vector2 = edge[1]
				var steps := int(ceil(run.length() / SAMPLE_STEP))
				for s in steps + 1:
					var p: Vector2 = origin + run * (float(s) / float(steps))
					if not _protected(p, zi, zones, curbs, walls, connectors):
						holes += 1
						if first == Vector2.INF:
							first = p
			t.check(holes == 0, "%s: %s rim fully protected (%d open samples, first at %s)" %
				[tag, zone_names[zi], holes, first.round()])
		lvl.free()
	t.check(linted >= 3, "sweep linted %d hazard-bearing levels (>=3)" % linted)
