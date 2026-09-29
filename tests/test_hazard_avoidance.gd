extends RefCounted
## Lethal-hazard awareness: the geometry service (game/hazards.gd) that turns
## the &"lethal_hazards" group into queryable world rects, and the EnemyDriver
## behaviors built on it. The zones themselves are unraycastable (layer 0) —
## these tests lock the substitute senses that keep AI out of the Potomac.

const Hazards := preload("res://game/hazards.gd")
const AiNoGoScript := preload("res://environment/ai_no_go.gd")
const WaterScene := preload("res://environment/deep_water_zone.tscn")
const PitScene := preload("res://environment/pit_zone.tscn")
const DriverScript := preload("res://vehicles/drivers/enemy_driver.gd")
const EnemyScene := preload("res://vehicles/enemy_vehicle.tscn")
const VehicleScene := preload("res://vehicles/vehicle.tscn")

var t

## Minimal stand-in for guard/detour logic tests (test_enemy_driver pattern,
## plus `height` so the airborne exemption is exercised).
class FakeCar extends Node2D:
	var hpf := 1.0
	var heading := 0.0
	var height := 0.0
	var real_velocity := Vector2.ZERO
	var speed := 240.0
	var hops: Array = []  # escape_hop directions received
	var last_attacker: Node2D = null
	var last_attacker_ms := 0
	func get_hp_fraction() -> float:
		return hpf
	func get_hp() -> float:
		return hpf * 100.0
	func get_real_velocity() -> Vector2:
		return real_velocity
	func get_speed() -> float:
		return speed
	func escape_hop(dir: Vector2) -> void:
		hops.append(dir)

func _init(runner) -> void:
	t = runner

func _water(container: Node2D, pos: Vector2, size: Vector2) -> Node:
	Hazards.rects(t)  # flush a same-frame fixture swap before restoring the same group count
	var zone = WaterScene.instantiate()
	zone.size = size
	zone.position = pos
	container.add_child(zone)
	return zone

## Capital-shaped river: three tall rects, gapped where the bridges live.
## Gap bands: y -160..160 (Memorial) and y 960..1280 (14th St).
func _river(container: Node2D) -> void:
	_water(container, Vector2(0, -1040), Vector2(384, 1760))
	_water(container, Vector2(0, 560), Vector2(384, 800))
	_water(container, Vector2(0, 1600), Vector2(384, 640))

func test_registry_rects_and_cache() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(100, 200), Vector2(300, 400))
	var pit = PitScene.instantiate()
	pit.size = Vector2(256, 128)
	pit.position = Vector2(-500, 0)
	container.add_child(pit)
	var rects := Hazards.rects(t)
	t.check(rects.size() == 2, "hazards: both zone flavors join the registry")
	var found_water := false
	for r in rects:
		if r.is_equal_approx(Rect2(-50, 0, 300, 400)):
			found_water = true
	t.check(found_water, "hazards: rect matches painted center+size extents")
	# Membership change invalidates the cache without waiting for a new frame.
	_water(container, Vector2(900, 900), Vector2(64, 64))
	t.check(Hazards.rects(t).size() == 3, "hazards: cache rebuilds on group count change")
	t.root.remove_child(container)
	container.free()
	t.check(Hazards.rects(t).is_empty(), "hazards: empty tree yields empty registry")

func test_ai_no_go_registers_without_hurting_a_grounded_vehicle() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var no_go := AiNoGoScript.new() as Node2D
	no_go.position = Vector2(120, -80)
	no_go.set("size", Vector2(384, 384))
	container.add_child(no_go)
	t.check(not no_go is CollisionObject2D and no_go.get_child_count() == 0,
		"ai no-go: remains a collisionless Node2D with no child shapes")
	var car: Vehicle = VehicleScene.instantiate()
	car.faction = &"enemies"
	car.global_position = no_go.global_position
	var died := [false]
	var health := car.get_node(^"Health") as Health
	health.died.connect(func() -> void: died[0] = true)
	container.add_child(car)
	var found := false
	for rect: Rect2 in Hazards.rects(t):
		found = found or rect == Rect2(-72, -272, 384, 384)
	t.check(found, "ai no-go: exported center and size appear in Hazards.rects()")
	for _frame in 55:
		await t.physics_frame
	t.check(is_instance_valid(car) and not bool(died[0]) and health.hp > 0.0
			and not bool(car.get("_falling")) and car.height == 0.0,
		"ai no-go: a grounded vehicle inside remains alive and does not fall")
	t.root.remove_child(container)
	container.free()

