extends RefCounted
## Geometry and generated-scene probes for Mountainside's grid-authored furniture.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")
const PassBuilder := preload("res://levels/snowy/pass_builder.gd")
const BoulderScript := preload("res://environment/boulder.gd")
const ClutterScript := preload("res://environment/clutter.gd")
const DerelictCarScript := preload("res://environment/derelict_car.gd")

const SOLID_KINDS := [&"boulder", &"wreck", &"pine"]
const SOFT_KINDS := [&"drift", &"cone", &"sign"]
const COUNTS := {
	&"boulder": 4, &"wreck": 3, &"pine": 39, &"drift": 10, &"cone": 6,
	&"sign": 3,
}

static func geometry_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var pieces := _pieces()
	var knoll := _knoll_rect()
	var road := _terrain_rects(&"road")
	var pits := _terrain_rects(&"pit")
	var mountains := _terrain_rects(&"mountain")
	for kind: StringName in COUNTS:
		var data: Array = PassGrid.FURNITURE.get(kind, [])
		if data.size() != COUNTS[kind] or PassGrid.furniture_rects(kind).size() != COUNTS[kind]:
			errors.append("%s count %d/%d, want %d" % [kind, data.size(),
				PassGrid.furniture_rects(kind).size(), COUNTS[kind]])
	for piece: Dictionary in pieces:
		var rect: Rect2 = piece["rect"]
		if not _rect_driveable(rect):
			errors.append("%s is not wholly driveable: %s" % [piece["name"], rect])
		if rect.intersects(knoll):
			errors.append("%s intersects knoll %s" % [piece["name"], knoll])
		for rail: Rect2 in PassGrid.rail_segments():
			if rect.intersects(rail):
				errors.append("%s intersects rail %s" % [piece["name"], rail])
				break
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var nodes: Array[Node] = []
	_walk(level, nodes)
	var pickups: Array[Vector2] = []
	for node: Node in nodes:
		if node.scene_file_path.ends_with("ammo_pickup.tscn"):
			pickups.append((node as Node2D).global_position)
	var solids := pieces.filter(func(piece): return SOLID_KINDS.has(piece["kind"]))
	for i in solids.size():
		_check_solid(errors, solids[i], road, pickups, knoll)
		for j in range(i + 1, solids.size()):
			if (solids[i]["rect"] as Rect2).intersects(solids[j]["rect"]):
				errors.append("solids %s and %s overlap" %
					[solids[i]["name"], solids[j]["name"]])
	_check_kind_clearances(errors, pieces, road, pits, mountains)
	level.free()
	return errors

static func scene_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var built := PassBuilder.build_furniture()
	var saved := (load("res://levels/snowy/pass_furniture.tscn") as PackedScene).instantiate()
	if not _same_tree(built, saved):
		errors.append("pass_furniture.tscn differs from build_furniture()")
	var group_names := PackedStringArray(["Boulders", "Wrecks", "PineGroves",
		"Drifts", "Markers"])
	if built.name != &"Furniture" or built.get_script() != null \
			or built.get_child_count() != group_names.size():
		errors.append("Furniture root is not the plain five-group tree")
	else:
		for i in group_names.size():
			var group := built.get_child(i)
			if group.name != group_names[i] or group.get_class() != "Node2D" \
					or group.get_script() != null:
				errors.append("group %d is %s/%s" % [i, group.name, group.get_class()])
	_check_group(errors, built.get_node(^"Boulders"), [&"boulder"])
	_check_group(errors, built.get_node(^"Wrecks"), [&"wreck"])
	_check_group(errors, built.get_node(^"PineGroves"), [&"pine"])
	_check_group(errors, built.get_node(^"Drifts"), [&"drift"])
	_check_group(errors, built.get_node(^"Markers"), [&"cone", &"sign"])
	if not is_equal_approx(ClutterScript.PINE_HP, 40.0):
		errors.append("pine durability is %.1f, want 40" % ClutterScript.PINE_HP)
	built.free()
	saved.free()
	_check_level_instance(errors)
	return errors

