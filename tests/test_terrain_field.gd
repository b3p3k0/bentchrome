extends RefCounted
## TerrainField contract: one deterministic union skin over untouched terrain
## tiles, while physics and radar continue to read the authored TerrainZones.

const TerrainFieldScript := preload("res://environment/terrain_field.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const TerrainSensorScript := preload("res://vehicles/terrain_sensor.gd")
const RectUnion := preload("res://environment/rect_union.gd")
const RadarScript := preload("res://ui/radar.gd")

const TILE_SIZE := 256.0
const TILE_LAYER := 1

var t

func _init(runner) -> void:
	t = runner

func _tile(rect: Rect2, terrain_type := &"snow", vis := false,
		layer := TILE_LAYER) -> TerrainZone:
	var tile := TerrainZoneScript.new() as TerrainZone
	tile.name = "Tile_%d_%d" % [int(rect.position.x), int(rect.position.y)]
	tile.position = rect.get_center()
	tile.terrain_type = terrain_type
	tile.collision_layer = layer
	tile.collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	tile.add_child(col)
	if vis:
		var polygon := Polygon2D.new()
		polygon.name = "Vis"
		polygon.polygon = PackedVector2Array([
			-rect.size * 0.5, Vector2(rect.size.x, -rect.size.y) * 0.5,
			rect.size * 0.5, Vector2(-rect.size.x, rect.size.y) * 0.5,
		])
		tile.add_child(polygon)
	return tile

func _quilt_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for y in 3:
		for x in 3:
			if x == 1 and y == 0:
				continue
			rects.append(Rect2(x * TILE_SIZE, y * TILE_SIZE,
				TILE_SIZE, TILE_SIZE))
	return rects

func _field(rects: Array[Rect2], seed := 173,
		position := Vector2.ZERO):
	var field = TerrainFieldScript.new()
	field.position = position
	field.paint_seed = seed
	for rect: Rect2 in rects:
		field.add_child(_tile(rect))
	return field

func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

func _distance_to_loops(point: Vector2,
		loops: Array[PackedVector2Array]) -> float:
	var best := INF
	for loop: PackedVector2Array in loops:
		for i in loop.size():
			var closest := Geometry2D.get_closest_point_to_segment(
				point, loop[i], loop[(i + 1) % loop.size()])
			best = minf(best, point.distance_to(closest))
	return best

func _same_loops(a: Array[PackedVector2Array],
		b: Array[PackedVector2Array]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

func _warnings_contain(warnings: PackedStringArray, needle: String) -> bool:
	for warning: String in warnings:
		if warning.to_lower().contains(needle.to_lower()):
			return true
	return false

func test_quilt_builds_one_near_boundary_skin_without_tile_notches() -> void:
	var rects := _quilt_rects()
	var field = _field(rects, 917, Vector2(137, 211))
	t.root.add_child(field)
	var loops: Array[PackedVector2Array] = field.outline_loops()
	var boundary := RectUnion.outline(rects)
	var near_boundary := loops.size() == 1 and boundary.size() == 1
	var no_deep_interior_vertices := near_boundary
	for point: Vector2 in loops[0] if not loops.is_empty() else PackedVector2Array():
		var distance := _distance_to_loops(point, boundary)
		near_boundary = near_boundary and distance <= field.corner_radius + 0.01
		if RectUnion.contains(rects, point):
			no_deep_interior_vertices = no_deep_interior_vertices \
				and distance <= field.corner_radius + 0.01
	var generated: Node = field.get_node(^"_Generated")
	t.check(loops.size() == 1 and generated.get_child_count() == 1,
		"terrain field: edge-missing 3x3 quilt paints exactly one union loop")
	t.check(near_boundary and no_deep_interior_vertices,
		"terrain field: every quilt vertex stays in the union boundary band")
	t.check(field.validation_warnings().is_empty(),
		"terrain field: valid abutting quilt has no validation warnings")
	var changed: Array[PackedVector2Array] = field.outline_loops()
	changed[0][0] += Vector2(999, 999)
	t.check(changed[0] != field.outline_loops()[0],
		"terrain field: outline reader returns deep copies")
	_free_node(field)

func test_ready_leaves_authored_tiles_and_collision_shapes_untouched() -> void:
	var field = _field(_quilt_rects(), 41, Vector2(-300, 125))
	var snapshots: Array[Dictionary] = []
	for child: Node in field.get_children():
		var tile := child as TerrainZone
		var col := tile.get_node(^"Col") as CollisionShape2D
		snapshots.append({
			"tile": tile, "position": tile.position, "shape": col.shape,
			"size": (col.shape as RectangleShape2D).size,
			"terrain": tile.terrain_type, "layer": tile.collision_layer,
		})
	t.root.add_child(field)
	var untouched := true
	for snapshot: Dictionary in snapshots:
		var tile: TerrainZone = snapshot.tile
		var col := tile.get_node(^"Col") as CollisionShape2D
		untouched = untouched and tile.position == snapshot.position \
			and col.shape == snapshot.shape \
			and (col.shape as RectangleShape2D).size == snapshot.size \
			and tile.terrain_type == snapshot.terrain \
			and tile.collision_layer == snapshot.layer
	t.check(untouched, "terrain field: _ready leaves every authored tile unchanged")
	_free_node(field)

func test_vehicle_style_probe_reads_tile_inside_and_road_outside() -> void:
	var field = _field([Rect2(0, 0, TILE_SIZE, TILE_SIZE)], 12,
		Vector2(200, 300))
	t.root.add_child(field)
	var sensor := TerrainSensorScript.new() as TerrainSensor
	sensor.position = field.to_global(Vector2(TILE_SIZE, TILE_SIZE) * 0.5)
	sensor.collision_layer = 0
	sensor.collision_mask = TILE_LAYER
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	sensor.add_child(col)
	t.root.add_child(sensor)
	await t.root.get_tree().physics_frame
	await t.root.get_tree().physics_frame
	var reads_snow: bool = sensor.current_terrain == &"snow" \
		and field.get_child(1) in sensor.get_overlapping_areas()
	sensor.position = field.to_global(Vector2(900, 900))
	await t.root.get_tree().physics_frame
	await t.root.get_tree().physics_frame
	t.check(reads_snow and sensor.current_terrain == &"road",
		"terrain field: TerrainSensor reads snow inside a tile and road outside")
	_free_node(sensor)
	_free_node(field)

func _radar_body(parent: Node, at: Vector2,
		body_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)

func test_radar_scans_each_field_tile_like_a_standalone_zone() -> void:
	var arena := Node2D.new()
	_radar_body(arena, Vector2(500, 0), Vector2(1000, 20))
	_radar_body(arena, Vector2(500, 1000), Vector2(1000, 20))
	_radar_body(arena, Vector2(0, 500), Vector2(20, 1000))
	_radar_body(arena, Vector2(1000, 500), Vector2(20, 1000))
	var rects: Array[Rect2] = [
		Rect2(0, 0, 256, 256), Rect2(256, 0, 256, 256),
	]
	var field = _field(rects, 7, Vector2(100, 200))
	arena.add_child(field)
	var standalone := _tile(Rect2(700, 700, 128, 128))
	arena.add_child(standalone)
	t.root.add_child(arena)
	t.current_scene = arena
	var radar := RadarScript.new()
	arena.add_child(radar)
	radar._scan()
	var expected: Array[Rect2] = field.tile_rects()
	var standalone_col := standalone.get_node(^"Col") as CollisionShape2D
	var standalone_shape := standalone_col.shape as RectangleShape2D
	expected.append(Rect2(standalone_col.global_position - standalone_shape.size * 0.5,
		standalone_shape.size))
	var matched := 0
	for wanted: Rect2 in expected:
		for entry_v: Variant in radar._terrain:
			var entry: Dictionary = entry_v
			if entry.rect == wanted:
				matched += 1
				break
	t.check(radar._terrain.size() == expected.size() and matched == expected.size(),
		"terrain field: radar retains one authored rect per tile and standalone zone")
	t.current_scene = null
	_free_node(arena)

func test_validation_reports_holes_vis_mixed_types_and_overlaps() -> void:
	var ring_rects: Array[Rect2] = []
	for y in 3:
		for x in 3:
			if x != 1 or y != 1:
				ring_rects.append(Rect2(x * TILE_SIZE, y * TILE_SIZE,
					TILE_SIZE, TILE_SIZE))
	var ring = _field(ring_rects)
	t.root.add_child(ring)
	var ring_warnings: PackedStringArray = ring.validation_warnings()
	t.check(_warnings_contain(ring_warnings, "hole")
			and ring.outline_loops().size() == 1
			and ring.get_node(^"_Generated").get_child_count() == 1,
		"terrain field: a ring reports its hole but still paints the outer loop")
	_free_node(ring)

	var invalid = TerrainFieldScript.new()
	invalid.add_child(_tile(Rect2(0, 0, 256, 256), &"snow", true))
	invalid.add_child(_tile(Rect2(128, 0, 256, 256), &"ice"))
	t.root.add_child(invalid)
	var warnings: PackedStringArray = invalid.validation_warnings()
	t.check(_warnings_contain(warnings, "vis child"),
		"terrain field: a tile Vis child is reported")
	t.check(_warnings_contain(warnings, "mixed terrain_type"),
		"terrain field: mixed tile terrain types are reported")
	t.check(_warnings_contain(warnings, "overlaps"),
		"terrain field: tile interior overlap is reported")
	_free_node(invalid)

func test_closed_side_bleeds_past_bounds_and_remains_straight() -> void:
	var field = _field(_quilt_rects(), 88, Vector2(400, 300))
	field.bounds = Rect2(Vector2(field.position.x, -10000), Vector2(10000, 20000))
	t.root.add_child(field)
	var loop: PackedVector2Array = field.outline_loops()[0]
	var min_world_x := INF
	for point: Vector2 in loop:
		min_world_x = minf(min_world_x, field.to_global(point).x)
	var straight_span := 0.0
	for i in loop.size():
		var a: Vector2 = field.to_global(loop[i])
		var b: Vector2 = field.to_global(loop[(i + 1) % loop.size()])
		if is_equal_approx(a.x, min_world_x) and is_equal_approx(b.x, min_world_x):
			straight_span = maxf(straight_span, absf(b.y - a.y))
	t.check(min_world_x <= field.bounds.position.x - field.bleed + 0.01,
		"terrain field: closed side paint reaches at least bleed past the bound")
	t.check(straight_span >= TILE_SIZE * 3.0 - field.corner_radius * 2.0 - 0.01,
		"terrain field: closed side remains one straight boundary span")
	_free_node(field)

func test_seeded_loops_are_exact_and_material_is_shared() -> void:
	var material := ShaderMaterial.new()
	var first = _field(_quilt_rects(), 1234)
	var second = _field(_quilt_rects(), 1234, Vector2(1200, 700))
	first.terrain_material = material
	t.root.add_child(first)
	t.root.add_child(second)
	var surface := first.get_node(^"_Generated/Surface") as Polygon2D
	var fallback := second.get_node(^"_Generated/Surface") as Polygon2D
	t.check(_same_loops(first.outline_loops(), second.outline_loops()),
		"terrain field: identical tiles and seed produce identical local loops")
	t.check(surface.material == material,
		"terrain field: generated paint shares rather than duplicates its material")
	t.check(fallback.material == null and fallback.color == second.fill_color,
		"terrain field: null material uses the authored fallback fill color")
	t.check(first.corner_radius == TerrainZoneScript.CORNER_RADIUS
			and first.edge_step == TerrainZoneScript.EDGE_STEP
			and first.edge_jitter == TerrainZoneScript.EDGE_JITTER,
		"terrain field: softening defaults come from TerrainZone constants")
	_free_node(first)
	_free_node(second)

func test_eighty_tile_field_builds_under_150_ms() -> void:
	var rects: Array[Rect2] = []
	for y in 8:
		for x in 10:
			rects.append(Rect2(x * 128, y * 128, 128, 128))
	var field = _field(rects, 991)
	var started := Time.get_ticks_usec()
	t.root.add_child(field)
	var elapsed := Time.get_ticks_usec() - started
	print("terrain field performance: %.3f ms" % (float(elapsed) / 1000.0))
	t.check(elapsed < 150000,
		"terrain field: 80-tile _ready completes under 150 ms")
	_free_node(field)
