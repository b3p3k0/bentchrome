extends RefCounted
## Terraced-floor core. Locks the load-bearing contract: legacy (-1) mask math
## is bit-for-bit today's values, zones adopt, driving past a lower seam ledge-
## hops, 2+ floor landings bill fall damage, the size cue never touches the
## collision radius, and respawn resets to legacy for re-adoption.

const Floors := preload("res://game/floors.gd")
const VehicleScene := preload("res://vehicles/vehicle.tscn")
const FloorZoneScene := preload("res://environment/floor_zone.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_mask_math_legacy_is_bit_for_bit() -> void:
	t.check(Floors.ground_layer(-1) == 1, "floors: legacy layer is exactly 1")
	t.check(Floors.ground_mask(-1) == 7, "floors: legacy mask is exactly 7")
	t.check(Floors.projectile_mask(-1, false) == 7, "floors: legacy straight shot mask 7")
	t.check(Floors.projectile_mask(-1, true) == 7, "floors: legacy tracking shot mask 7")
	t.check(Floors.los_mask(-1) == 7, "floors: legacy LoS mask 7")

func test_mask_math_floor_mode() -> void:
	t.check(Floors.floor_bit(1) == 8 and Floors.floor_bit(2) == 16 and Floors.floor_bit(3) == 32,
		"floors: floor bits are 8/16/32")
	t.check(Floors.ground_layer(2) == (1 | 16), "floors: floor-2 layer keeps the ground bit")
	t.check(Floors.ground_mask(2) == (2 | 16), "floors: floor-2 mask = wall + own floor")
	t.check(Floors.projectile_mask(2, false) == (2 | 16), "floors: straight shot never signals cross-floor cars")
	t.check(Floors.projectile_mask(2, true) == (1 | 2 | 16), "floors: untargeted tracking shot respects launch cover")
	t.check(Floors.projectile_mask(1, true, 3) == (1 | 2 | 8 | 32),
		"floors: tracking shot respects endpoint cover and arcs over the middle")
	t.check(Floors.projectile_mask(1, true, 3, true) == (1 | 2),
		"floors: explicit cover piercing remains boundary-only")
	t.check(Floors.los_mask(3) == (1 | 2 | 32), "floors: LoS blocks on own-floor statics")

func test_same_floor_duck_typing() -> void:
	var a := Node.new()
	var b := Node.new()
	t.check(Floors.floor_of(a) == -1, "floors: plain node reads as legacy")
	t.check(Floors.same_floor(a, b), "floors: legacy participants never gate")
	a.free()
	b.free()

func _fixture(zones: Array) -> Dictionary:
	# zones: [{floor, pos, size}] — abutting rects, pit_zone fixture pattern.
	var container := Node2D.new()
	t.root.add_child(container)
	for z in zones:
		var zone = FloorZoneScene.instantiate()
		zone.floor_index = z.floor
		zone.size = z.size
		zone.position = z.pos
		container.add_child(zone)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0) — inside the first zone by convention
	return {"container": container, "car": car}

func _done(f: Dictionary) -> void:
	t.root.remove_child(f.container)
	f.container.free()

func _settle(frames: int) -> void:
	for i in frames:
		await t.physics_frame