static func level_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var nodes: Array[Node] = []
	_walk(level, nodes)
	var ammo := {}
	var station_count := 0
	for node: Node in nodes:
		if node.scene_file_path.ends_with("ammo_pickup.tscn"):
			var kind := String(node.get("kind"))
			ammo[kind] = true
			var distance := _distance_to_rim((node as Node2D).global_position)
			if distance < 256.0:
				errors.append("pickup %s is %.1f from rim" % [node.name, distance])
		elif node.scene_file_path.ends_with("health_station.tscn"):
			station_count += 1
	for kind in ["standard", "homing", "power", "rear"]:
		if not ammo.has(kind):
			errors.append("missing %s missile crate" % kind)
	if station_count != 1:
		errors.append("repair station count %d, want 1" % station_count)
	var skiers := level.get_node_or_null(^"AmbientLife/Skiers") as Node2D
	var deer := level.get_node_or_null(^"SnowyHill/DeerHerd") as Node2D
	if skiers == null or int(skiers.get("count")) != 2 \
			or not is_equal_approx(float(skiers.get("speed")), 80.0) \
			or not is_equal_approx(float(skiers.get("lane_spread")), 20.0):
		errors.append("skiers do not retain count 2, speed 80, spread 20")
	if deer == null or int(deer.get("count")) != 5:
		errors.append("deer herd count is not 5")
	if skiers != null:
		_check_skier_route(errors, skiers)
	level.free()
	return errors

static func _check_solid(errors: PackedStringArray, piece: Dictionary,
		road: Array[Rect2], pickups: Array[Vector2], knoll: Rect2) -> void:
	var rect: Rect2 = piece["rect"]
	if _nearest(rect, road) <= 0.0:
		errors.append("%s touches road" % piece["name"])
	for spawn_name in PassGrid.SPAWNS:
		var distance := _point_rect_distance(PassGrid.SPAWNS[spawn_name]["center"], rect)
		if distance < 256.0:
			errors.append("%s is %.1f from spawn %s" % [piece["name"], distance, spawn_name])
	var station_distance := _point_rect_distance(PassGrid.STATION["center"], rect)
	if station_distance < 200.0:
		errors.append("%s is %.1f from station" % [piece["name"], station_distance])
	for pickup: Vector2 in pickups:
		var distance := _point_rect_distance(pickup, rect)
		if distance < 96.0:
			errors.append("%s is %.1f from pickup %s" % [piece["name"], distance, pickup])
	for pad_name in PassGrid.PADS:
		if rect.intersects(_pad_lane(PassGrid.PADS[pad_name])):
			errors.append("%s intersects %s launch lane" % [piece["name"], pad_name])
	var knoll_distance := _rect_distance(rect, knoll)
	if knoll_distance < 192.0:
		errors.append("%s is %.1f from knoll" % [piece["name"], knoll_distance])
	if rect.intersects(_runaway_run_in()):
		errors.append("%s intersects runaway run-in" % piece["name"])

static func _check_kind_clearances(errors: PackedStringArray, pieces: Array,
		road: Array[Rect2], pits: Array[Rect2], mountains: Array[Rect2]) -> void:
	var boulders := pieces.filter(func(piece): return piece["kind"] == &"boulder")
	for i in boulders.size():
		var piece: Dictionary = boulders[i]
		var rect: Rect2 = piece["rect"]
		var road_gap := _nearest(rect, road)
		var pit_gap := _nearest(rect, pits)
		var mountain_gap := _nearest(rect, mountains)
		if road_gap < 64.0 or pit_gap < 160.0 \
				or mountain_gap > 24.0 and mountain_gap < 160.0:
			errors.append("%s gaps road %.1f pit %.1f mountain %.1f" %
				[piece["name"], road_gap, pit_gap, mountain_gap])
		for j in range(i + 1, boulders.size()):
			var gap := _rect_distance(rect, boulders[j]["rect"])
			if gap > 24.0 and gap < 160.0:
				errors.append("boulder gap %s/%s is %.1f" %
					[piece["name"], boulders[j]["name"], gap])
	for piece: Dictionary in pieces:
		var kind: StringName = piece["kind"]
		var rect: Rect2 = piece["rect"]
		if (kind == &"wreck" or kind == &"pine") \
				and (_point_nearest(piece["center"], road) < 32.0 \
				or _point_nearest(piece["center"], pits) < 96.0):
			errors.append("%s gaps road %.1f pit %.1f" %
				[piece["name"], _point_nearest(piece["center"], road),
					_point_nearest(piece["center"], pits)])
		elif SOFT_KINDS.has(kind):
			_check_soft(errors, piece, pits)
	var pines := pieces.filter(func(piece): return piece["kind"] == &"pine")
	for i in pines.size():
		for j in range(i + 1, pines.size()):
			var gap := _rect_distance(pines[i]["rect"], pines[j]["rect"])
			if gap < 40.0:
				errors.append("pine gap %s/%s is %.1f" %
					[pines[i]["name"], pines[j]["name"], gap])

