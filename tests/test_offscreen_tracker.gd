extends RefCounted
## Edge tracker geometry plus live roster cleanup. The paint is screen-space;
## these tests lock the play-square contract without requiring a visible window.

const TrackerScript := preload("res://ui/offscreen_tracker.gd")
const RadarScript := preload("res://ui/radar.gd")
const DesignatorScript := preload("res://game/target_designator.gd")
const EnemyDriverScript := preload("res://vehicles/drivers/enemy_driver.gd")

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

func test_marker_geometry_is_single_or_overlapping_vcr_pair() -> void:
	var pos := Vector2(900, 360)
	var angle := deg_to_rad(25.0)
	var axis := Vector2.RIGHT.rotated(angle)
	var single: Array = TrackerScript.marker_triangles(pos, angle, false)
	var pair: Array = TrackerScript.marker_triangles(pos, angle, true)
	t.check(single.size() == 1, "tracker geometry: ordinary marker is one triangle")
	t.check(pair.size() == 2, "tracker geometry: designation is a two-triangle VCR pair")
	var first: PackedVector2Array = pair[0]
	var second: PackedVector2Array = pair[1]
	var first_dir := (first[0] - (first[1] + first[2]) * 0.5).normalized()
	var second_dir := (second[0] - (second[1] + second[2]) * 0.5).normalized()
	t.check(first_dir.is_equal_approx(axis) and second_dir.is_equal_approx(axis),
		"tracker geometry: both designation triangles point toward the opponent")
	var first_center := (first[0] + first[1] + first[2]) / 3.0
	var second_center := (second[0] + second[1] + second[2]) / 3.0
	var separation: Vector2 = second_center - first_center
	t.check(is_equal_approx(separation.dot(axis), TrackerScript.TARGET_TRIANGLE_OFFSET)
		and absf(separation.dot(axis.orthogonal())) < 0.001,
		"tracker geometry: VCR pair offset follows only the marker axis")
	t.check(TrackerScript.TARGET_TRIANGLE_OFFSET < TrackerScript.TIP + TrackerScript.WING
		and not Geometry2D.intersect_polygons(first, second).is_empty(),
		"tracker geometry: rear and front triangles deliberately overlap")

func test_vcr_pair_stays_inside_play_rim() -> void:
	var inset := TrackerScript.PLAY_RECT.grow(-TrackerScript.EDGE_INSET)
	var center := TrackerScript.PLAY_RECT.get_center()
	for target in [Vector2(1500, center.y), Vector2(-500, center.y),
			Vector2(center.x, -500), Vector2(1500, -500)]:
		var pos := TrackerScript.edge_intersection(center, target, inset)
		var angle: float = (target - center).angle()
		for triangle_v in TrackerScript.marker_triangles(pos, angle, true):
			var triangle: PackedVector2Array = triangle_v
			for point in triangle:
				t.check(point.x >= TrackerScript.PLAY_RECT.position.x
					and point.x <= TrackerScript.PLAY_RECT.end.x
					and point.y >= TrackerScript.PLAY_RECT.position.y
					and point.y <= TrackerScript.PLAY_RECT.end.y,
					"tracker geometry: VCR triangle stays inside play rim")

func test_radar_roster_is_sensor_bounded_live_and_paint_matched() -> void:
	var viewer := StubCar.new()
	viewer.add_to_group(&"local_player")
	viewer.add_to_group(&"vehicles")
	var near_human := StubCar.new()
	near_human.position = Vector2(1500.0, 0.0)  # inside BASE_SENSOR_RANGE
	near_human.body_color = Color(0.05, 0.12, 0.2)
	near_human.add_to_group(&"player")
	near_human.add_to_group(&"vehicles")
	var far_human := StubCar.new()
	far_human.position = Vector2(50000.0, -50000.0)
	far_human.add_to_group(&"player")
	far_human.add_to_group(&"vehicles")
	var dead_ai := StubCar.new()
	dead_ai.hp = 0.0
	dead_ai.add_to_group(&"enemies")
	dead_ai.add_to_group(&"vehicles")
	t.root.add_child(viewer)
	t.root.add_child(near_human)
	t.root.add_child(far_human)
	t.root.add_child(dead_ai)
	var opponents: Array = RadarScript.opponents(t.root.get_tree(), viewer)
	t.check(near_human in opponents,
		"radar: near combatant paints regardless of faction")
	t.check(far_human not in opponents,
		"radar: combatants beyond sensor reach stay off the scope")
	t.check(viewer not in opponents and dead_ai not in opponents,
		"radar: viewer and destroyed combatants stay off the opponent layer")
	t.check(RadarScript.blip_color(near_human) == TrackerScript.marker_color(near_human),
		"radar: blip and offscreen marker share the exact vehicle paint")
	t.check(RadarScript.blip_outline(near_human)
		== TrackerScript.contrast_outline(near_human.body_color),
		"radar: dark paint shares the offscreen contrast outline")
	for car in [dead_ai, far_human, near_human, viewer]:
		t.root.remove_child(car)
		car.free()

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

