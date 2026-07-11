extends RefCounted
## The Coliseum structural contract, read off the instantiated (never tree-
## entered) scene like test_dock_level: the two-floor bowl topology holds
## (field plate under a floor-2 outer RIM ring; the grandstand slopes between
## them are Ramp-built zones, invisible here since the scene never enters the
## tree), the corner tunnel pockets stay open floor 1, every spawn's
## start_floor has a matching tag zone under it, grade routes run both
## directions with their approach runs on the right floor, and the jump pads
## stand clear of solid scenery. Batch B adds the Goliath checks.

var t

func _init(runner) -> void:
	t = runner

func _zone_rect(z: Node) -> Rect2:
	var size: Vector2 = z.get("size")
	return Rect2(z.position - size * 0.5, size)

func _body_rect(n: Node2D) -> Rect2:
	var size_v: Variant = n.get("size")
	if size_v is Vector2:
		return Rect2(n.position - (size_v as Vector2) * 0.5, size_v)
	var col := n.get_node_or_null(^"Col") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		return Rect2(n.position + col.position - col.shape.size * 0.5, col.shape.size)
	return Rect2()

## The grade is physical: coasting DOWN the stands retains more speed than
## coasting UP at the same entry speed (Ramp.downhill_pull — an environment-
## side force; controller gains and the feel bands stay untouched).
func test_grade_bias_reads_downhill() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var ramp := Ramp.new()
	ramp.low_floor = 1
	ramp.high_floor = 2
	ramp.size = Vector2(256, 800)
	ramp.rails = false
	ramp.surface_paint = false
	ramp.downhill_pull = 400.0
	container.add_child(ramp)
	var speeds: Array[float] = []
	for dir in [1.0, -1.0]:  # +y = downhill, -y = uphill (high end at -y)
		var car = preload("res://vehicles/vehicle.tscn").instantiate()
		container.add_child(car)
		car.global_position = Vector2(0, -dir * 250.0)
		car.heading = PI / 2.0 * dir  # nose along the travel line
		car.velocity = Vector2(0, dir * 300.0)
		for i in 25:
			await t.physics_frame
		speeds.append(car.velocity.length())
		container.remove_child(car)
		car.free()
	t.check(speeds[0] > speeds[1] + 60.0,
		"grade: downhill coast keeps speed, uphill bleeds it (%.0f vs %.0f)"
		% [speeds[0], speeds[1]])
	t.root.remove_child(container)
	container.free()