func test_adopt_and_one_floor_drop_is_free() -> void:
	var f := _fixture([
		{"floor": 2, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.floor_index == 2, "floors: car adopts the zone under it")
	t.check(f.car.collision_layer == (1 | 16), "floors: adopted layer applied")
	t.check(f.car.collision_mask == (2 | 16), "floors: adopted mask applied")
	f.car.global_position = Vector2(900, 0)  # past the seam, over floor 1
	await _settle(3)
	t.check(f.car.height > 0.0 or f.car.vz > 0.0, "floors: lower seam ledge-hops airborne")
	await _settle(60)  # DROP_POP_VZ 240 lands in ~0.4s
	t.check(f.car.height == 0.0, "floors: ledge hop lands")
	t.check(f.car.floor_index == 1, "floors: landing adopts the lower floor")
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "floors: one-floor drop is free")
	_done(f)

func test_two_floor_fall_bills_max_hp_fraction() -> void:
	var f := _fixture([
		{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.floor_index == 3, "floors: car adopts the roof")
	f.car.global_position = Vector2(900, 0)
	await _settle(90)  # two-floor pop (~480 vz) needs the longer arc
	t.check(f.car.floor_index == 1, "floors: two-floor drop lands on floor 1")
	var health = f.car.get_node("Health")
	var expected: float = health.max_hp * (1.0 - f.car.fall_damage_frac)
	t.check(absf(health.hp - expected) < 0.5,
		"floors: 2-floor fall costs fall_damage_frac of max HP (hp %.1f, want %.1f)" % [health.hp, expected])
	_done(f)

func test_size_cue_never_touches_the_radius() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	var col: CollisionShape2D = f.car.get_node("CollisionShape2D")
	var radius_before: float = (col.shape as CircleShape2D).radius
	await _settle(30)  # adoption + the 0.25s scale tween
	var vis: Node2D = f.car.get_node("Visual")
	var want: float = f.car.body_scale * float(Floors.VISUAL_SCALE[3])
	t.check(absf(vis.scale.x - want) < 0.01, "floors: roof size cue reaches the visual")
	var radius_after: float = ((f.car.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	t.check(is_equal_approx(radius_before, radius_after), "floors: collision radius untouched by the cue")
	_done(f)

func test_draw_order_tracks_floor_and_air() -> void:
	var f := _fixture([
		{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 1, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(3)
	t.check(f.car.z_index == 2, "floors: roof car draws above overhead paint (z 2)")
	f.car.global_position = Vector2(900, 0)
	await _settle(3)
	t.check(f.car.z_index == 2, "floors: mid-drop stays above (airborne z 2)")
	await _settle(90)
	t.check(f.car.z_index == 0, "floors: landed low car returns to z 0")
	f.car.respawn(Vector2(900, 0), 0.0, 0.0)
	t.check(f.car.z_index == 0, "floors: respawn resets draw order")
	_done(f)

func test_respawn_resets_to_legacy_then_readopts() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	await _settle(30)
	t.check(f.car.floor_index == 3, "floors: pre-respawn adoption")
	f.car.respawn(Vector2.ZERO, 0.0, 0.0)
	t.check(f.car.floor_index == -1, "floors: respawn resets to legacy")
	var vis: Node2D = f.car.get_node("Visual")
	t.check(is_equal_approx(vis.scale.x, f.car.body_scale), "floors: respawn resets the size cue")
	await _settle(3)
	t.check(f.car.floor_index == 3, "floors: respawned car re-adopts from the sensor")
	_done(f)

func test_jump_pad_launches_only_its_own_terrace() -> void:
	var f := _fixture([{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)}])
	await _settle(3)  # car adopts the roof
	var pad = load("res://environment/jump_pad.gd").new()
	pad.floor_index = 2
	f.container.add_child(pad)
	f.car.velocity = Vector2(300, 0)
	pad._on_body_entered(f.car)
	t.check(f.car.vz == 0.0, "floors: a street jump pad ignores roof wheels")
	pad.floor_index = 3
	pad._on_body_entered(f.car)
	t.check(f.car.vz > 0.0, "floors: the same-terrace jump pad launches")
	_done(f)

func test_driveable_ramp_grades_both_ways() -> void:
	var f := _fixture([{"floor": 2, "pos": Vector2.ZERO, "size": Vector2(900, 900)}])
	var ramp = load("res://environment/ramp.gd").new()
	ramp.low_floor = 2
	ramp.high_floor = 3
	ramp.size = Vector2(200, 400)
	ramp.rotation = PI / 2  # high end points +x
	ramp.position = Vector2(600, 0)
	f.container.add_child(ramp)
	await _settle(3)
	t.check(f.car.floor_index == 2, "ramp: car starts on the plate")
	f.car.global_position = Vector2(500, 0)  # low half
	await _settle(3)
	t.check(f.car.floor_index == 2 and f.car.height == 0.0, "ramp: low half stays low, grounded")
	f.car.global_position = Vector2(700, 0)  # high half
	await _settle(3)
	t.check(f.car.floor_index == 3, "ramp: climbs to the high floor at grade")
	t.check(f.car.height == 0.0 and f.car.vz == 0.0, "ramp: no hop on the climb")
	var health = f.car.get_node("Health")
	t.check(health.hp >= health.max_hp, "ramp: grading costs nothing")
	f.car.global_position = Vector2(500, 0)  # back down the slope
	await _settle(3)
	t.check(f.car.floor_index == 2 and f.car.height == 0.0, "ramp: descends at grade too")
	# Side exit: from the high half straight onto the plain plate = ledge hop.
	f.car.global_position = Vector2(700, 0)
	await _settle(3)
	f.car.global_position = Vector2(0, 0)
	await _settle(3)
	t.check(f.car.height > 0.0 or f.car.vz > 0.0, "ramp: off the side is a real drop")
	await _settle(60)
	t.check(f.car.floor_index == 2 and f.car.height == 0.0, "ramp: side drop lands on the plate")
	_done(f)

func test_ramp_node_builds_the_recipe() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var ramp = load("res://environment/ramp.gd").new()
	ramp.low_floor = 2
	ramp.high_floor = 3
	container.add_child(ramp)
	var zones := 0
	var rails := 0
	for child in ramp.get_children():
		if child is Area2D and bool(child.get("ramp")):
			zones += 1
			t.check(int(child.floor_index) in [2, 3], "ramp node: half tags a real floor")
		elif child is StaticBody2D:
			rails += 1
			t.check(child.collision_layer == (4 | 16 | 32),
				"ramp node: rail blocks both terraces (got %d)" % child.collision_layer)
			var col: CollisionShape2D = child.get_child(0)
			t.check(is_equal_approx((col.shape as RectangleShape2D).size.y, ramp.size.y),
				"ramp node: rail runs the full slope (chokepoint)")
	t.check(zones == 2, "ramp node: two ramp-flagged halves (got %d)" % zones)
	t.check(rails == 2, "ramp node: two side rails (got %d)" % rails)
	t.root.remove_child(container)
	container.free()

func test_corner_grade_and_solid_chamfer_recipes() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var corner := CornerRamp.new()
	corner.low_floor = 2
	corner.high_floor = 3
	corner.leg_size = 240.0
	corner.terrain_type = "snow"
	container.add_child(corner)
	var zones: Array[FloorZone] = []
	for child in corner.get_children():
		if child is FloorZone:
			zones.append(child)
	t.check(zones.size() == 2, "corner grade: high and low ramp polygons exist")
	t.check(corner.high_polygon().size() == 3 and corner.low_polygon().size() == 4,
		"corner grade: triangle splits into high triangle and low trapezoid")
	t.check(corner.footprint()[0] == Vector2.ZERO
			and corner.footprint()[1] == Vector2(240, 0)
			and corner.footprint()[2] == Vector2(0, 240),
		"corner grade: right-angle vertex is high and hypotenuse is low")
	var terrain := corner.get_node_or_null(^"TerrainOverride/Terrain") as TerrainZone
	t.check(terrain != null and terrain.terrain_type == &"snow"
			and terrain.terrain_priority == Ramp.TERRAIN_PRIORITY,
		"corner grade: authored terrain owns the triangular slope")
	t.check(CornerRamp.downhill_vector(0.0).is_equal_approx(Vector2(1, 1).normalized()),
		"corner grade: pull runs high vertex to hypotenuse midpoint")

	var chamfer := TerraceChamfer.new()
	chamfer.low_floor = 1
	chamfer.high_floor = 2
	chamfer.leg_size = 384.0
	container.add_child(chamfer)
	t.check(chamfer.collision_layer == (4 | 8 | 16),
		"terrace chamfer: solid carries obstacle plus both floor bits")
	var col := chamfer.get_node_or_null(^"Col") as CollisionPolygon2D
	t.check(col != null and col.polygon == PackedVector2Array([
		Vector2.ZERO, Vector2(0, -384), Vector2(384, 0)]),
		"terrace chamfer: reusable collision matches the Coliseum right triangle")
	t.root.remove_child(container)
	container.free()

func test_corner_grade_transitions_without_a_hop() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var plate := FloorZoneScene.instantiate() as FloorZone
	plate.floor_index = 2
	plate.size = Vector2(1000, 1000)
	container.add_child(plate)
	var corner := CornerRamp.new()
	corner.low_floor = 2
	corner.high_floor = 3
	corner.leg_size = 240.0
	container.add_child(corner)
	var car := VehicleScene.instantiate() as Vehicle
	car.position = Vector2(160, 40)  # low trapezoid (x+y > half leg)
	container.add_child(car)
	await _settle(3)
	t.check(car.floor_index == 2 and car.height == 0.0,
		"corner grade: low hypotenuse side stays grounded on the low floor")
	car.global_position = Vector2(20, 20)  # high triangle
	await _settle(3)
	t.check(car.floor_index == 3 and car.height == 0.0 and car.vz == 0.0,
		"corner grade: diagonal climb adopts high floor without a hop")
	car.global_position = Vector2(160, 40)
	await _settle(3)
	t.check(car.floor_index == 2 and car.height == 0.0 and car.vz == 0.0,
		"corner grade: diagonal descent returns low without fall physics")
	t.root.remove_child(container)
	container.free()

func test_grade_visual_floor_queries_all_faces() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var ramp := Ramp.new()
	ramp.size = Vector2(200, 240)
	ramp.low_floor = 2
	ramp.high_floor = 3
	container.add_child(ramp)
	t.check_approx(ramp.visual_floor_at(Vector2(0, 120)), 2.0,
		"grade visual: cardinal low edge is floor 2")
	t.check_approx(ramp.visual_floor_at(Vector2.ZERO), 2.5,
		"grade visual: cardinal midpoint is fractional")
	t.check_approx(ramp.visual_floor_at(Vector2(0, -120)), 3.0,
		"grade visual: cardinal high edge is floor 3")
	t.check(ramp.visual_floor_at(Vector2(140, 0)) == -INF,
		"grade visual: cardinal outside returns invalid")
	ramp.stairs = true
	t.check(ramp.visual_floor_at(Vector2.ZERO) == -INF,
		"grade visual: Coliseum stairs retain stepped presentation")

	for rot in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var corner := CornerRamp.new()
		corner.position = Vector2(400 + rot * 10.0, 0)
		corner.rotation = rot
		corner.leg_size = 120.0
		container.add_child(corner)
		t.check_approx(corner.visual_floor_at(corner.to_global(Vector2.ZERO)), 3.0,
			"grade visual: rotated corner high vertex %.2f" % rot)
		t.check_approx(corner.visual_floor_at(corner.to_global(Vector2(30, 30))), 2.5,
			"grade visual: rotated corner midpoint %.2f" % rot)
		t.check_approx(corner.visual_floor_at(corner.to_global(Vector2(60, 60))), 2.0,
			"grade visual: rotated corner hypotenuse %.2f" % rot)
	t.root.remove_child(container)
	container.free()

func test_vehicle_and_puppet_rise_cosmetically_across_grade() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var ramp := Ramp.new()
	ramp.size = Vector2(200, 240)
	ramp.low_floor = 2
	ramp.high_floor = 3
	container.add_child(ramp)
	var car := VehicleScene.instantiate() as Vehicle
	container.add_child(car)
	car._cache_grade_visuals()
	var col := car.get_node(^"CollisionShape2D") as CollisionShape2D
	var radius_before := (col.shape as CircleShape2D).radius
	var visual := car.get_node(^"Visual") as Node2D
	var shadow := car.get_node(^"Shadow") as Node2D

	car.global_position = Vector2(0, 120)
	car._paint_depth()
	t.check(absf(visual.position.y) < 0.01 and absf(shadow.position.y) < 0.01,
		"grade visual: low wheels and tight shadow stay at baseline")
	car.global_position = Vector2.ZERO
	car._paint_depth()
	t.check(absf(visual.position.y + 16.0) < 0.01
			and absf(shadow.position.y + 16.0) < 0.01,
		"grade visual: car and shadow rise continuously at midpoint")
	t.check(absf(visual.scale.x - car.body_scale * 1.03) < 0.01,
		"grade visual: existing size cue interpolates at midpoint")
	car.global_position = Vector2(0, -120)
	car._paint_depth()
	t.check(absf(visual.position.y + 32.0) < 0.01,
		"grade visual: high edge reaches the authored terrace lift")
	t.check(is_equal_approx((col.shape as CircleShape2D).radius, radius_before),
		"grade visual: cosmetic rise never scales the physics body")

	car.set_net_puppet(true)
	car.global_position = Vector2.ZERO
	car._puppet_physics(0.0)
	t.check(absf(visual.position.y + 16.0) < 0.01,
		"grade visual: network puppet derives the same midpoint lift locally")
	car.set_net_puppet(false)
	car._floor_lift = 32.0
	car.global_position = Vector2(500, 500)
	car._paint_depth()
	t.check(absf(visual.position.y + 32.0) < 0.01,
		"grade visual: leaving a grade reconciles to the discrete floor state")
	t.root.remove_child(container)
	container.free()

func test_floor_lift_reads_elevation() -> void:
	var f := _fixture([
		{"floor": 3, "pos": Vector2.ZERO, "size": Vector2(600, 600)},
		{"floor": 2, "pos": Vector2(900, 0), "size": Vector2(600, 600)},
	])
	await _settle(30)  # adoption + the lift tween
	var vis: Node2D = f.car.get_node("Visual")
	t.check(absf(vis.position.y + 32.0) < 1.0,
		"lift: roof car body rides 32px up (y=%.1f)" % vis.position.y)
	var shadow: Node2D = f.car.get_node("Shadow")
	t.check(absf(shadow.position.y + 32.0) < 1.0,
		"lift: the shadow rides the terrace with the car (y=%.1f)" % shadow.position.y)
	t.check(shadow.modulate.a > 0.95,
		"lift: a grounded roof car keeps a tight full shadow (a=%.2f)" % shadow.modulate.a)
	f.car.global_position = Vector2(900, 0)  # one-floor drop back to baseline
	await _settle(90)
	t.check(absf(vis.position.y) < 1.0,
		"lift: floor-2 car sits at street level (y=%.1f)" % vis.position.y)
	_done(f)

func test_overhead_structures_fade_for_underpassers() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var bridge = load("res://levels/dock_deco.gd").new()
	bridge.kind = &"bridge"
	bridge.size = Vector2(300, 200)
	bridge.z_index = 1
	container.add_child(bridge)
	var car = VehicleScene.instantiate()
	container.add_child(car)  # (0,0): under the deck, grounded legacy = z 0
	await _settle(12)  # overlap registers + fade eases in
	t.check(bridge.modulate.a < 0.6, "underpass: deck fades while a car is beneath (a=%.2f)" % bridge.modulate.a)
	car.global_position = Vector2(2000, 0)
	await _settle(30)
	t.check(bridge.modulate.a > 0.9, "underpass: deck recovers once clear (a=%.2f)" % bridge.modulate.a)
	_done({"container": container, "car": car})

func test_no_zones_stays_legacy() -> void:
	var f := _fixture([])
	await _settle(3)
	t.check(f.car.floor_index == -1, "floors: zone-free level stays legacy")
	t.check(f.car.collision_mask == 7, "floors: zone-free mask stays 7")
	t.check(f.car.collision_layer == 1, "floors: zone-free layer stays 1")
	_done(f)
