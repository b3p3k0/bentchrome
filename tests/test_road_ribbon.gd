extends RefCounted
## The organic street painter: build_quads produces one full-width quad per
## segment, closed rings wrap the last segment back to the start, degenerate
## points are skipped, and the node itself stays pure paint (no collision).

const RibbonScript := preload("res://environment/road_ribbon.gd")

var t

func _init(runner) -> void:
	t = runner

func test_open_polyline_quads() -> void:
	var line := PackedVector2Array([Vector2.ZERO, Vector2(200, 0), Vector2(200, 200)])
	var quads: Array = RibbonScript.build_quads(line, 100.0, false)
	t.check(quads.size() == 2, "ribbon: open 3-point line yields two segment quads")
	var q: PackedVector2Array = quads[0]
	t.check(q.size() == 4, "ribbon: segments are quads")
	t.check_approx(q[0].distance_to(q[3]), 100.0, "ribbon: quad spans the full width")
	t.check_approx((q[1] - q[0]).length(), 200.0, "ribbon: quad runs the segment length")

func test_closed_ring_wraps() -> void:
	var square := PackedVector2Array([
		Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)])
	var open_quads: Array = RibbonScript.build_quads(square, 64.0, false)
	var ring_quads: Array = RibbonScript.build_quads(square, 64.0, true)
	t.check(open_quads.size() == 3 and ring_quads.size() == 4,
		"ribbon: closing the ring adds the wrap segment")
	var wrap: PackedVector2Array = ring_quads[3]
	t.check_approx((wrap[1] - wrap[0]).length(), 200.0,
		"ribbon: wrap segment joins last point back to first")

func test_degenerate_points_skipped() -> void:
	var line := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(100, 0)])
	var quads: Array = RibbonScript.build_quads(line, 50.0, false)
	t.check(quads.size() == 1, "ribbon: duplicate points never build zero-length quads")
	t.check(RibbonScript.build_quads(PackedVector2Array([Vector2.ONE]), 50.0, false).is_empty(),
		"ribbon: a single point paints nothing")

func test_node_is_pure_paint() -> void:
	var ribbon: Node2D = RibbonScript.new()
	ribbon.points = PackedVector2Array([Vector2.ZERO, Vector2(300, 100)])
	t.root.add_child(ribbon)
	t.check(not (ribbon is CollisionObject2D),
		"ribbon: paint only — AI feelers and cars never see it")
	t.root.remove_child(ribbon)
	ribbon.free()