static func _check_soft(errors: PackedStringArray, piece: Dictionary,
		pits: Array[Rect2]) -> void:
	var center: Vector2 = piece["center"]
	if _point_nearest(center, pits) < 48.0:
		errors.append("%s is %.1f from pit/drop" %
			[piece["name"], _point_nearest(center, pits)])
	for spawn_name in PassGrid.SPAWNS:
		var distance := center.distance_to(PassGrid.SPAWNS[spawn_name]["center"])
		if distance < 96.0:
			errors.append("%s is %.1f from spawn %s" % [piece["name"], distance, spawn_name])
	for pad_name in PassGrid.PADS:
		var pad: Dictionary = PassGrid.PADS[pad_name]
		var size: Vector2 = pad["size"]
		if Rect2(pad["center"] - size * 0.5, size).has_point(center):
			errors.append("%s intersects jump pad %s" % [piece["name"], pad_name])

static func _check_group(errors: PackedStringArray, group: Node, kinds: Array) -> void:
	var entries: Array = []
	for kind: StringName in kinds:
		for data: Dictionary in PassGrid.FURNITURE[kind]:
			entries.append({"kind": kind, "data": data})
	if group.get_child_count() != entries.size():
		errors.append("%s count %d, want %d" %
			[group.name, group.get_child_count(), entries.size()])
		return
	for i in entries.size():
		var node := group.get_child(i) as Node2D
		var kind: StringName = entries[i]["kind"]
		var data: Dictionary = entries[i]["data"]
		if node.name != data["name"] or node.position != data["center"]:
			errors.append("%s[%d] does not match data" % [group.name, i])
		if kind == &"boulder":
			var col := node.get_node_or_null(^"Col") as CollisionShape2D
			var shape := col.shape as RectangleShape2D if col else null
			if node.get_script() != BoulderScript or node.get("size") != data["size"] \
					or node.get("floor_index") != data["floor"] \
					or node.get("paint_seed") != data["paint_seed"] \
					or shape == null or shape.size != data["size"]:
				errors.append("%s boulder exports/collider differ" % node.name)
		elif kind == &"wreck":
			if node.get_script() != DerelictCarScript \
					or not is_equal_approx(node.rotation, float(data["rotation"])) \
					or node.get("max_hp") != data["max_hp"] \
					or node.get("floor_index") != data["floor"] \
					or node.get("arena_net_id") != data["arena_net_id"]:
				errors.append("%s wreck exports differ" % node.name)
		elif node.get_script() != ClutterScript or node.get("kind") != kind \
				or node.get("footprint") != data["footprint"] \
				or node.get("floor_index") != data["floor"]:
			errors.append("%s clutter exports differ" % node.name)