func test_guard_fires_for_ai_no_go() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var no_go := AiNoGoScript.new() as Node2D
	no_go.set("size", Vector2(384, 384))
	container.add_child(no_go)
	var car := _guarded_car(container, Vector2(-332, 0), Vector2(500, 0), 0.0)
	var driver: Variant = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(driver._guard_active and absf(float(intent["steer"])) > 0.9,
		"ai no-go: guard fires for a FakeCar driving at the rect")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_segment_geometry() -> void:
	var rect := Rect2(-100, -100, 200, 200)
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(300, 0)) < 1.0,
		"hazards: crossing segment reports an entry")
	var entry_t := Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(300, 0))
	t.check(absf(entry_t - 0.3333) < 0.01, "hazards: entry fraction lands on the near face")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 200), Vector2(300, 200)) > 1.0,
		"hazards: parallel segment outside the slab is clear")
	t.check(Hazards.segment_entry_t(rect, Vector2(0, 0), Vector2(300, 0)) == 0.0,
		"hazards: starting inside reports entry 0")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 130), Vector2(300, 130), 50.0) < 1.0,
		"hazards: margin grows the blocking slab")
	t.check(Hazards.segment_entry_t(rect, Vector2(-300, 0), Vector2(-150, 0)) > 1.0,
		"hazards: segment ending short of the rect is clear")

func test_entry_axis_reports_the_face() -> void:
	var rect := Rect2(-100, -100, 200, 200)
	t.check(Hazards.segment_entry_axis(rect, Vector2(-300, 0), Vector2(300, 0)) == 0,
		"hazards: west-face entry reports a Y-running rim")
	t.check(Hazards.segment_entry_axis(rect, Vector2(0, -300), Vector2(0, 300)) == 1,
		"hazards: north-face entry reports an X-running rim")
	t.check(Hazards.segment_entry_axis(rect, Vector2(-300, 200), Vector2(300, 200)) == -1,
		"hazards: a miss has no entry face")
	t.check(Hazards.segment_entry_axis(rect, Vector2.ZERO, Vector2(300, 0)) == -1,
		"hazards: a segment starting inside has no entry face")

func _escape_path_safe(from: Vector2, dir: Vector2, reach: float) -> bool:
	if dir == Vector2.ZERO:
		return false
	var endpoint := from + dir * reach
	for rect: Rect2 in Hazards.rects(t):
		var grown := rect.grow(Hazards.GUARD_MARGIN)
		if grown.has_point(endpoint):
			return false
		if grown.has_point(from):
			var band_depth := Hazards.GUARD_MARGIN + Hazards.KILL_INSET + 0.01
			if grown.has_point(from + dir * band_depth):
				return false
		elif Hazards.segment_entry_t(rect, from, endpoint, Hazards.GUARD_MARGIN) \
				< Hazards.CLEAR:
			return false
	return true

func test_escape_direction_leaves_forgiveness_band() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2.ZERO, Vector2(600, 300))
	var from := Vector2(0, -160)
	var result := Hazards.escape_direction(t, from, Vector2.UP, 280.0)
	t.check(result == Vector2.UP,
		"escape: a requested direction out of the forgiveness band stays outward")
	t.root.remove_child(container)
	container.free()

func test_escape_direction_never_enters_from_forgiveness_band() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2.ZERO, Vector2(600, 300))
	var from := Vector2(0, -160)
	var result := Hazards.escape_direction(t, from, Vector2.DOWN, 280.0)
	t.check(result.dot(Vector2.UP) >= 0.0,
		"escape: a band escape has no component into the void")
	t.check(_escape_path_safe(from, result, 280.0),
		"escape: the band escape leaves promptly and lands outside the pit")
	t.root.remove_child(container)
	container.free()

func test_escape_direction_handles_overlapping_corner_bands() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2.ZERO, Vector2(600, 300))
	_water(container, Vector2(450, -450), Vector2(300, 600))
	var from := Vector2(290, -160)
	var left_result := Vector2.ZERO
	for requested in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
		var result := Hazards.escape_direction(t, from, requested, 700.0)
		if result != Vector2.ZERO:
			t.check(_escape_path_safe(from, result, 700.0),
				"escape corner: every offered direction clears both bands promptly")
		if requested == Vector2.LEFT:
			left_result = result
	t.check(left_result.dot(Vector2.LEFT) > 0.0 and left_result.dot(Vector2.UP) > 0.0,
		"escape corner: a left request finds the open up-left route")
	t.root.remove_child(container)
	container.free()

