extends RefCounted
## Edge tracker geometry plus live roster cleanup. The paint is screen-space;
## these tests lock the play-square contract without requiring a visible window.

const TrackerScript := preload("res://ui/offscreen_tracker.gd")

var t

class StubCar extends Node2D:
	var hp := 100.0
	var body_color := Color(0.2, 0.6, 0.9)
	func get_hp() -> float:
		return hp

func _init(runner) -> void:
	t = runner

func test_edge_intersections_cover_cardinals_and_corner() -> void:
	var r := TrackerScript.PLAY_RECT.grow(-TrackerScript.EDGE_INSET)
	var c := TrackerScript.PLAY_RECT.get_center()
	t.check(TrackerScript.edge_intersection(c, Vector2(1400, c.y), r).is_equal_approx(Vector2(r.end.x, c.y)),
		"tracker: east ray lands on right edge")
	t.check(TrackerScript.edge_intersection(c, Vector2(-200, c.y), r).is_equal_approx(Vector2(r.position.x, c.y)),
		"tracker: west ray lands on left edge")
	t.check(TrackerScript.edge_intersection(c, Vector2(c.x, -500), r).is_equal_approx(Vector2(c.x, r.position.y)),
		"tracker: north ray lands on top edge")
	var corner := TrackerScript.edge_intersection(c, Vector2(1500, -500), r)
	var on_edge := is_equal_approx(corner.x, r.position.x) or is_equal_approx(corner.x, r.end.x) \
		or is_equal_approx(corner.y, r.position.y) or is_equal_approx(corner.y, r.end.y)
	var in_bounds := corner.x >= r.position.x and corner.x <= r.end.x \
		and corner.y >= r.position.y and corner.y <= r.end.y
	t.check(on_edge and in_bounds, "tracker: diagonal ray stays on inset rim")

func test_canvas_transform_and_contrast() -> void:
	var canvas := Transform2D(0.0, Vector2(50, -20)).scaled(Vector2(0.5, 0.5))
	t.check(TrackerScript.world_to_screen(canvas, Vector2(200, 100)).is_equal_approx(canvas * Vector2(200, 100)),
		"tracker: world point follows active canvas transform")
	t.check(TrackerScript.contrast_outline(Color(0.05, 0.05, 0.05)).r > 0.8,
		"tracker: dark paint gets a light outline")
	t.check(TrackerScript.contrast_outline(Color(1.0, 0.9, 0.2)).r < 0.1,
		"tracker: bright paint gets a dark outline")

func test_overlap_spread_keeps_edge_and_order() -> void:
	var rect := TrackerScript.PLAY_RECT.grow(-TrackerScript.EDGE_INSET)
	var records := [
		{"pos": Vector2(rect.end.x, 350.0)},
		{"pos": Vector2(rect.end.x, 352.0)},
		{"pos": Vector2(rect.end.x, 354.0)},
	]
	TrackerScript.separate_overlaps(records, rect)
	t.check(absf(records[1].pos.y - records[0].pos.y) >= TrackerScript.MARKER_GAP - 0.01,
		"tracker: overlapping arrows separate along edge")
	t.check(records[0].pos.x == rect.end.x and records[2].pos.x == rect.end.x,
		"tracker: separation never enters gutter")
	t.check(records[0].pos.y < records[1].pos.y and records[1].pos.y < records[2].pos.y,
		"tracker: bearing order survives separation")

func test_live_roster_hides_onscreen_and_cleans_dead() -> void:
	var viewer := StubCar.new()
	viewer.position = TrackerScript.PLAY_RECT.get_center()
	viewer.add_to_group(&"local_player")
	viewer.add_to_group(&"vehicles")
	var enemy := StubCar.new()
	enemy.position = Vector2(1400, 360)
	enemy.add_to_group(&"vehicles")
	var tracker = TrackerScript.new()
	t.root.add_child(viewer)
	t.root.add_child(enemy)
	t.root.add_child(tracker)
	tracker._process(0.0)
	t.check(tracker.is_tracking(enemy), "tracker: offscreen live combatant earns marker")
	enemy.position = TrackerScript.PLAY_RECT.get_center()
	tracker._process(0.0)
	t.check(not tracker.is_tracking(enemy), "tracker: onscreen combatant hides after hysteresis")
	enemy.position = Vector2(1400, 360)
	enemy.hp = 0.0
	tracker._process(0.0)
	t.check(not tracker.is_tracking(enemy), "tracker: dead combatant state is removed")
	t.root.remove_child(tracker)
	t.root.remove_child(enemy)
	t.root.remove_child(viewer)
	tracker.free()
	enemy.free()
	viewer.free()
