extends RefCounted
## MountainWall and DropField contract: deterministic union skins around
## untouched authored gameplay geometry, with boundary bleed and valid bands.

const MountainWallScript := preload("res://environment/mountain_wall.gd")
const DropFieldScript := preload("res://environment/drop_field.gd")
const PitScene := preload("res://environment/pit_zone.tscn")
const PitPaint := preload("res://environment/pit_zone.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const RadarScript := preload("res://ui/radar.gd")

const BLOCK_SIZE := Vector2(256, 256)
const BLOCK_LAYER := 54

# Captured from MountainWall before the union-skin helper extraction. Hashing
# var_to_str locks every returned point and loop boundary without burying this
# suite under hundreds of literal Vector2 values.
const PRE_REFACTOR_GEOMETRY := {
	"staircase": {
		"solid": "557add46ce75043b442273be03e3d9ba51b22785971eb7fe8efa4c0679fd3fc5",
		"base_rim": "3be698ea38ffc0d052c195a4835a38afd795e5d0a939d19313b6a2f0af528b7f",
		"outline": "dd7589c58a87c0760b4f87be56da3119a8148eaf8bd01ba25c1189d630afd0b4",
		"snow": "778568990f99c0c70dea3432e41b4d152be53c0fef2d971dbbc3ae1a84bea8d6",
		"chamfers": "02ee7b28eb0009606a5118af8afdbe4bc1feb0f6f2cc3b816fec72643815e969",
		"pines": "8128679620f0938a1993e7b425f1ec7c86230d04cba42b82ef8a80ed4967f3f4",
	},
	"real_scale": {
		"solid": "1304d365f0b354405924eb84f73f9dddbb83bd3369f3e6fac41cff12d3f17434",
		"base_rim": "fc4025b7ef5ce866829dd1b4fd4c314b1633c04f0e6d1441113fe0ed6a3f3bf0",
		"outline": "d163e9c3ff7853a4d68a1a2e5da84205e1389aad30e2b2e1490362adeeac7ee6",
		"snow": "1204209ea75e4c809a548541ba05d32a6bad6d573595f2c06477888d27864388",
		"chamfers": "9ebafee6d73025bdfc57a04da78662d13d79a6333daebc1d47d890c2b141ec8a",
		"pines": "0d38239e39d0f8acf00c265d9eb33c39a2aee5054315cc4277235d117618147d",
	},
}

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

func _pit(parent: DropField, name: String, rect: Rect2,
		paint := false) -> Area2D:
	var pit := PitScene.instantiate() as Area2D
	pit.name = name
	pit.position = rect.get_center()
	pit.set("size", rect.size)
	pit.set("paint", paint)
	parent.add_child(pit)
	return pit

func _drop_fixture(abutting := false, closed_east := false,
		seed := 173, painted_index := -1) -> Dictionary:
	var field := DropFieldScript.new() as DropField
	field.position = Vector2(137, 211)
	field.paint_seed = seed
	var rects: Array[Rect2] = []
	if abutting:
		rects = [
			Rect2(768, -512, 768, 256), Rect2(512, -256, 1024, 256),
			Rect2(256, 0, 1280, 256),
		]
	else:
		rects = [
			Rect2(768, -512, 768, 320), Rect2(512, -256, 1024, 320),
			Rect2(256, 0, 1280, 320),
		]
	var pits: Array[Area2D] = []
	for i in rects.size():
		pits.append(_pit(field, "Pit%d" % i, rects[i], i == painted_index))
	if closed_east:
		field.bounds = Rect2(field.position + Vector2(-4096, -4096),
			Vector2(4096 + 1536, 8192))
	t.root.add_child(field)
	return {"field": field, "pits": pits, "rects": rects}

func _real_scale_drop() -> Dictionary:
	var field := DropFieldScript.new() as DropField
	field.position = Vector2(-321, 147)
	field.paint_seed = 173
	field.bounds = Rect2(field.position + Vector2(-4096, -4096),
		Vector2(8192, 8192))
	var pits: Array[Area2D] = []
	for k in 14:
		var rect := Rect2(Vector2((4 + k) * 128, k * 128),
			Vector2(4096 - (4 + k) * 128, 192))
		pits.append(_pit(field, "Pit%d" % k, rect))
	t.root.add_child(field)
	return {"field": field, "pits": pits}

func _done_drop(fixture: Dictionary) -> void:
	var field: DropField = fixture.field
	if is_instance_valid(field):
		t.root.remove_child(field)
		field.free()

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

func _point_in_rect_union(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect: Rect2 in rects:
		if point.x >= rect.position.x - 0.01 and point.x <= rect.end.x + 0.01 \
				and point.y >= rect.position.y - 0.01 and point.y <= rect.end.y + 0.01:
			return true
	return false

func _has_closed_east_rim(field: DropField,
		segments: Array[PackedVector2Array]) -> bool:
	for segment: PackedVector2Array in segments:
		var a := field.to_global(segment[0])
		var b := field.to_global(segment[segment.size() - 1])
		if a.x > field.bounds.end.x and b.x > field.bounds.end.x \
				and absf(b.y - a.y) > absf(b.x - a.x):
			return true
	return false

func _has_closed_east_inset_detail(field: DropField,
		segments: Array[PackedVector2Array]) -> bool:
	for segment: PackedVector2Array in segments:
		var a := field.to_global(segment[0])
		var b := field.to_global(segment[segment.size() - 1])
		if a.x > field.bounds.end.x and b.x < a.x \
				and absf(b.x - a.x) > absf(b.y - a.y):
			return true
	return false

func _has_edge_on_world_x(field: DropField,
		loops: Array[PackedVector2Array], world_x: float) -> bool:
	for loop: PackedVector2Array in loops:
		for i in loop.size():
			var a := field.to_global(loop[i])
			var b := field.to_global(loop[(i + 1) % loop.size()])
			if is_equal_approx(a.x, world_x) and is_equal_approx(b.x, world_x):
				return true
	return false

func _same_loops(a: Array[PackedVector2Array], b: Array[PackedVector2Array]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

func _geometry_fingerprints(wall: MountainWall) -> Dictionary:
	return {
		"solid": var_to_str(wall.solid_loops()).sha256_text(),
		"base_rim": var_to_str(wall.base_rim_loops()).sha256_text(),
		"outline": var_to_str(wall.outline_loops()).sha256_text(),
		"snow": var_to_str(wall.snow_loops()).sha256_text(),
		"chamfers": var_to_str(wall.chamfer_triangles()).sha256_text(),
		"pines": var_to_str(wall.pine_points()).sha256_text(),
	}

func test_shared_geometry_refactor_preserves_exact_fixture_outputs() -> void:
	var staircase := _fixture()
	var real_scale := _real_scale_fixture()
	t.check(_geometry_fingerprints(staircase.wall) == PRE_REFACTOR_GEOMETRY.staircase,
		"mountain wall refactor: staircase geometry exactly matches the captured baseline")
	t.check(_geometry_fingerprints(real_scale.wall) == PRE_REFACTOR_GEOMETRY.real_scale,
		"mountain wall refactor: real-scale geometry exactly matches the captured baseline")
	_done(staircase)
	_done(real_scale)

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

func test_drop_staircase_builds_one_inward_organic_rim() -> void:
	var f := _drop_fixture()
	var field: DropField = f.field
	var outlines := field.outline_loops()
	var inside := outlines.size() == 1
	var near_edge := true
	for loop: PackedVector2Array in outlines:
		for point: Vector2 in loop:
			inside = inside and _point_in_rect_union(point, f.rects)
			near_edge = near_edge and _distance_to_loops(
				point, field.solid_loops()) <= 12.0 + 0.01
	t.check(outlines.size() == 1,
		"drop field: three overlapping bands paint as one continuous rim")
	var rects_match: bool = field.pit_rects().size() == f.rects.size()
	for i in f.rects.size():
		rects_match = rects_match and field.pit_rects()[i] == Rect2(
			f.rects[i].position + field.position, f.rects[i].size)
	t.check(field.position != Vector2.ZERO and rects_match,
		"drop field: non-zero root reports every authored pit rect in world space")
	t.check(inside, "drop field: every rim vertex stays inside or on the pit union")
	t.check(near_edge, "drop field: every rim vertex stays within 12px of the union edge")
	t.check(field.kill_gaps().is_empty(),
		"drop field: 64px band overlaps leave no uncovered kill samples")
	_done_drop(f)

func test_drop_abutting_bands_report_kill_gaps() -> void:
	var f := _drop_fixture(true)
	var field: DropField = f.field
	t.check(not field.kill_gaps().is_empty(),
		"drop field: abutting pits expose their 48px kill-shape seam")
	var warnings := field.validation_warnings()
	t.check(warnings.size() == 1 and "kill-gap" in warnings[0],
		"drop field: validation reports the abutting chain's uncovered gap")
	_done_drop(f)

func test_drop_validation_names_painted_pits_only() -> void:
	var good := _drop_fixture()
	var good_field: DropField = good.field
	t.check(good_field.validation_warnings().is_empty(),
		"drop field: a paintless overlapped chain validates cleanly")
	_done_drop(good)

	var painted := _drop_fixture(false, false, 173, 1)
	var painted_field: DropField = painted.field
	var warnings := painted_field.validation_warnings()
	t.check(warnings.size() == 1 and "Pit1" in warnings[0]
			and "paint = true" in warnings[0],
		"drop field: validation names each child that still paints itself")
	_done_drop(painted)

func test_drop_closed_east_side_bleeds_without_edge_details() -> void:
	var f := _drop_fixture(false, true)
	var field: DropField = f.field
	var farthest_east := -INF
	for loop: PackedVector2Array in field.outline_loops():
		for point: Vector2 in loop:
			farthest_east = maxf(farthest_east, field.to_global(point).x)
	t.check(farthest_east >= field.bounds.end.x + field.bleed - 0.01,
		"drop field: a closed east side bleeds at least bleed past the arena bound")
	t.check(not _has_closed_east_rim(field, field.rim_line_segments()),
		"drop field: the closed east side gets no hazard rim line")
	t.check(not _has_closed_east_inset_detail(field, field.face_striations()),
		"drop field: the closed east side gets no cliff-face striations")
	t.check(not _has_edge_on_world_x(field, field.face_loops(), field.bounds.end.x),
		"drop field: the closed east side gets no face-band edge")
	t.check(not _has_closed_east_inset_detail(field, field.crack_segments()),
		"drop field: the closed east side gets no crumbling cracks")
	_done_drop(f)

func test_drop_reuses_pit_zone_paint_contract() -> void:
	t.check(DropFieldScript.PitPaint == PitPaint
			and DropFieldScript.PinePaint == PitPaint.PinePaint,
		"drop field: chain and shipped pit share the same paint dependencies")
	t.check(DropFieldScript.RIM == PitPaint.RIM
			and DropFieldScript.SNOW_CAP == PitPaint.SNOW_CAP
			and DropFieldScript.CLIFF_FACE == PitPaint.CLIFF_FACE
			and DropFieldScript.OCCLUSION == PitPaint.OCCLUSION,
		"drop field: chain colors are the shipped pit's exact values")

func test_drop_same_seed_produces_identical_rim() -> void:
	var first := _drop_fixture(false, false, 9876)
	var second := _drop_fixture(false, false, 9876)
	t.check(_same_loops(first.field.outline_loops(), second.field.outline_loops()),
		"drop field: equal authored pits and seed produce identical rims")
	_done_drop(first)
	_done_drop(second)

func test_drop_ready_leaves_authored_pits_untouched_and_lethal() -> void:
	var container := Node2D.new()
	var field := DropFieldScript.new() as DropField
	field.position = Vector2(137, 211)
	var pit := _pit(field, "PitUntouched", Rect2(768, -512, 768, 320))
	var keep_position := pit.position
	var keep_size: Vector2 = pit.get("size")
	container.add_child(field)
	var car: Vehicle = VehicleScene.instantiate()
	car.faction = &"enemies"
	car.position = field.position + pit.position
	var died := [false]
	var health := car.get_node(^"Health") as Health
	health.died.connect(func() -> void: died[0] = true)
	container.add_child(car)
	t.root.add_child(container)
	t.check(pit.position == keep_position and pit.get("size") == keep_size
			and pit.is_in_group(&"lethal_hazards"),
		"drop field: ready preserves authored pit transform, size, and hazard group")
	for _frame in 55:
		await t.physics_frame
	t.check(bool(died[0]),
		"drop field: a grounded enemy still dies inside the untouched child pit")
	if is_instance_valid(container):
		t.root.remove_child(container)
		container.free()

func test_real_scale_drop_draws_one_valid_closed_edge_cliff() -> void:
	var f := _real_scale_drop()
	var field: DropField = f.field
	var solid := field.solid_loops()
	var rim := field.outline_loops()
	var void_regions := field.void_loops()
	var solid_valid := solid.size() == 1 \
		and not Geometry2D.triangulate_polygon(solid[0]).is_empty()
	var rim_valid := rim.size() == 1 \
		and not Geometry2D.triangulate_polygon(rim[0]).is_empty()
	var void_valid := not void_regions.is_empty()
	for loop: PackedVector2Array in void_regions:
		void_valid = void_valid and not Geometry2D.triangulate_polygon(loop).is_empty()
	var pines := field.pine_points()
	var pines_valid := not pines.is_empty()
	for point: Vector2 in pines:
		pines_valid = pines_valid and _point_in_loops(point, void_regions)
	t.check(solid_valid and rim_valid,
		"drop field: real-scale chain has one triangulating solid and rim")
	t.check(rim[0].size() > solid[0].size(),
		"drop field: real-scale rim retains inserted organic vertices")
	t.check(void_valid, "drop field: real-scale distant void exists and triangulates")
	t.check(pines_valid, "drop field: miniature pines exist inside the distant void")
	t.check(field.kill_gaps().is_empty(),
		"drop field: real-scale overlapping chain has no uncovered kill samples")
	t.check(not _has_closed_east_rim(field, field.rim_line_segments())
			and not _has_closed_east_inset_detail(field, field.face_striations())
			and not _has_closed_east_inset_detail(field, field.crack_segments())
			and not _has_edge_on_world_x(field, field.face_loops(), field.bounds.end.x),
		"drop field: real-scale closed east side draws no edge details")
	_done_drop(f)

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