func test_escape_direction_uses_entered_face() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2.ZERO, Vector2(1200, 200))
	var result := Hazards.escape_direction(t, Vector2(-700, 0), Vector2.RIGHT, 450.0)
	t.check(absf(result.dot(Vector2.RIGHT)) < 0.001 and absf(result.y) > 0.9,
		"escape: a wide rect deflects along the entered west face, not its long axis")
	t.root.remove_child(container)
	container.free()

func test_boxed_escape_skips_hop_and_unsticks() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(200, 0), Vector2(100, 400))
	_water(container, Vector2(-200, 0), Vector2(100, 400))
	_water(container, Vector2(0, 200), Vector2(400, 100))
	_water(container, Vector2(0, -200), Vector2(400, 100))
	var car := _guarded_car(container, Vector2.ZERO, Vector2.ZERO, 0.0)
	var target := FakeCar.new()
	container.add_child(target)
	target.global_position = Vector2(500, 0)
	t.check(Hazards.escape_direction(t, car.global_position, Vector2.RIGHT,
		DriverScript.ESCAPE_HOP_RANGE) == Vector2.ZERO,
		"escape: a four-sided box reports no safe landing")
	var driver = DriverScript.new()
	driver._on_stuck(car, target, 0.0)
	var intent: Dictionary = driver._on_stuck(car, target, 0.0)
	t.check(car.hops.is_empty(), "hop: no safe landing skips the airborne escape")
	t.check(driver._mode == DriverScript.Mode.UNSTICK and float(intent["throttle"]) < 0.0,
		"hop: a boxed rival falls through to the ordinary reverse-out")
	t.check(driver._hop_cd == 0.0 and driver._pin_repeats == 2,
		"hop: a skipped landing preserves cooldown and repeat state")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_escape_direction_unchanged_without_hazards() -> void:
	var requested := Vector2(3, -4)
	t.check(Hazards.escape_direction(t, Vector2(20, 30), requested, 280.0) == requested,
		"escape: a hazard-free tree returns the requested direction unchanged")

func test_segment_hit_first_blocker() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(400, 0), Vector2(200, 200))   # far
	_water(container, Vector2(-400, 0), Vector2(200, 200))  # near for a west start
	var rects := Hazards.rects(t)
	var idx := Hazards.segment_hit(t, Vector2(-900, 0), Vector2(900, 0))
	t.check(idx >= 0 and rects[idx].get_center().x < 0.0,
		"hazards: segment_hit returns the FIRST rect along the travel")
	t.check(Hazards.segment_blocked(t, Vector2(-900, 0), Vector2(900, 0)),
		"hazards: blocked convenience agrees")
	t.check(not Hazards.segment_blocked(t, Vector2(-900, 300), Vector2(900, 300)),
		"hazards: clear lane between rects stays clear")
	t.check(Hazards.point_inside(t, Vector2(-400, 90)),
		"hazards: point_inside sees the interior")
	t.check(not Hazards.point_inside(t, Vector2(-400, 110)),
		"hazards: point just past the rim is outside unmargined")
	t.check(Hazards.point_inside(t, Vector2(-400, 110), 20.0),
		"hazards: margin extends point_inside")
	t.root.remove_child(container)
	container.free()

func test_detour_candidates_find_bridge_gaps() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	# East-bank car hunting a west-bank target straight through the middle rect.
	var from := Vector2(600, 560)
	var to := Vector2(-600, 560)
	var cands := Hazards.detour_candidates(t, from, to)
	t.check(cands.size() == 2, "detour: middle river rect offers both ends")
	for c in cands:
		var p: Vector2 = c["point"]
		var in_memorial: bool = p.y > -160.0 and p.y < 160.0
		var in_14th: bool = p.y > 960.0 and p.y < 1280.0
		t.check(in_memorial or in_14th,
			"detour: candidate lands inside a bridge gap band (y=%.0f)" % p.y)
		t.check((c["normal"] as Vector2).is_equal_approx(Vector2(1, 0)),
			"detour: normal points back to the approach side")
	t.check(Hazards.detour_candidates(t, Vector2(600, 0), Vector2(-600, 0)).is_empty(),
		"detour: the bridge lane itself is clear — no candidates offered")
	t.root.remove_child(container)
	container.free()

