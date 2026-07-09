extends RefCounted
## The Docks structural contract, read off the instantiated (never tree-
## entered) scene like test_spawn_distance: every spawn's authored start_floor
## has a matching floor-tag zone under it, LARGE class rules hold (7 enemies,
## 3 stations), every floor pair has a connector in both directions, and each
## connector's from_floor zone actually covers its approach run.

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

func test_dock_structure() -> void:
	var scene: PackedScene = load("res://levels/dock/dock.tscn")
	var dock: Node = scene.instantiate()

	var zones: Array = []      # {rect, floor}
	var connectors: Array = [] # nodes
	var stations := 0
	var enemies: Array = []
	var player: Node2D = null
	for child in dock.get_children():
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

	t.check(enemies.size() == 7, "dock: LARGE class carries 7 enemies (got %d)" % enemies.size())
	t.check(stations == 2, "dock: two stations only — this size earns its scarcity (got %d)" % stations)
	t.check(zones.size() >= 10, "dock: floor tags cover the terraces (got %d zones)" % zones.size())

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
		t.check(best == want, "dock: %s start_floor %d matches the zone under it (zone says %d)"
			% [s.name, want, best])

	# Route completeness: both directions for both floor pairs.
	var pairs := {}
	for c in connectors:
		pairs["%d>%d" % [int(c.from_floor), int(c.to_floor)]] = true
	for key in ["1>2", "2>1", "2>3", "3>2"]:
		t.check(pairs.has(key), "dock: connector route %s exists" % key)

	# Sky bridges: floor-3 spans whose BOTH ends touch another roof surface.
	for bname in ["FZBridgeCentral", "FZBridgeEast"]:
		var b: Dictionary = {}
		for z in zones:
			if z.name == bname:
				b = z
		t.check(not b.is_empty() and int(b.get("floor", -1)) == 3, "dock: %s exists at floor 3" % bname)
		if b.is_empty():
			continue
		var touches := 0
		var grown: Rect2 = (b.rect as Rect2).grow(2.0)
		for z in zones:
			if z.name != bname and int(z.floor) == 3 and grown.intersects(z.rect):
				touches += 1
		t.check(touches >= 2, "dock: %s connects two roof surfaces (touches %d)" % [bname, touches])

	# Props keep their distance: no container inside another, and every ramp
	# belongs to exactly one terrace and stands clear of solid scenery.
	var boxes: Array = []
	var ramp_solids: Array = []
	var ramps: Array = []
	for child in dock.get_children():
		var n := String(child.name)
		if n.begins_with("Container"):
			boxes.append(child)
			ramp_solids.append(child)
		elif n.begins_with("Warehouse") or n.begins_with("Rail") or n == "RetainingWall":
			ramp_solids.append(child)
		elif child is Area2D and child.get_script() != null \
				and (child.get_script() as Script).resource_path.ends_with("ramp.gd"):
			ramps.append(child)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			t.check(not _body_rect(boxes[i]).intersects(_body_rect(boxes[j])),
				"dock: %s and %s don't overlap" % [boxes[i].name, boxes[j].name])
	t.check(ramps.size() == 8, "dock: eight ramps found (got %d)" % ramps.size())
	for r in ramps:
		t.check(int(r.get("floor_index")) >= 1, "dock: %s belongs to one terrace" % r.name)
		var rr := _body_rect(r)
		for solid in ramp_solids:
			t.check(not rr.intersects(_body_rect(solid)),
				"dock: %s stands clear of %s" % [r.name, solid.name])

	# Each connector's approach run starts on its own from_floor.
	for c in connectors:
		var entry: Vector2 = c.position - (c.approach_dir as Vector2).normalized() * 220.0
		var best := -1
		for z in zones:
			if (z.rect as Rect2).has_point(entry):
				best = maxi(best, int(z.floor))
		t.check(best == int(c.from_floor),
			"dock: %s approach run sits on floor %d (zone says %d)" % [c.name, int(c.from_floor), best])

	dock.free()
