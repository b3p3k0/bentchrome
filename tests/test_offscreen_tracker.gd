extends RefCounted
## Edge tracker geometry plus live roster cleanup. The paint is screen-space;
## these tests lock the play-square contract without requiring a visible window.

const TrackerScript := preload("res://ui/offscreen_tracker.gd")
const RadarScript := preload("res://ui/radar.gd")

var t

class StubCar extends Node2D:
	signal combat_hit(attacker: Node2D)
	var hp := 100.0
	var body_color := Color(0.2, 0.6, 0.9)
	func get_hp() -> float:
		return hp
	func present_hit(attacker: Node2D) -> void:
		combat_hit.emit(attacker)

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

func test_radar_roster_is_mapwide_live_and_paint_matched() -> void:
	var viewer := StubCar.new()
	viewer.add_to_group(&"local_player")
	viewer.add_to_group(&"vehicles")
	var far_human := StubCar.new()
	far_human.position = Vector2(50000.0, -50000.0)
	far_human.body_color = Color(0.05, 0.12, 0.2)
	far_human.add_to_group(&"player")
	far_human.add_to_group(&"vehicles")
	var dead_ai := StubCar.new()
	dead_ai.hp = 0.0
	dead_ai.add_to_group(&"enemies")
	dead_ai.add_to_group(&"vehicles")
	t.root.add_child(viewer)
	t.root.add_child(far_human)
	t.root.add_child(dead_ai)
	var opponents: Array = RadarScript.opponents(t.root.get_tree(), viewer)
	t.check(far_human in opponents,
		"radar: far human combatant stays visible without faction or range gate")
	t.check(viewer not in opponents and dead_ai not in opponents,
		"radar: viewer and destroyed combatants stay off the opponent layer")
	t.check(RadarScript.blip_color(far_human) == TrackerScript.marker_color(far_human),
		"radar: blip and offscreen marker share the exact vehicle paint")
	t.check(RadarScript.blip_outline(far_human)
		== TrackerScript.contrast_outline(far_human.body_color),
		"radar: dark paint shares the offscreen contrast outline")
	t.root.remove_child(dead_ai)
	t.root.remove_child(far_human)
	t.root.remove_child(viewer)
	dead_ai.free()
	far_human.free()
	viewer.free()

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

func test_personal_hit_burst_filters_and_rate_limits() -> void:
	var viewer := StubCar.new()
	viewer.position = TrackerScript.PLAY_RECT.get_center()
	viewer.add_to_group(&"local_player")
	viewer.add_to_group(&"vehicles")
	var other := StubCar.new()
	other.add_to_group(&"vehicles")
	var enemy := StubCar.new()
	enemy.position = Vector2(1400, 360)
	enemy.add_to_group(&"vehicles")
	var tracker = TrackerScript.new()
	t.root.add_child(viewer)
	t.root.add_child(other)
	t.root.add_child(enemy)
	t.root.add_child(tracker)
	tracker._process(0.0)
	enemy.present_hit(other)
	t.check(tracker.get_node_or_null("HitBurst") == null,
		"hit cue: somebody else's hit stays quiet")
	enemy.present_hit(viewer)
	var burst = tracker.get_node_or_null("HitBurst")
	t.check(burst != null, "hit cue: local hit on tracked enemy bursts")
	if burst:
		t.check(is_equal_approx(float(burst.size_scale), TrackerScript.HIT_BURST_SCALE),
			"hit cue: explosion reuses the small HUD scale")
		t.check(not burst.allow_camera_shake and not burst.allow_night_light,
			"hit cue: screen-space explosion cannot shake or bloom the world")
		t.check(burst.ring_only, "hit cue: nonfatal confirmation uses outer ring only")
		var debris := false
		for child in burst.get_children():
			if child is CPUParticles2D:
				debris = true
		t.check(not debris, "hit cue: nonfatal confirmation creates no debris")
	var before := tracker.get_child_count()
	enemy.present_hit(viewer)
	t.check(tracker.get_child_count() == before, "hit cue: rapid repeats are rate-limited")
	# Fatal feedback must survive that same cooldown and restore the complete
	# miniature explosion; Health has already written hp=0 when combat_hit fires.
	enemy.hp = 0.0
	enemy.present_hit(viewer)
	var fatal = tracker.get_node_or_null("FatalHitBurst")
	t.check(fatal != null and not fatal.ring_only,
		"hit cue: fatal tracked hit bypasses cooldown with full burst")
	var fatal_debris := false
	if fatal:
		for child in fatal.get_children():
			if child is CPUParticles2D:
				fatal_debris = true
	t.check(fatal_debris, "hit cue: fatal confirmation keeps debris scatter")
	enemy.hp = 100.0
	enemy.position = TrackerScript.PLAY_RECT.get_center()
	tracker._process(0.0)
	tracker._last_burst_ms.clear()
	var before_onscreen := tracker.get_child_count()
	enemy.present_hit(viewer)
	t.check(tracker.get_child_count() == before_onscreen, "hit cue: onscreen victim gets no edge burst")
	t.root.remove_child(tracker)
	t.root.remove_child(enemy)
	t.root.remove_child(other)
	t.root.remove_child(viewer)
	tracker.free()
	enemy.free()
	other.free()
	viewer.free()