func test_designation_decorates_only_existing_offscreen_record() -> void:
	var viewer := StubCar.new()
	viewer.position = TrackerScript.PLAY_RECT.get_center()
	viewer.add_to_group(&"local_player")
	viewer.add_to_group(&"vehicles")
	var driver = EnemyDriverScript.new()
	driver.name = "Driver"
	viewer.add_child(driver)
	var designator = DesignatorScript.new()
	designator.name = "TargetDesignator"
	viewer.add_child(designator)
	var marked := StubCar.new()
	marked.position = Vector2(1400, 360)
	marked.add_to_group(&"vehicles")
	var ordinary := StubCar.new()
	ordinary.position = Vector2(1400, 520)
	ordinary.add_to_group(&"vehicles")
	var onscreen := StubCar.new()
	onscreen.position = TrackerScript.PLAY_RECT.get_center() + Vector2(100, 0)
	onscreen.add_to_group(&"vehicles")
	var unsensed := StubCar.new()
	unsensed.position = Vector2(50000, -50000)
	unsensed.add_to_group(&"vehicles")
	var tracker = TrackerScript.new()
	for node in [viewer, marked, ordinary, onscreen, unsensed, tracker]:
		t.root.add_child(node)
	driver._adopt_target(marked)
	tracker._process(0.0)
	var marked_records: Array = tracker._draw_records.filter(
		func(rec: Dictionary) -> bool: return rec.ref == marked)
	var ordinary_records: Array = tracker._draw_records.filter(
		func(rec: Dictionary) -> bool: return rec.ref == ordinary)
	t.check(marked_records.size() == 1 and bool(marked_records[0].designated)
		and TrackerScript.marker_triangles(marked_records[0].pos,
			float(marked_records[0].angle), true).size() == 2,
		"tracker designation: sensed offscreen target gets one double-marker record")
	t.check(ordinary_records.size() == 1 and not bool(ordinary_records[0].designated)
		and TrackerScript.marker_triangles(ordinary_records[0].pos,
			float(ordinary_records[0].angle), false).size() == 1,
		"tracker designation: ordinary opponent keeps one triangle")
	driver._adopt_target(onscreen)
	tracker._process(0.0)
	t.check(not tracker.is_tracking(onscreen),
		"tracker designation: on-screen target gains no marker")
	driver._adopt_target(unsensed)
	tracker._process(0.0)
	t.check(not tracker.is_tracking(unsensed)
		and tracker._draw_records.all(func(rec: Dictionary) -> bool: return rec.ref != unsensed),
		"tracker designation: unsensed target gains no marker record")
	for node in [tracker, unsensed, onscreen, ordinary, marked, viewer]:
		t.root.remove_child(node)
		node.free()

## Sensor-range churn must never re-connect: leaving reach prunes the marker
## state, but the combat_hit connection's lifetime is the CAR's lifetime — a
## re-entering car keeps exactly one connection (regression: the old state
## flag was pruned with the state, spamming "already connected" per crossing).
func test_range_reentry_never_duplicates_hit_connection() -> void:
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
	t.check(enemy.get_signal_connection_list(&"combat_hit").size() == 1,
		"tracker: first sighting wires the hit confirm once")
	enemy.position = Vector2(50000, -50000)  # past sensor reach — state pruned
	tracker._process(0.0)
	t.check(not tracker.is_tracking(enemy), "tracker: out-of-reach car drops its marker")
	enemy.position = Vector2(1400, 360)  # back inside
	tracker._process(0.0)
	tracker._process(0.0)
	t.check(enemy.get_signal_connection_list(&"combat_hit").size() == 1,
		"tracker: re-entry never stacks a second connection")
	t.check(tracker.is_tracking(enemy), "tracker: re-entering car earns its marker back")
	for n in [tracker, enemy, viewer]:
		t.root.remove_child(n)
		n.free()

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