func test_stadium_structure() -> void:
	var scene: PackedScene = load("res://levels/stadium/stadium.tscn")
	var stadium: Node = scene.instantiate()

	var zones: Array = []      # {rect, floor, name}
	var connectors: Array = []
	var stations := 0
	var enemies: Array = []
	var player: Node2D = null
	for child in stadium.get_children():
		if child is Area2D and child.scene_file_path.ends_with("floor_zone.tscn"):
			zones.append({"rect": _zone_rect(child), "floor": int(child.floor_index),
				"name": String(child.name)})
		elif child.get("from_floor") != null:
			connectors.append(child)
		elif child.get("cooldown_seconds") != null:
			stations += 1
		elif child.name == "Vehicle":
			player = child
		elif str(child.name).begins_with("Enemy"):
			enemies.append(child)

	t.check(stations == 1, "stadium: boss arena earns one station (got %d)" % stations)
	t.check(zones.size() >= 5, "stadium: field plate + rim ring tagged (got %d zones)" % zones.size())

	# Bowl topology: exactly one floor-1 plate, and every floor-2 rim band
	# sits inside it (the ring never leaks past the field's footprint).
	var field := {}
	var rim_bands := 0
	for z in zones:
		if int(z.floor) == 1:
			t.check(field.is_empty(), "stadium: a single floor-1 field plate")
			field = z
		elif int(z.floor) == 2:
			rim_bands += 1
	t.check(not field.is_empty(), "stadium: the floor-1 field plate exists")
	t.check(rim_bands == 4, "stadium: four rim bands crown the bowl (got %d)" % rim_bands)
	if not field.is_empty():
		for z in zones:
			if int(z.floor) == 2:
				t.check((field.rect as Rect2).grow(2.0).encloses(z.rect),
					"stadium: %s sits inside the field plate" % z.name)

	# The chamfered corners: the crown ring runs CONTINUOUSLY — the corner
	# strips behind each 45° wall read floor 2, so a rim lap never dead-ends.
	for pc in [Vector2(1984, -1664), Vector2(2176, -1300), Vector2(-1984, -1664),
			Vector2(-2176, 1300), Vector2(1984, 1664), Vector2(-1984, 1664)]:
		var ring_floor := -1
		for z in zones:
			if (z.rect as Rect2).has_point(pc):
				ring_floor = maxi(ring_floor, int(z.floor))
		t.check(ring_floor == 2, "stadium: crown ring covers the corner at %s (got %d)"
			% [pc, ring_floor])

	# Four raised 45° chamfer walls cap the bleacher ends (floor-1 cars deflect
	# along them; rim cars dive off over them).
	var chamfers := 0
	for child in stadium.get_children():
		if String(child.name).begins_with("Chamfer") and child is StaticBody2D:
			chamfers += 1
			t.check((child as StaticBody2D).collision_layer == 12,
				"stadium: %s wears obstacle + floor-1 bits" % child.name)
	t.check(chamfers == 4, "stadium: four corner chamfers (got %d)" % chamfers)

	# Every spawn's start_floor has a matching tag zone under it (highest wins,
	# same rule as the sensor).
	var spawns: Array = enemies.duplicate()
	spawns.append(player)
	for s in spawns:
		var want := int(s.get("start_floor"))
		var best := -1
		for z in zones:
			if (z.rect as Rect2).has_point(s.position):
				best = maxi(best, int(z.floor))
		t.check(best == want, "stadium: %s start_floor %d matches the zone under it (zone says %d)"
			% [s.name, want, best])

	# Route completeness: up and down between field and seats, with grade
	# ramps on all four sides plus lip drop-offs.
	var pairs := {}
	var grades_up := 0
	for c in connectors:
		pairs["%d>%d" % [int(c.from_floor), int(c.to_floor)]] = true
		if String(c.kind) == "grade" and int(c.from_floor) == 1:
			grades_up += 1
	for key in ["1>2", "2>1"]:
		t.check(pairs.has(key), "stadium: connector route %s exists" % key)
	t.check(grades_up == 4, "stadium: a ramp up on every side (got %d)" % grades_up)

	# Each connector's approach run starts on its own from_floor.
	for c in connectors:
		var entry: Vector2 = c.position - (c.approach_dir as Vector2).normalized() * 220.0
		var best := -1
		for z in zones:
			if (z.rect as Rect2).has_point(entry):
				best = maxi(best, int(z.floor))
		t.check(best == int(c.from_floor),
			"stadium: %s approach run sits on floor %d (zone says %d)" % [c.name, int(c.from_floor), best])

	# The boss rig: Goliath duels alone, authored with the full flag set,
	# riding an authored waypoint ring that stays inside the arena.
	var boss: Node2D = null
	for e in enemies:
		if String(e.name) == "Enemy1":
			boss = e
	t.check(enemies.size() == 1 and boss != null,
		"stadium: Goliath duels alone (got %d enemies)" % enemies.size())
	if boss:
		t.check(bool(boss.get("fixed_loadout")), "stadium: the re-roll never touches Goliath")
		t.check(bool(boss.get("launch_immune")), "stadium: Goliath is launch-immune")
		t.check(float(boss.get("mine_weakness")) > 1.0,
			"stadium: the soft underbelly is authored (land mines bite)")
		t.check(is_equal_approx(float(boss.get("body_scale")), 1.6),
			"stadium: Goliath wears the x1.6 stadium scale")
		var bstats: Resource = boss.get("stats")
		t.check(bstats != null and bstats.get("id") == &"goliath_cab",
			"stadium: the goliath stats deck is authored")
		var drv := boss.get_node_or_null(^"Driver")
		t.check(drv != null and drv.get_script() != null
			and (drv.get_script() as Script).resource_path.ends_with("goliath_driver.gd"),
			"stadium: the bespoke GoliathDriver rides the boss")
		t.check(boss.get_node_or_null(^"BossController") != null,
			"stadium: the boss controller is mounted")
	# The soft belly's ammunition: exactly two land-mine crates — one down on
	# the field, one up on the rim (the climb earns the counter).
	var mine_crates: Array = []
	for child in stadium.get_children():
		var k: Variant = child.get("kind")
		if k != null and String(k) == "mine":
			mine_crates.append(child)
	t.check(mine_crates.size() == 2,
		"stadium: exactly two mine crates (got %d)" % mine_crates.size())
	var crate_floors := {}
	for c in mine_crates:
		var cf := -1
		for z in zones:
			if (z.rect as Rect2).has_point((c as Node2D).position):
				cf = maxi(cf, int(z.floor))
		crate_floors[cf] = true
	t.check(crate_floors.has(1) and crate_floors.has(2),
		"stadium: one mine crate per floor")

	var ring := stadium.get_node_or_null(^"GoliathLoop")
	t.check(ring != null and ring.get_child_count() >= 8,
		"stadium: the loop ring is authored (got %d marks)"
		% (ring.get_child_count() if ring else 0))
	if ring and not field.is_empty():
		for m in ring.get_children():
			t.check((field.rect as Rect2).has_point((m as Node2D).position),
				"stadium: %s sits inside the arena" % m.name)

	# Props keep their distance: cover never overlaps cover, and every jump
	# pad belongs to one terrace and stands clear of solid scenery.
	var solids: Array = []
	var pads: Array = []
	for child in stadium.get_children():
		var n := String(child.name)
		if n.begins_with("Container") or n.begins_with("Junk") \
				or n.begins_with("Crate") or n.begins_with("Barrier") \
				or n.begins_with("FanRail"):
			solids.append(child)
		elif child is Area2D and child.get_script() != null \
				and (child.get_script() as Script).resource_path.ends_with("jump_pad.gd"):
			pads.append(child)
	for i in solids.size():
		for j in range(i + 1, solids.size()):
			t.check(not _body_rect(solids[i]).intersects(_body_rect(solids[j])),
				"stadium: %s and %s don't overlap" % [solids[i].name, solids[j].name])
	t.check(pads.size() == 2, "stadium: two jump pads found (got %d)" % pads.size())
	for r in pads:
		t.check(int(r.get("floor_index")) >= 1, "stadium: %s belongs to one terrace" % r.name)
		var rr := _body_rect(r)
		for solid in solids:
			t.check(not rr.intersects(_body_rect(solid)),
				"stadium: %s stands clear of %s" % [r.name, solid.name])

	stadium.free()