func test_detour_orders_clear_approach_first() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_water(container, Vector2(0, -600), Vector2(300, 800))  # y -1000..-200
	# Near the rect's north end: rounding north is clear, rounding south drags
	# the whole flank. Ordering must put the clear approach first.
	var cands := Hazards.detour_candidates(t, Vector2(600, -980), Vector2(-600, -980))
	t.check(cands.size() == 2, "detour: lone rect offers both ends")
	t.check(bool(cands[0]["clear_from"]) and not bool(cands[1]["clear_from"]),
		"detour: clear-approach candidate sorts first")
	t.check((cands[0]["point"] as Vector2).y < -1000.0,
		"detour: the clear candidate rounds the near end")
	t.root.remove_child(container)
	container.free()

func test_detour_filters_chained_neighbor_end() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	# Two rects nearly abutting: the shared end is NOT a gap and must drop.
	_water(container, Vector2(0, -600), Vector2(300, 800))  # y -1000..-200
	_water(container, Vector2(0, 300), Vector2(300, 800))   # y -100..700
	var cands := Hazards.detour_candidates(t, Vector2(600, -600), Vector2(-600, -600))
	t.check(cands.size() == 1, "detour: the end poking into the neighbor is filtered")
	t.check((cands[0]["point"] as Vector2).y < -1000.0,
		"detour: the surviving candidate rounds the open end")
	t.root.remove_child(container)
	container.free()

func _guarded_car(container: Node2D, pos: Vector2, vel: Vector2, heading: float) -> FakeCar:
	var car := FakeCar.new()
	container.add_child(car)
	car.global_position = pos
	car.real_velocity = vel
	car.heading = heading
	return car

func _steered_aim(car: FakeCar, intent: Dictionary) -> Vector2:
	var aimed_heading := car.heading + float(intent["steer"]) * PI * 0.5
	return Vector2.RIGHT.rotated(aimed_heading)

func _check_guard_west_face(size: Vector2, label: String) -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pit: Variant = PitScene.instantiate()
	pit.size = size
	container.add_child(pit)
	var car := _guarded_car(container, Vector2(-size.x * 0.5 - 140.0, 0),
		Vector2(500, 0), 0.0)
	var driver: Variant = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(driver._guard_active, "%s: guard fires" % label)
	var aim := _steered_aim(car, intent)
	t.check(absf(aim.y) > absf(aim.x), "%s: steer turns along Y, not into the pit" % label)
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_short_face_of_wide_rect() -> void:
	_check_guard_west_face(Vector2(896, 128), "guard wide west face")

func test_guard_square_rect_west_face() -> void:
	_check_guard_west_face(Vector2(128, 128), "guard square west face")

