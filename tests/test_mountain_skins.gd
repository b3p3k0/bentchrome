extends RefCounted
## MountainWall contract: one deterministic skin around untouched authored
## blocks, road-side chamfers, boundary bleed, and dual-role radar geometry.

const MountainWallScript := preload("res://environment/mountain_wall.gd")
const RadarScript := preload("res://ui/radar.gd")

const BLOCK_SIZE := Vector2(256, 256)
const BLOCK_LAYER := 54

var t

func _init(runner) -> void:
	t = runner

func _block(at: Vector2, body_size := BLOCK_SIZE,
		layer := BLOCK_LAYER) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	return body

func _fixture(seed := 173, closed_west := false, leg := 128.0) -> Dictionary:
	var wall := MountainWallScript.new() as MountainWall
	wall.position = Vector2(100, 200)
	wall.paint_seed = seed
	wall.chamfer_leg = leg
	var bands := [
		[Vector2(384, -384), Vector2(768, 256)],
		[Vector2(256, -128), Vector2(512, 256)],
		[Vector2(128, 128), Vector2(256, 256)],
	]
	for band: Array in bands:
		wall.add_child(_block(band[0], band[1]))
	if closed_west:
		wall.bounds = Rect2(Vector2(100, -2000), Vector2(4000, 4000))
	t.root.add_child(wall)
	return {"wall": wall}

func _real_scale_fixture() -> Dictionary:
	var wall := MountainWallScript.new() as MountainWall
	wall.position = Vector2(100, 200)
	wall.paint_seed = 173
	wall.bounds = Rect2(wall.position, Vector2(4096, 4096))
	for k in 14:
		var size := Vector2((18 - k) * 128, 128)
		wall.add_child(_block(Vector2(size.x * 0.5, k * 128 + 64), size))
	t.root.add_child(wall)
	return {"wall": wall}

func _done(fixture: Dictionary) -> void:
	var wall: MountainWall = fixture.wall
	if is_instance_valid(wall):
		t.root.remove_child(wall)
		wall.free()

func _point_in_loops(point: Vector2, loops: Array[PackedVector2Array]) -> bool:
	for loop: PackedVector2Array in loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			return true
	return false

func _distance_to_loops(point: Vector2,
		loops: Array[PackedVector2Array]) -> float:
	var best := INF
	for loop: PackedVector2Array in loops:
		for i in loop.size():
			var closest := Geometry2D.get_closest_point_to_segment(
				point, loop[i], loop[(i + 1) % loop.size()])
			best = minf(best, point.distance_to(closest))
	return best

func _outside_bounds(wall: MountainWall, a: Vector2, b: Vector2) -> bool:
	if not wall.bounds.has_area():
		return false
	var wa := wall.to_global(a)
	var wb := wall.to_global(b)
	return (wa.x < wall.bounds.position.x and wb.x < wall.bounds.position.x) \
		or (wa.x > wall.bounds.end.x and wb.x > wall.bounds.end.x) \
		or (wa.y < wall.bounds.position.y and wb.y < wall.bounds.position.y) \
		or (wa.y > wall.bounds.end.y and wb.y > wall.bounds.end.y)

func _distance_to_open_boundary(point: Vector2, wall: MountainWall,
		loops: Array[PackedVector2Array]) -> float:
	var best := INF
	for loop: PackedVector2Array in loops:
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			if _outside_bounds(wall, a, b):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
			best = minf(best, point.distance_to(closest))
	return best

func _is_loop_vertex(point: Vector2, loops: Array[PackedVector2Array]) -> bool:
	for loop: PackedVector2Array in loops:
		for candidate: Vector2 in loop:
			if point.is_equal_approx(candidate):
				return true
	return false

