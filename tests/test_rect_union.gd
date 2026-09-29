extends RefCounted
## Rect-union geometry contract: connected outlines, holes, corner-only contact,
## containment, and corner chamfering all remain pure static operations.

const RectUnion := preload("res://environment/rect_union.gd")

var t

func _init(runner) -> void:
	t = runner

func _same_points(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for point in a:
		if not b.has(point):
			return false
	return true

func _signed_area(loop: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in loop.size():
		twice_area += loop[i].cross(loop[(i + 1) % loop.size()])
	return twice_area * 0.5

func _is_input_feature(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		var corners := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
		if corners.has(point):
			return true
	for vertical in rects:
		var on_vertical := (point.x == vertical.position.x or point.x == vertical.end.x) \
			and point.y >= vertical.position.y and point.y <= vertical.end.y
		if not on_vertical:
			continue
		for horizontal in rects:
			var on_horizontal := (point.y == horizontal.position.y or point.y == horizontal.end.y) \
				and point.x >= horizontal.position.x and point.x <= horizontal.end.x
			if on_horizontal:
				return true
	return false

func test_one_rect_is_four_corners() -> void:
	var rects: Array[Rect2] = [Rect2(10, 20, 200, 100)]
	var loops := RectUnion.outline(rects)
	var expected := PackedVector2Array([
		Vector2(10, 20), Vector2(210, 20), Vector2(210, 120), Vector2(10, 120)])
	t.check(loops.size() == 1, "rect union: one rect has one loop")
	t.check(loops[0].size() == 4 and _same_points(loops[0], expected),
		"rect union: one rect is exactly its four corners")
	t.check(_signed_area(loops[0]) > 0.0,
		"rect union: one rect winds clockwise in screen space")

func test_abutting_rects_merge_to_rectangle() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(100, 0, 100, 100)]
	var loops := RectUnion.outline(rects)
	var expected := PackedVector2Array([
		Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(0, 100)])
	t.check(loops.size() == 1 and loops[0].size() == 4 and _same_points(loops[0], expected),
		"rect union: abutting rects merge into one four-point outline")

func test_overlapping_rects_match_abutting_union() -> void:
	var abutting: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(100, 0, 100, 100)]
	var overlapping: Array[Rect2] = [Rect2(0, 0, 132, 100), Rect2(68, 0, 132, 100)]
	var joined := RectUnion.outline(abutting)
	var overlapped := RectUnion.outline(overlapping)
	t.check(joined.size() == 1 and overlapped.size() == 1 \
		and _same_points(joined[0], overlapped[0]),
		"rect union: a 64px overlap has the same outline as an abutment")

func test_l_shape_has_six_points() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 200), Rect2(100, 100, 100, 100)]
	var loops := RectUnion.outline(rects)
	t.check(loops.size() == 1 and loops[0].size() == 6,
		"rect union: an L has one six-point outline")

func _staircase() -> Array[Rect2]:
	return [Rect2(0, 0, 200, 200), Rect2(100, 100, 200, 200),
		Rect2(200, 200, 200, 200)]

func test_staircase_has_only_input_features() -> void:
	var rects := _staircase()
	var loops := RectUnion.outline(rects)
	t.check(loops.size() == 1 and loops[0].size() == 12,
		"rect union: three-step staircase has one twelve-point outline")
	var features_only := true
	for point in loops[0]:
		features_only = features_only and _is_input_feature(point, rects)
	t.check(features_only, "rect union: staircase turns come only from input edge features")

func test_ring_returns_outer_and_hole_with_opposite_winding() -> void:
	var rects: Array[Rect2] = [
		Rect2(0, 0, 300, 100), Rect2(0, 200, 300, 100),
		Rect2(0, 100, 100, 100), Rect2(200, 100, 100, 100),
	]
	var loops := RectUnion.outline(rects)
	t.check(loops.size() == 2, "rect union: a ring has an outer loop and a hole")
	var first_area := _signed_area(loops[0])
	var second_area := _signed_area(loops[1])
	t.check(first_area * second_area < 0.0, "rect union: outer and hole wind oppositely")
	var outer_area := first_area if absf(first_area) > absf(second_area) else second_area
	var hole_area := second_area if absf(first_area) > absf(second_area) else first_area
	t.check(outer_area > 0.0 and hole_area < 0.0,
		"rect union: outer is clockwise and hole counter-clockwise in screen space")

func test_corner_touch_stays_two_loops() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(100, 100, 100, 100)]
	var loops := RectUnion.outline(rects)
	t.check(loops.size() == 2 and loops[0].size() == 4 and loops[1].size() == 4,
		"rect union: corner-only contact remains two four-point loops")

func test_empty_and_degenerate_inputs_are_empty() -> void:
	var empty: Array[Rect2] = []
	var zero: Array[Rect2] = [Rect2(0, 0, 0, 100)]
	var negative: Array[Rect2] = [Rect2(0, 0, -10, 100)]
	t.check(RectUnion.outline(empty).is_empty(), "rect union: empty input has no loops")
	t.check(RectUnion.outline(zero).is_empty() and RectUnion.outline(negative).is_empty(),
		"rect union: non-positive rects have no loops")

func test_contains_matches_brute_force_on_staircase_grid() -> void:
	var rects := _staircase()
	var agrees := true
	for y in range(-50, 451, 25):
		for x in range(-50, 451, 25):
			var point := Vector2(x, y)
			var brute := false
			for rect in rects:
				brute = brute or rect.has_point(point)
			agrees = agrees and RectUnion.contains(rects, point) == brute
	t.check(agrees, "rect union: contains agrees with brute force across staircase grid")

func test_chamfer_square_makes_eight_near_boundary_points() -> void:
	var square := PackedVector2Array([
		Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200)])
	var chamfered := RectUnion.chamfer(square, 20.0)
	t.check(chamfered.size() == 8, "rect union: chamfered square has eight points")
	var near_boundary := true
	var near_corner := true
	for point in chamfered:
		var edge_distance := INF
		var corner_distance := INF
		for i in square.size():
			edge_distance = minf(edge_distance, point.distance_to(
				Geometry2D.get_closest_point_to_segment(point, square[i],
					square[(i + 1) % square.size()])))
			corner_distance = minf(corner_distance, point.distance_to(square[i]))
		near_boundary = near_boundary and edge_distance <= 20.001
		near_corner = near_corner and corner_distance <= 20.001
	t.check(near_boundary and near_corner,
		"rect union: every chamfer point stays within cut of its source boundary")