func test_guard_pushes_out_through_nearest_face() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pit: Variant = PitScene.instantiate()
	pit.size = Vector2(896, 128)
	container.add_child(pit)
	var car := _guarded_car(container, Vector2(-458, 0), Vector2(500, 0), PI * 0.5)
	var driver: Variant = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(driver._guard_active, "guard forgiveness band: guard fires")
	var aim := _steered_aim(car, intent)
	t.check(aim.x < 0.0, "guard forgiveness band: nearest west face pushes west")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_axis_change_follows_travel_not_stale_slide() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var pit: Variant = PitScene.instantiate()
	pit.size = Vector2(896, 128)
	container.add_child(pit)
	var velocity := Vector2(-300, 300)
	var car := _guarded_car(container, Vector2(0, -200), velocity, velocity.angle())
	var driver: Variant = DriverScript.new()
	driver._guard_active = true
	driver._guard_tangent = Vector2.DOWN
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(driver._guard_active, "guard axis change: guard fires")
	var aim := _steered_aim(car, intent)
	t.check(aim.x < 0.0, "guard axis change: current travel keeps the slide west")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_overrides_toward_rim_tangent() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var car := _guarded_car(container, Vector2(600, 560), Vector2(-500, 0), PI)
	var driver = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "fire_mg": true, "boost": true})
	t.check(driver._guard_active, "guard: lookahead into the river fires")
	t.check(absf(float(intent["steer"])) > 0.9,
		"guard: steering overridden hard toward the rim tangent")
	t.check(float(intent["throttle"]) < 0.5,
		"guard: throttle staged down inside the reaction envelope")
	t.check(intent["boost"] == false, "guard: boost vetoed")
	t.check(intent["fire_mg"] == true, "guard: fire flags untouched")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_exemptions() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	# Airborne sails over: intent passes through untouched.
	var car := _guarded_car(container, Vector2(600, 560), Vector2(-500, 0), PI)
	car.height = 500.0
	var driver = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(not driver._guard_active and intent["boost"] == true and float(intent["steer"]) == 0.0,
		"guard: airborne cars pass through untouched")
	# The bridge lane: rim-parallel travel through the gap stays silent.
	var runner := _guarded_car(container, Vector2(600, 0), Vector2(-500, 0), PI)
	intent = driver._apply_hazard_guard(runner,
		{"throttle": 1.0, "steer": 0.0, "boost": true})
	t.check(not driver._guard_active and intent["boost"] == true,
		"guard: the gap lane is legally driveable")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_silent_without_zones() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var car := _guarded_car(container, Vector2.ZERO, Vector2(400, 0), 0.0)
	var driver = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": 1.0, "steer": 0.25, "boost": true})
	t.check(not driver._guard_active and float(intent["steer"]) == 0.25 and intent["boost"] == true,
		"guard: zone-free levels are byte-identical")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_guard_stops_a_reverse_into_water() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	# Backing west toward the rim, nose east: stop the reverse, keep the steer
	# (UNSTICK's sign-flipped swing must not be fought), kill boost.
	var car := _guarded_car(container, Vector2(600, 560), Vector2(-400, 0), 0.0)
	var driver = DriverScript.new()
	var intent: Dictionary = driver._apply_hazard_guard(car,
		{"throttle": -1.0, "steer": 0.7, "boost": false})
	t.check(driver._guard_active, "guard: reverse lookahead rides real travel")
	t.check(float(intent["throttle"]) == 0.0, "guard: the reverse stops short of the rim")
	t.check(float(intent["steer"]) == 0.7, "guard: reversing steer left alone")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_escape_hop_deflects_off_the_water() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var car := _guarded_car(container, Vector2(300, 560), Vector2.ZERO, PI)
	var target := FakeCar.new()
	container.add_child(target)
	target.global_position = Vector2(-600, 560)  # straight across the channel
	var driver = DriverScript.new()
	driver._on_stuck(car, target, 0.0)  # first pin: reverse-out
	driver._on_stuck(car, target, 0.0)  # second same-spot pin: the hop
	t.check(car.hops.size() == 1, "hop: second pin still hops with water ahead")
	var landing: Vector2 = car.global_position + (car.hops[0] as Vector2) * DriverScript.ESCAPE_HOP_RANGE
	t.check(not Hazards.point_inside(t, landing, 0.0),
		"hop: deflected landing is on dry land (was a ballistic drowning)")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_break_exit_never_lands_in_water() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var car := _guarded_car(container, Vector2(600, 560), Vector2.ZERO, PI)
	var target := FakeCar.new()
	container.add_child(target)
	target.global_position = Vector2(350, 560)  # close, rim at its back
	var driver = DriverScript.new()
	driver._enter_break(car, target)
	t.check(driver._break_exit != Vector2.INF, "break: exit committed")
	t.check(not Hazards.point_inside(t, driver._break_exit, 0.0),
		"break: drive-by exit validated onto dry land")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_target_score_pays_across_the_river() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var hunter := _guarded_car(container, Vector2(600, 560), Vector2.ZERO, PI)
	hunter.add_to_group(&"vehicles")
	var near_bank := FakeCar.new()
	container.add_child(near_bank)
	near_bank.global_position = Vector2(600, -100)  # same side, 660 away
	near_bank.add_to_group(&"vehicles")
	var far_bank := FakeCar.new()
	container.add_child(far_bank)
	far_bank.global_position = Vector2(-60, 560)  # across, 660 away
	far_bank.add_to_group(&"vehicles")
	var driver = DriverScript.new()
	var near_score: float = driver._target_score(hunter, near_bank)
	var far_score: float = driver._target_score(hunter, far_bank)
	t.check(near_score > far_score, "score: the same-bank fight wins the tie")
	t.check(far_score > -INF, "score: across the river is a penalty, never a veto")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_detour_two_phase_run() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var car := _guarded_car(container, Vector2(600, 560), Vector2.ZERO, PI)
	car.add_to_group(&"vehicles")
	var target := FakeCar.new()
	container.add_child(target)
	target.global_position = Vector2(-600, 560)
	target.add_to_group(&"vehicles")
	var driver = DriverScript.new()
	var intent: Dictionary = driver._detour_gate(car, target, Vector2.ZERO, 0.1)
	t.check(driver._mode == DriverScript.Mode.DETOUR, "detour: blocked beeline enters DETOUR")
	t.check(not intent.is_empty() and float(intent["throttle"]) > 0.0,
		"detour: a driving intent comes back")
	t.check(intent["fire_mg"] == false and intent["fire_selected"] == false,
		"detour: guns stay quiet on the crossing")
	t.check(not Hazards.point_inside(t, driver._detour_entry, 0.0)
		and not Hazards.point_inside(t, driver._detour_exit, 0.0),
		"detour: both bridgeheads sit on dry land")
	t.check(driver._detour_entry.x > 0.0 and driver._detour_exit.x < 0.0,
		"detour: bridgeheads straddle the water")
	car.global_position = driver._detour_entry
	driver._detour_gate(car, target, Vector2.ZERO, 0.1)
	t.check(driver._detour_phase == 1, "detour: entry arrival commits the exit leg")
	car.global_position = driver._detour_exit
	var out: Dictionary = driver._detour_gate(car, target, Vector2.ZERO, 0.1)
	t.check(driver._mode == DriverScript.Mode.PURSUE and out.is_empty(),
		"detour: exit arrival hands back to the ladder same-tick")
	driver.free()
	t.root.remove_child(container)
	container.free()