static func _check_level_instance(errors: PackedStringArray) -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var furniture := level.get_node_or_null(^"Furniture") as Node2D
	var rails := level.get_node_or_null(^"Rails") as Node2D
	if furniture == null \
			or furniture.scene_file_path != "res://levels/snowy/pass_furniture.tscn" \
			or furniture.get_parent() != level or rails == null \
			or furniture.get_index() != rails.get_index() + 1:
		errors.append("Furniture is not the generated direct child immediately after Rails")
	if furniture != null:
		for child: Node in level.get_children():
			var gameplay := child is Vehicle or String(child.name).begins_with("Jump") \
				or child.scene_file_path.ends_with("ammo_pickup.tscn") \
				or child.scene_file_path.ends_with("health_station.tscn")
			if gameplay and furniture.get_index() >= child.get_index():
				errors.append("Furniture follows gameplay node %s" % child.name)
	var ids := {}
	var wreck_ids: Array[int] = []
	var nodes: Array[Node] = []
	_walk(level, nodes)
	for node: Node in nodes:
		if not _has_property(node, &"arena_net_id"):
			continue
		var arena_id := int(node.get("arena_net_id"))
		if arena_id <= 0:
			continue
		if ids.has(arena_id):
			errors.append("arena_net_id %d collides on %s/%s" %
				[arena_id, ids[arena_id], node.name])
		ids[arena_id] = node.name
		if node.get_parent() != null and node.get_parent().name == &"Wrecks":
			wreck_ids.append(arena_id)
	if wreck_ids != [50, 51, 52]:
		errors.append("wreck arena IDs are %s" % [wreck_ids])
	level.free()

static func _check_skier_route(errors: PackedStringArray, skiers: Node2D) -> void:
	var points: PackedVector2Array = skiers.get("route_points")
	var solids := PassGrid.solid_furniture_rects()
	for point: Vector2 in points:
		var world := skiers.global_transform * point
		var cell := PassGrid.cell_of(world)
		if not PassGrid.is_driveable(cell.x, cell.y):
			errors.append("skier vertex %s is not driveable" % world)
		for solid: Rect2 in solids:
			var distance := _point_rect_distance(world, solid)
			if distance < 64.0:
				errors.append("skier vertex %s is %.1f from solid %s" %
					[world, distance, solid])
	var boulders := PassGrid.furniture_rects(&"boulder")
	for i in points.size() - 1:
		var a := skiers.global_transform * points[i]
		var b := skiers.global_transform * points[i + 1]
		for rect: Rect2 in boulders:
			if _segment_hits_rect(a, b, rect):
				errors.append("skier leg %s -> %s crosses boulder %s" % [a, b, rect])

static func _pieces() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for kind: StringName in PassGrid.FURNITURE:
		var rects := PassGrid.furniture_rects(kind)
		for i in rects.size():
			pieces.append({"kind": kind, "name": PassGrid.FURNITURE[kind][i]["name"],
				"center": PassGrid.FURNITURE[kind][i]["center"], "rect": rects[i]})
	return pieces

static func _terrain_rects(kind: StringName) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			var cell_kind := PassGrid.kind_at(i, j)
			var matches := kind == &"road" and PassGrid.is_road(i, j) \
				or kind == &"pit" and _is_pit(cell_kind) \
				or kind == &"mountain" and cell_kind == PassGrid.MOUNTAIN
			if matches:
				rects.append(PassGrid.cell_rect(i, j))
	return rects

static func _rect_driveable(rect: Rect2) -> bool:
	var first := PassGrid.cell_of(rect.position + Vector2.ONE * 0.01)
	var last := PassGrid.cell_of(rect.end - Vector2.ONE * 0.01)
	for j in range(first.y, last.y + 1):
		for i in range(first.x, last.x + 1):
			if not PassGrid.is_driveable(i, j):
				return false
	return true

static func _knoll_rect() -> Rect2:
	var center: Vector2 = PassGrid.KNOLL["center"]
	var size := Vector2.ONE * float(PassGrid.KNOLL["footprint"])
	return Rect2(center - size * 0.5, size)

static func _cell_span_rect(cells: Rect2i) -> Rect2:
	return Rect2(PassGrid.ORIGIN + Vector2(cells.position) * PassGrid.CELL,
		Vector2(cells.size) * PassGrid.CELL)