func _same_loops(a: Array[PackedVector2Array], b: Array[PackedVector2Array]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

func test_staircase_builds_one_painted_loop() -> void:
	var f := _fixture()
	var wall: MountainWall = f.wall
	t.check(wall.outline_loops().size() == 1,
		"mountain wall: three solid stepped bands paint as one silhouette")
	_done(f)

func test_paint_contains_every_block_corner_and_edge_midpoint() -> void:
	var f := _fixture()
	var wall: MountainWall = f.wall
	var loops: Array[PackedVector2Array] = wall.outline_loops()
	var contained := true
	for world_rect: Rect2 in wall.block_rects():
		var samples := PackedVector2Array([
			world_rect.position, Vector2(world_rect.end.x, world_rect.position.y),
			world_rect.end, Vector2(world_rect.position.x, world_rect.end.y),
			Vector2(world_rect.get_center().x, world_rect.position.y),
			Vector2(world_rect.end.x, world_rect.get_center().y),
			Vector2(world_rect.get_center().x, world_rect.end.y),
			Vector2(world_rect.position.x, world_rect.get_center().y),
		])
		for sample: Vector2 in samples:
			contained = contained and _point_in_loops(wall.to_local(sample), loops)
	for triangle: PackedVector2Array in wall.chamfer_triangles():
		var center := (triangle[0] + triangle[1] + triangle[2]) / 3.0
		contained = contained and _point_in_loops(center, loops)
	t.check(contained, "mountain wall: painted silhouette contains authored blocks and chamfers")
	_done(f)

func test_open_outline_stays_in_overhang_band() -> void:
	var f := _fixture()
	var wall: MountainWall = f.wall
	var solids := wall.solid_loops()
	var bases := wall.base_rim_loops()
	var in_band := true
	for loop: PackedVector2Array in wall.outline_loops():
		for point: Vector2 in loop:
			var distance := _distance_to_loops(point, solids)
			var upper := wall.overhang + wall.jitter + 0.5
			if _is_loop_vertex(point, bases):
				upper = maxf(upper, wall.overhang * sqrt(2.0) + 0.5)
			in_band = in_band and distance >= wall.overhang - wall.jitter - 0.5 \
				and distance <= upper
	t.check(in_band, "mountain wall: every open silhouette vertex stays in the overhang band")
	_done(f)

func test_closed_west_side_bleeds_and_rejects_chamfers() -> void:
	var f := _fixture(173, true)
	var wall: MountainWall = f.wall
	var farthest_west := INF
	for loop: PackedVector2Array in wall.outline_loops():
		for local_point: Vector2 in loop:
			farthest_west = minf(farthest_west, wall.to_global(local_point).x)
	var no_touch := true
	for triangle: PackedVector2Array in wall.chamfer_triangles():
		for local_point: Vector2 in triangle:
			no_touch = no_touch and not is_equal_approx(
				wall.to_global(local_point).x, wall.bounds.position.x)
	t.check(farthest_west <= wall.bounds.position.x - (wall.bleed - wall.jitter),
		"mountain wall: closed west side bleeds beyond the arena bound")
	t.check(no_touch, "mountain wall: no chamfer touches a closed side")
	_done(f)

func test_chamfers_fill_each_road_side_notch_on_the_authored_layer() -> void:
	var f := _fixture()
	var wall: MountainWall = f.wall
	var triangles: Array[PackedVector2Array] = wall.chamfer_triangles()
	var legs_match := triangles.size() == 2
	for triangle: PackedVector2Array in triangles:
		legs_match = legs_match and is_equal_approx(triangle[0].distance_to(triangle[1]),
			wall.chamfer_leg) and is_equal_approx(triangle[0].distance_to(triangle[2]),
			wall.chamfer_leg)
	var body := wall.get_node(^"_Generated/Chamfers") as StaticBody2D
	t.check(legs_match, "mountain wall: the 1:1 staircase gets two equal-leg chamfers")
	t.check(body.collision_layer == BLOCK_LAYER and body.collision_mask == 0,
		"mountain wall: generated chamfers copy authored layer and scan nothing")
	_done(f)

	var zero := _fixture(173, false, 0.0)
	var zero_wall: MountainWall = zero.wall
	t.check(zero_wall.chamfer_triangles().is_empty(),
		"mountain wall: chamfer_leg zero disables generated triangles")
	_done(zero)

func test_corner_touching_blocks_do_not_get_chamfers() -> void:
	var wall := MountainWallScript.new() as MountainWall
	wall.position = Vector2(100, 200)
	wall.add_child(_block(Vector2(128, 128)))
	wall.add_child(_block(Vector2(384, -128)))
	t.root.add_child(wall)
	t.check(wall.chamfer_triangles().is_empty(),
		"mountain wall: corner-only contact produces no chamfer")
	_done({"wall": wall})

func test_ready_never_mutates_authored_blocks() -> void:
	var wall := MountainWallScript.new() as MountainWall
	wall.position = Vector2(100, 200)
	var blocks: Array[StaticBody2D] = []
	var positions: Array[Vector2] = []
	var sizes: Array[Vector2] = []
	var bands := [
		[Vector2(384, -384), Vector2(768, 256)],
		[Vector2(256, -128), Vector2(512, 256)],
		[Vector2(128, 128), Vector2(256, 256)],
	]
	for band: Array in bands:
		var body := _block(band[0], band[1])
		blocks.append(body)
		positions.append(body.position)
		var col := body.get_node(^"Col") as CollisionShape2D
		var shape := col.shape as RectangleShape2D
		sizes.append(shape.size)
		wall.add_child(body)
	t.root.add_child(wall)
	var untouched := true
	for i in blocks.size():
		var col := blocks[i].get_node(^"Col") as CollisionShape2D
		var shape := col.shape as RectangleShape2D
		untouched = untouched and blocks[i].position == positions[i] \
			and shape.size == sizes[i] and blocks[i].collision_layer == BLOCK_LAYER \
			and blocks[i].scale == Vector2.ONE
	t.check(untouched, "mountain wall: ready leaves every authored block untouched")
	var f := {"wall": wall}
	_done(f)

func test_same_seed_produces_identical_silhouette() -> void:
	var first := _fixture(9876)
	var second := _fixture(9876)
	var a: MountainWall = first.wall
	var b: MountainWall = second.wall
	t.check(_same_loops(a.outline_loops(), b.outline_loops()),
		"mountain wall: equal authored blocks and seed produce identical loops")
	_done(first)
	_done(second)

func test_pines_fill_the_snow_cap_without_exceeding_the_cap() -> void:
	var f := _fixture()
	var wall: MountainWall = f.wall
	var points := wall.pine_points()
	var snow := wall.snow_loops()
	var solids := wall.solid_loops()
	var all_inside := true
	var has_deep_pine := false
	for point: Vector2 in points:
		all_inside = all_inside and _point_in_loops(point, snow)
		var far_from_open_edges := true
		for loop: PackedVector2Array in solids:
			for i in loop.size():
				var a: Vector2 = loop[i]
				var b: Vector2 = loop[(i + 1) % loop.size()]
				var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
				far_from_open_edges = far_from_open_edges \
					and point.distance_to(closest) > 120.0
		has_deep_pine = has_deep_pine or far_from_open_edges
	t.check(has_deep_pine,
		"mountain wall: the snow-cap grid places at least one deep-interior pine")
	t.check(all_inside, "mountain wall: every pine lies inside the snow cap")
	t.check(points.size() <= MountainWallScript.MAX_PINES,
		"mountain wall: pine count respects MAX_PINES")
	_done(f)

func test_real_scale_mountain_draws_completely() -> void:
	var f := _real_scale_fixture()
	var wall: MountainWall = f.wall
	var snow := wall.snow_loops()
	var paint := wall.outline_loops()
	var bases := wall.base_rim_loops()
	var solids := wall.solid_loops()
	var snow_valid := not snow.is_empty()
	for loop: PackedVector2Array in snow:
		snow_valid = snow_valid and not Geometry2D.triangulate_polygon(loop).is_empty()
	var paint_valid := not paint.is_empty()
	for loop: PackedVector2Array in paint:
		paint_valid = paint_valid and not Geometry2D.triangulate_polygon(loop).is_empty()
	var organic := paint.size() == bases.size() and not paint.is_empty()
	for i in mini(paint.size(), bases.size()):
		organic = organic and paint[i].size() > bases[i].size()
	var pines := wall.pine_points()
	var pines_valid := not pines.is_empty()
	for point: Vector2 in pines:
		pines_valid = pines_valid and _point_in_loops(point, snow)
	var chamfers := wall.chamfer_triangles()
	var chamfers_valid := chamfers.size() == 13
	for triangle: PackedVector2Array in chamfers:
		for point: Vector2 in triangle:
			var world := wall.to_global(point)
			chamfers_valid = chamfers_valid \
				and not is_equal_approx(world.x, wall.bounds.position.x) \
				and not is_equal_approx(world.y, wall.bounds.position.y)
	var open_band := true
	var west_snow := false
	for loop: PackedVector2Array in snow:
		for point: Vector2 in loop:
			open_band = open_band and _distance_to_open_boundary(
				point, wall, solids) >= wall.face_width - 1.0
			west_snow = west_snow \
				or wall.to_global(point).x < wall.bounds.position.x
	t.check(snow_valid, "mountain wall: real-scale snow loops all triangulate")
	t.check(paint_valid, "mountain wall: real-scale paint loops all triangulate")
	t.check(organic, "mountain wall: real-scale rim retains inserted organic vertices")
	t.check(pines_valid, "mountain wall: real-scale pines exist inside the snow cap")
	t.check(chamfers_valid,
		"mountain wall: real-scale staircase has 13 open-side chamfers")
	t.check(open_band, "mountain wall: real-scale open sides retain the full rock band")
	t.check(west_snow, "mountain wall: real-scale snow extends past the closed west bound")
	_done(f)

func _radar_body(parent: Node, at: Vector2, body_size: Vector2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body

func test_radar_dual_layer_body_is_bound_and_solid() -> void:
	var arena := Node2D.new()
	t.root.add_child(arena)
	t.current_scene = arena
	_radar_body(arena, Vector2(500, 0), Vector2(1000, 20), 2)
	_radar_body(arena, Vector2(500, 1000), Vector2(1000, 20), 2)
	_radar_body(arena, Vector2(0, 500), Vector2(20, 1000), 2)
	var layer_two_wall := _radar_body(arena, Vector2(1000, 500), Vector2(20, 1000), 2)
	var mountain_block := _radar_body(arena, Vector2(500, 500), BLOCK_SIZE, BLOCK_LAYER)
	var radar = RadarScript.new()
	arena.add_child(radar)
	radar._scan()
	var expected_bounds := Rect2(-10, -10, 1020, 1020)
	var mountain_rect := Rect2(mountain_block.global_position - BLOCK_SIZE * 0.5, BLOCK_SIZE)
	var found_mountain := false
	var found_wall := false
	for solid_v: Variant in radar._solids:
		var solid: Dictionary = solid_v
		found_mountain = found_mountain or solid.rect == mountain_rect
		var wall_rect := Rect2(layer_two_wall.global_position - Vector2(10, 500),
			Vector2(20, 1000))
		found_wall = found_wall or solid.rect == wall_rect
	t.check(radar._bounds == expected_bounds,
		"radar: dual-layer block preserves the four authored walls' arena bounds")
	t.check(found_mountain, "radar: dual-layer mountain block is appended to solids")
	t.check(not found_wall, "radar: layer-2-only boundary stays out of solids")
	t.current_scene = null
	t.root.remove_child(arena)
	arena.free()