func test_detour_times_out_to_pursue() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_river(container)
	var car := _guarded_car(container, Vector2(600, 560), Vector2.ZERO, PI)
	var target := FakeCar.new()
	container.add_child(target)
	target.global_position = Vector2(-600, 560)
	var driver = DriverScript.new()
	driver._detour_gate(car, target, Vector2.ZERO, 0.1)
	t.check(driver._mode == DriverScript.Mode.DETOUR, "detour: entered for the timeout probe")
	driver._detour_t = 0.05
	var out: Dictionary = driver._detour_gate(car, target, Vector2.ZERO, 0.1)
	t.check(driver._mode == DriverScript.Mode.PURSUE and out.is_empty(),
		"detour: timeout abandons the route, never parks")
	driver.free()
	t.root.remove_child(container)
	container.free()

func _wall(container: Node2D, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos
	container.add_child(body)

## The anti-suicide integration lock the suite never had: a REAL enemy
## vehicle, a wall-to-wall water column with one 320px gap, and a prey across
## it. A drowning bot passed every prior test; this one it cannot.
func test_live_rival_survives_a_cross_water_hunt() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	_wall(container, Vector2(0, -1132), Vector2(3400, 64))
	_wall(container, Vector2(0, 1132), Vector2(3400, 64))
	_wall(container, Vector2(-1732, 0), Vector2(64, 2264))
	_wall(container, Vector2(1732, 0), Vector2(64, 2264))
	# Column spans wall to wall in y; the one gap (y -180..140) is the bridge.
	_water(container, Vector2(0, -640), Vector2(384, 920))
	_water(container, Vector2(0, 620), Vector2(384, 960))
	var enemy = EnemyScene.instantiate()
	enemy.position = Vector2(900, 700)
	container.add_child(enemy)
	enemy.set_stats(load("res://data/vehicles/hammertoe.tres"))
	enemy.get_node("Driver").mix = Vector3(1, 0, 0)
	enemy.get_node("Health").invulnerable = true
	var prey := FakeCar.new()
	container.add_child(prey)
	prey.global_position = Vector2(-900, 700)
	prey.add_to_group(&"vehicles")
	prey.add_to_group(&"player")
	var start: Vector2 = enemy.global_position
	for i in 480:
		await t.physics_frame
	var alive: bool = is_instance_valid(enemy) and enemy.get_hp() > 0.0
	t.check(alive, "sim: the hunter never sank")
	if alive:
		var moved: float = enemy.global_position.distance_to(start)
		var gap: float = enemy.global_position.distance_to(prey.global_position)
		t.check(not Hazards.point_inside(t, enemy.global_position, 0.0),
			"sim: final position is dry land")
		t.check(moved > 300.0, "sim: perpetual motion held (moved %.0fpx)" % moved)
		# Start gap is 1800px with the water between; anything under half means
		# the hunter genuinely crossed at the bridge and closed on the prey.
		t.check(gap < 900.0, "sim: crossed the water and closed the gap (%.0fpx left)" % gap)
		print("    [sim] hunter at %s after 8s (prey across the gap at %s)"
			% [enemy.global_position.round(), prey.global_position.round()])
	t.root.remove_child(container)
	container.free()