static func _pad_lane(pad: Dictionary) -> Rect2:
	var center: Vector2 = pad["center"]
	var vertical: bool = pad["launch"] == &"north" or pad["launch"] == &"south"
	var size := Vector2(384.0, 900.0) if vertical else Vector2(900.0, 384.0)
	return Rect2(center - size * 0.5, size)

static func _runaway_run_in() -> Rect2:
	var rect := _cell_span_rect(PassGrid.SPUR_DATA["cells"])
	return Rect2(rect.position - Vector2(0, 64), rect.size + Vector2(384, 128))

static func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()

static func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))

static func _nearest(rect: Rect2, others: Array[Rect2]) -> float:
	var nearest := INF
	for other: Rect2 in others:
		nearest = minf(nearest, _rect_distance(rect, other))
	return nearest

static func _point_nearest(point: Vector2, others: Array[Rect2]) -> float:
	var nearest := INF
	for other: Rect2 in others:
		nearest = minf(nearest, _point_rect_distance(point, other))
	return nearest

static func _is_pit(kind: StringName) -> bool:
	return kind == PassGrid.DROP or kind == PassGrid.WEST_PIT or kind == PassGrid.EAST_PIT

static func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for i in corners.size():
		if Geometry2D.segment_intersects_segment(a, b, corners[i],
				corners[(i + 1) % corners.size()]) != null:
			return true
	return false

static func _rim_edges() -> Array[PackedVector2Array]:
	var edges: Array[PackedVector2Array] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			if not _is_pit(PassGrid.kind_at(i, j)):
				continue
			var rect := PassGrid.cell_rect(i, j)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
					Vector2i.UP, Vector2i.DOWN]:
				if not PassGrid.is_driveable(i + direction.x, j + direction.y):
					continue
				if direction == Vector2i.LEFT:
					edges.append(PackedVector2Array([rect.position,
						Vector2(rect.position.x, rect.end.y)]))
				elif direction == Vector2i.RIGHT:
					edges.append(PackedVector2Array([
						Vector2(rect.end.x, rect.position.y), rect.end]))
				elif direction == Vector2i.UP:
					edges.append(PackedVector2Array([rect.position,
						Vector2(rect.end.x, rect.position.y)]))
				else:
					edges.append(PackedVector2Array([
						Vector2(rect.position.x, rect.end.y), rect.end]))
	return edges

static func _distance_to_rim(point: Vector2) -> float:
	var nearest := INF
	for edge: PackedVector2Array in _rim_edges():
		var at := Geometry2D.get_closest_point_to_segment(point, edge[0], edge[1])
		nearest = minf(nearest, point.distance_to(at))
	return nearest

static func _same_tree(a: Node, b: Node) -> bool:
	if a.name != b.name or a.get_class() != b.get_class() or a.get_script() != b.get_script() \
			or a.get_child_count() != b.get_child_count():
		return false
	if a is Node2D:
		var node_a := a as Node2D
		var node_b := b as Node2D
		if node_a.position != node_b.position \
				or not is_equal_approx(node_a.rotation, node_b.rotation):
			return false
	if a is CollisionObject2D:
		var body_a := a as CollisionObject2D
		var body_b := b as CollisionObject2D
		if body_a.collision_layer != body_b.collision_layer \
				or body_a.collision_mask != body_b.collision_mask:
			return false
	for property: StringName in [
			&"size", &"paint_seed", &"max_hp", &"floor_index", &"arena_net_id",
			&"kind", &"footprint",
		]:
		if _has_property(a, property) != _has_property(b, property):
			return false
		if _has_property(a, property) and a.get(property) != b.get(property):
			return false
	if a is CollisionShape2D:
		var shape_a := (a as CollisionShape2D).shape as RectangleShape2D
		var shape_b := (b as CollisionShape2D).shape as RectangleShape2D
		if shape_a == null or shape_b == null or shape_a.size != shape_b.size:
			return false
	for i in a.get_child_count():
		if not _same_tree(a.get_child(i), b.get_child(i)):
			return false
	return true

static func _walk(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)

static func _has_property(node: Node, property: StringName) -> bool:
	for info: Dictionary in node.get_property_list():
		if info["name"] == property:
			return true
	return false
