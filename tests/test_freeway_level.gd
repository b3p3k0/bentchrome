extends RefCounted
## Freeway's floor-2 retrofit and signed-off eastward expansion contract. The
## plan stays dependency-free; these checks prove its grades, islands, retaining
## edge, country-road landing, and today's live floor-masked car/rail combat agree.

const FreewayScene := preload("res://levels/freeway/freeway.tscn")
const Plan := preload("res://levels/freeway/freeway_plan.gd")
const Floors := preload("res://game/floors.gd")
const FLOOR_BITS := 8 | 16 | 32
const SAMPLE_STEP := 8
const CONNECTOR_RUNUP := 220.0
const EDGE_INSET := 40.0
const SIDES := [&"north", &"east", &"south", &"west"]
const F4_FLOOR_ZONES := [&"FZShelfN", &"FZShelfS"]
const F4_RAMPS := [&"RampN", &"RampS"]
const F4_WALLS := [
	&"RetainE_1", &"RetainE_2", &"RetainE_3", &"RetainE_4",
	&"ShelfN_E", &"ShelfN_N", &"ShelfS_E", &"ShelfS_S",
]
const F5_WALLS := [&"LandingN", &"LandingS", &"RampBN", &"RampBS"]
const TEMP_LANDING_W := Rect2(1448, -928, 24, 320)

var t

class FullThrottleDriver:
	extends Driver
	func get_intent(_vehicle, _delta: float) -> Dictionary:
		return {
			"throttle": 1.0, "steer": 0.0, "fire_mg": false,
			"fire_selected": false, "weapon_prev": false, "weapon_next": false,
			"handbrake": false,
		}

func _init(runner) -> void:
	t = runner

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

func _collision_rect(owner: Node2D, collision: CollisionShape2D) -> Rect2:
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()
	return Rect2(owner.position + collision.position - rectangle.size * 0.5, rectangle.size)

func _remove_other_cars(freeway: Node) -> void:
	for child in freeway.get_children():
		if child is Vehicle and child.name != &"Vehicle":
			freeway.remove_child(child)
			child.free()

func _toward_vector(toward: StringName) -> Vector2:
	match toward:
		&"north":
			return Vector2.UP
		&"east":
			return Vector2.RIGHT
		&"south":
			return Vector2.DOWN
		&"west":
			return Vector2.LEFT
	return Vector2.ZERO

func _has_point_inclusive(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
		and point.y >= rect.position.y and point.y <= rect.end.y

func _floor_at_structure(freeway: Node, point: Vector2) -> int:
	var best := -1
	for child in freeway.get_children():
		if child is FloorZone:
			var rect := Rect2(child.position - child.size * 0.5, child.size)
			if rect.grow(8.0).has_point(point):
				best = maxi(best, child.floor_index)
		elif child is Ramp:
			var local: Vector2 = (point - child.position).rotated(-child.rotation)
			var half: Vector2 = child.size * 0.5 + Vector2.ONE * 8.0
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				best = maxi(best, child.high_floor if local.y <= 0.0 else child.low_floor)
	return best

func _side_midpoint(rect: Rect2, side: StringName) -> Vector2:
	match side:
		&"north":
			return Vector2(rect.get_center().x, rect.position.y)
		&"east":
			return Vector2(rect.end.x, rect.get_center().y)
		&"south":
			return Vector2(rect.get_center().x, rect.end.y)
		&"west":
			return Vector2(rect.position.x, rect.get_center().y)
	return Vector2.INF

func _side_points(rect: Rect2, side: StringName) -> Array[Vector2]:
	var start: Vector2
	var finish: Vector2
	match side:
		&"north":
			start = rect.position
			finish = Vector2(rect.end.x, rect.position.y)
		&"east":
			start = Vector2(rect.end.x, rect.position.y)
			finish = rect.end
		&"south":
			start = Vector2(rect.position.x, rect.end.y)
			finish = rect.end
		&"west":
			start = rect.position
			finish = Vector2(rect.position.x, rect.end.y)
	var length := int(start.distance_to(finish))
	var points: Array[Vector2] = []
	for distance in range(0, length + 1, SAMPLE_STEP):
		points.append(start + start.direction_to(finish) * distance)
	return points

func _meets_wall_or_grade(point: Vector2) -> bool:
	for wall: Dictionary in Plan.WALLS.values():
		if _has_point_inclusive(wall["rect"], point):
			return true
	for ramp: Dictionary in Plan.RAMPS.values():
		if _has_point_inclusive(ramp["rect"], point):
			return true
	return false

func test_freeway_plan_grade_ends_and_spacing() -> void:
	var ramp_names := Plan.RAMPS.keys()
	for ramp_name in ramp_names:
		var ramp: Dictionary = Plan.RAMPS[ramp_name]
		var rect: Rect2 = ramp["rect"]
		var toward := _toward_vector(ramp["toward"])
		var half_length := rect.size.y * 0.5 if toward.y != 0.0 else rect.size.x * 0.5
		var high_end := rect.get_center() + toward * (half_length + 1.0)
		var low_end := rect.get_center() - toward * (half_length + 1.0)
		t.check(Plan.floor_at(high_end) == int(ramp["high"]),
			"freeway plan: %s high end meets floor %d" % [ramp_name, ramp["high"]])
		t.check(Plan.floor_at(low_end) == int(ramp["low"]),
			"freeway plan: %s low end meets floor %d" % [ramp_name, ramp["low"]])
	for i in ramp_names.size():
		for j in range(i + 1, ramp_names.size()):
			var a: Rect2 = Plan.rect_of(Plan.RAMPS, ramp_names[i])
			var b: Rect2 = Plan.rect_of(Plan.RAMPS, ramp_names[j])
			t.check(not a.intersects(b), "freeway plan: %s and %s grades do not overlap" %
				[ramp_names[i], ramp_names[j]])

func test_freeway_plan_floor_two_islands_are_guarded() -> void:
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	for zone_name: StringName in [&"FZLanding", &"FZShelfN", &"FZShelfS"]:
		var rect := Plan.rect_of(Plan.FLOOR_ZONES, zone_name)
		for side: StringName in SIDES:
			if _has_point_inclusive(plate, _side_midpoint(rect, side)):
				continue
			for point in _side_points(rect, side):
				t.check(_meets_wall_or_grade(point),
					"freeway plan: %s %s side is guarded at %s" %
					[zone_name, side, point])

func test_freeway_plan_plate_east_edge_is_closed() -> void:
	for y in range(int(Plan.ARENA_RECT.position.y), int(Plan.ARENA_RECT.end.y) + 1,
			SAMPLE_STEP):
		t.check(Plan.plate_east_edge_covered(y),
			"freeway plan: plate east edge is covered at y=%d" % y)

func test_freeway_floor_stamps_and_counts() -> void:
	var freeway := FreewayScene.instantiate()
	var nodes: Array = []
	_walk(freeway, nodes)
	var counts := {
		"rails": 0, "debris": 0, "clutter": 0, "wrecks": 0,
		"stations": 0, "pickups": 0, "pads": 0, "cars": 0, "rivals": 0,
	}
	var floor_zones := 0
	for node in nodes:
		var source := String(node.scene_file_path).get_file()
		if node is StaticBody2D and (node.collision_layer & 4) != 0:
			var floor_value: Variant = node.get("floor_index")
			t.check((floor_value is int and int(floor_value) >= 1)
					or (node.collision_layer & FLOOR_BITS) != 0,
				"freeway: %s resolves an obstacle floor (layer %d, floor %s)" %
					[node.name, node.collision_layer, floor_value])
		if node is JumpPad:
			counts.pads += 1
			t.check(node.floor_index == 2, "freeway: %s jump pad is on floor 2" % node.name)
		if node is Vehicle:
			counts.cars += 1
			if String(node.name).begins_with("Enemy"):
				counts.rivals += 1
			var planned_floor := Plan.floor_at(node.position)
			t.check(node.start_floor == planned_floor,
				"freeway: %s starts on planned floor %d" % [node.name, planned_floor])
		if node is FloorZone:
			floor_zones += 1
		match source:
			"destructible_block.tscn":
				if String(node.name).begins_with("Rail"):
					counts.rails += 1
				elif String(node.name).begins_with("Debris"):
					counts.debris += 1
			"clutter.tscn":
				counts.clutter += 1
			"derelict_car.tscn":
				counts.wrecks += 1
			"health_station.tscn":
				counts.stations += 1
				t.check(node.floor_index == -1,
					"freeway: %s station stays ground-bit ungated like Dock" % node.name)
			"ammo_pickup.tscn":
				counts.pickups += 1
				t.check(node.floor_index == -1,
					"freeway: %s pickup stays ground-bit ungated like Dock" % node.name)

	t.check(counts.rails == 12, "freeway: 12 rails (got %d)" % counts.rails)
	t.check(counts.debris == 4, "freeway: 4 debris blocks (got %d)" % counts.debris)
	t.check(counts.clutter == 15, "freeway: 15 clutter props (got %d)" % counts.clutter)
	t.check(counts.wrecks == 2, "freeway: 2 wrecks (got %d)" % counts.wrecks)
	t.check(counts.stations == 3, "freeway: 3 stations (got %d)" % counts.stations)
	t.check(counts.pickups == 8, "freeway: 8 ammo pickups (got %d)" % counts.pickups)
	t.check(counts.pads == 2, "freeway: 2 jump pads (got %d)" % counts.pads)
	t.check(counts.cars == 8, "freeway: 8 cars (got %d)" % counts.cars)
	t.check(counts.rivals == 7, "freeway: 7 rivals (got %d)" % counts.rivals)
	t.check(floor_zones == 3 + F4_FLOOR_ZONES.size(),
		"freeway: the plate, lowland, landing, and two shelves are live floor zones")
	freeway.free()

func test_freeway_scene_plate_matches_plan() -> void:
	var freeway := FreewayScene.instantiate()
	var plate := freeway.get_node_or_null(^"FZPlate") as FloorZone
	t.check(plate != null, "freeway: FZPlate exists")
	if plate:
		var actual := Rect2(plate.position - plate.size * 0.5, plate.size)
		t.check(plate.floor_index == int(Plan.FLOOR_ZONES[&"FZPlate"]["floor"]),
			"freeway: FZPlate floor matches the plan")
		t.check(actual == Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate"),
			"freeway: FZPlate rectangle matches the plan")
	freeway.free()

func test_freeway_arena_shell_matches_plan() -> void:
	var freeway := FreewayScene.instantiate()
	var asphalt := freeway.get_node(^"Asphalt") as Polygon2D
	var grid := freeway.get_node(^"GridFloor") as GridFloor
	var arena := Plan.ARENA_RECT
	var corners := [
		arena.position,
		Vector2(arena.end.x, arena.position.y),
		arena.end,
		Vector2(arena.position.x, arena.end.y),
	]
	t.check(asphalt.polygon.size() == 4, "freeway: asphalt is one arena rectangle")
	for corner in corners:
		t.check(corner in asphalt.polygon, "freeway: asphalt reaches arena corner %s" % corner)
	t.check(grid.position == arena.get_center(), "freeway: grid is centred on the arena")
	t.check(grid.extent == arena.size * 0.5, "freeway: grid lines reach every arena edge")
	freeway.free()

func test_freeway_boundary_encloses_arena_only() -> void:
	var freeway := FreewayScene.instantiate()
	var boundary := freeway.get_node(^"Boundary") as StaticBody2D
	var arena := Plan.ARENA_RECT
	var expected := {
		&"TopCol": Rect2(arena.position - Vector2(40, 40),
			Vector2(arena.size.x + 80, 40)),
		&"BottomCol": Rect2(Vector2(arena.position.x - 40, arena.end.y),
			Vector2(arena.size.x + 80, 40)),
		&"LeftCol": Rect2(arena.position - Vector2(40, 40),
			Vector2(40, arena.size.y + 80)),
		&"RightCol": Rect2(Vector2(arena.end.x, arena.position.y - 40),
			Vector2(40, arena.size.y + 80)),
	}
	var collisions: Array[CollisionShape2D] = []
	for child in boundary.get_children():
		if child is CollisionShape2D:
			collisions.append(child)
	t.check(collisions.size() == expected.size(),
		"freeway: boundary has exactly four collision rectangles")
	for collision in collisions:
		var rectangle := collision.shape as RectangleShape2D
		t.check(expected.has(collision.name),
			"freeway: boundary collision %s is one of the four sides" % collision.name)
		t.check(rectangle != null, "freeway: %s uses a rectangle" % collision.name)
		if rectangle and expected.has(collision.name):
			t.check(_collision_rect(boundary, collision) == expected[collision.name],
				"freeway: %s encloses the arena with a 20px stand-off" % collision.name)
	freeway.free()

func test_freeway_lowland_matches_plan() -> void:
	var freeway := FreewayScene.instantiate()
	var lowland_plan: Dictionary = Plan.FLOOR_ZONES[&"FZLowland"]
	var expected: Rect2 = lowland_plan["rect"]
	var floor_zone := freeway.get_node_or_null(^"FZLowland") as FloorZone
	var dirt := freeway.get_node_or_null(^"LowlandDirt") as Area2D
	t.check(floor_zone != null, "freeway: FZLowland exists")
	if floor_zone:
		var actual := Rect2(floor_zone.position - floor_zone.size * 0.5, floor_zone.size)
		t.check(floor_zone.floor_index == int(lowland_plan["floor"]),
			"freeway: FZLowland floor matches the plan")
		t.check(actual == expected, "freeway: FZLowland rectangle matches the plan")
	t.check(dirt != null, "freeway: LowlandDirt exists")
	if dirt:
		var collision := dirt.get_node_or_null(^"Col") as CollisionShape2D
		var vis := dirt.get_node_or_null(^"Vis") as Polygon2D
		t.check(dirt.collision_layer == 128 and dirt.collision_mask == 0,
			"freeway: LowlandDirt is terrain-only collision")
		t.check(dirt.get("terrain_type") == &"dirt", "freeway: lowland handles as dirt")
		t.check(collision != null, "freeway: LowlandDirt has a collision rectangle")
		if collision:
			t.check(_collision_rect(dirt, collision) == expected,
				"freeway: LowlandDirt collision covers the lowland")
		t.check(vis != null, "freeway: LowlandDirt has visible paint")
		if vis:
			var shoulder_vis := freeway.get_node(^"ShoulderN/Vis") as Polygon2D
			t.check(vis.material == shoulder_vis.material,
				"freeway: LowlandDirt uses the shared dirt paint")
	freeway.free()

func test_freeway_f4_floor_zones_and_ramps_match_plan() -> void:
	var freeway := FreewayScene.instantiate()
	for zone_name: StringName in F4_FLOOR_ZONES:
		var zone := freeway.get_node_or_null(NodePath(zone_name)) as FloorZone
		var expected: Dictionary = Plan.FLOOR_ZONES[zone_name]
		t.check(zone != null, "freeway: %s exists" % zone_name)
		if zone:
			var actual := Rect2(zone.position - zone.size * 0.5, zone.size)
			t.check(actual == expected["rect"],
				"freeway: %s rectangle matches the plan" % zone_name)
			t.check(zone.floor_index == int(expected["floor"]),
				"freeway: %s floor matches the plan" % zone_name)

	for ramp_name: StringName in F4_RAMPS:
		var ramp := freeway.get_node_or_null(NodePath(ramp_name)) as Ramp
		var expected: Dictionary = Plan.RAMPS[ramp_name]
		var rect: Rect2 = expected["rect"]
		t.check(ramp != null, "freeway: %s exists" % ramp_name)
		if ramp == null:
			continue
		t.check(ramp.position == rect.get_center() and ramp.size == rect.size,
			"freeway: %s rectangle matches the plan" % ramp_name)
		t.check(ramp.low_floor == int(expected["low"])
				and ramp.high_floor == int(expected["high"]),
			"freeway: %s floors match the plan" % ramp_name)
		t.check(ramp.terrain_type == "road" and is_equal_approx(ramp.downhill_pull, 120.0)
				and ramp.rails,
			"freeway: %s is a railed road grade with the standard pull" % ramp_name)
		var toward := _toward_vector(expected["toward"])
		var expected_rotation := toward.angle() + PI * 0.5
		t.check(absf(angle_difference(ramp.rotation, expected_rotation)) < 0.001,
			"freeway: %s high end faces %s" % [ramp_name, expected["toward"]])
		var half_length := ramp.size.y * 0.5
		var high_end := ramp.position + Vector2.UP.rotated(ramp.rotation) * half_length
		var low_end := ramp.position + Vector2.DOWN.rotated(ramp.rotation) * half_length
		t.check(_floor_at_structure(freeway, high_end) == ramp.high_floor,
			"freeway: %s high end lands on floor %d" % [ramp_name, ramp.high_floor])
		t.check(_floor_at_structure(freeway, low_end) == ramp.low_floor,
			"freeway: %s low end lands on floor %d" % [ramp_name, ramp.low_floor])
	freeway.free()

func test_freeway_f4_walls_and_temporary_gap_match_plan() -> void:
	var freeway := FreewayScene.instantiate()
	var retaining_grey := Color(0.42, 0.42, 0.5, 1)
	for wall_name: StringName in F4_WALLS:
		var wall := freeway.get_node_or_null(NodePath(wall_name)) as StaticBody2D
		var expected: Dictionary = Plan.WALLS[wall_name]
		t.check(wall != null, "freeway: %s exists" % wall_name)
		if wall == null:
			continue
		var collision := wall.get_node_or_null(^"Col") as CollisionShape2D
		var vis := wall.get_node_or_null(^"Vis") as Polygon2D
		t.check(wall.collision_layer == int(expected["layer"])
				and wall.collision_mask == 0,
			"freeway: %s collision bits match the plan" % wall_name)
		t.check(collision != null and _collision_rect(wall, collision) == expected["rect"],
			"freeway: %s collision rectangle matches the plan" % wall_name)
		t.check(vis != null and vis.color == retaining_grey,
			"freeway: %s uses the retaining grey" % wall_name)

	t.check(freeway.get_node_or_null(^"TempEastWall") == null,
		"freeway: TempEastWall is gone")
	var gap := freeway.get_node_or_null(^"TempDeckGap") as StaticBody2D
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	var wall_width := Plan.rect_of(Plan.WALLS, &"RetainE_1").size.x
	var expected_gap := Rect2(Vector2(plate.end.x, deck.position.y),
		Vector2(wall_width, deck.size.y))
	t.check(gap != null, "freeway: TempDeckGap plugs the future deck opening")
	if gap:
		var collision := gap.get_node_or_null(^"Col") as CollisionShape2D
		t.check(gap.collision_layer == int(Plan.WALLS[&"RetainE_1"]["layer"])
				and gap.collision_mask == 0,
			"freeway: TempDeckGap blocks lowland cars only")
		t.check(collision != null and _collision_rect(gap, collision) == expected_gap,
			"freeway: TempDeckGap exactly covers the future deck opening")
	freeway.free()

func test_freeway_f4_shelf_roads_and_drop_shadows() -> void:
	var freeway := FreewayScene.instantiate()
	var asphalt := freeway.get_node(^"Asphalt") as Polygon2D
	for zone_name: StringName in F4_FLOOR_ZONES:
		var suffix := String(zone_name).trim_prefix("FZShelf")
		var road := freeway.get_node_or_null(NodePath("Shelf%sRoad" % suffix)) as Area2D
		var expected := Plan.rect_of(Plan.FLOOR_ZONES, zone_name)
		t.check(road != null, "freeway: Shelf%sRoad exists" % suffix)
		if road == null:
			continue
		var collision := road.get_node_or_null(^"Col") as CollisionShape2D
		var vis := road.get_node_or_null(^"Vis") as Polygon2D
		t.check(road.get("terrain_type") == &"road"
				and int(road.get("terrain_priority")) == 10,
			"freeway: Shelf%sRoad wins over LowlandDirt as priority-10 road" % suffix)
		t.check(collision != null and _collision_rect(road, collision) == expected,
			"freeway: Shelf%sRoad collision covers its shelf exactly" % suffix)
		t.check(vis != null and vis.material == asphalt.material,
			"freeway: Shelf%sRoad uses SM_asphalt" % suffix)

	for wall_name: StringName in [&"RetainE_1", &"RetainE_2", &"RetainE_3", &"RetainE_4"]:
		var wall_rect := Plan.rect_of(Plan.WALLS, wall_name)
		var shadow_name := StringName("%sShadow" % wall_name)
		var shadow := freeway.get_node_or_null(NodePath(shadow_name)) as Node2D
		t.check(shadow != null, "freeway: %s exists" % shadow_name)
		if shadow == null:
			continue
		var size: Vector2 = shadow.get("size")
		t.check(shadow.position == Vector2(wall_rect.end.x, wall_rect.get_center().y)
				and is_equal_approx(size.x, wall_rect.size.y),
			"freeway: %s spans its retaining wall" % shadow_name)
		t.check(Vector2.DOWN.rotated(shadow.rotation).is_equal_approx(Vector2.RIGHT),
			"freeway: %s falls toward the lowland" % shadow_name)
	freeway.free()

func test_freeway_f4_connectors_have_valid_approaches() -> void:
	var freeway := FreewayScene.instantiate()
	var ramp_connectors := {
		&"ConRampNUp": {"ramp": &"RampN", "from": 1, "to": 2, "up": true},
		&"ConRampNDown": {"ramp": &"RampN", "from": 2, "to": 1, "up": false},
		&"ConRampSUp": {"ramp": &"RampS", "from": 1, "to": 2, "up": true},
		&"ConRampSDown": {"ramp": &"RampS", "from": 2, "to": 1, "up": false},
	}
	for connector_name: StringName in ramp_connectors:
		var connector := freeway.get_node_or_null(NodePath(connector_name)) as FloorConnector
		var cfg: Dictionary = ramp_connectors[connector_name]
		var ramp: Dictionary = Plan.RAMPS[cfg["ramp"]]
		var approach := _toward_vector(ramp["toward"])
		if not bool(cfg["up"]):
			approach = -approach
		t.check(connector != null, "freeway: %s exists" % connector_name)
		if connector == null:
			continue
		t.check(connector.position == (ramp["rect"] as Rect2).get_center()
				and connector.from_floor == int(cfg["from"])
				and connector.to_floor == int(cfg["to"]),
			"freeway: %s is centred on its grade with the right floors" % connector_name)
		t.check(connector.approach_dir == approach and connector.kind == &"grade",
			"freeway: %s has the signed-off grade approach" % connector_name)
		var entry := connector.position - connector.approach_dir * CONNECTOR_RUNUP
		t.check(_floor_at_structure(freeway, entry) == connector.from_floor,
			"freeway: %s approach run sits on floor %d" %
				[connector_name, connector.from_floor])

	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	for connector_name: StringName in [&"ConPlateDownN", &"ConPlateDownS"]:
		var connector := freeway.get_node_or_null(NodePath(connector_name)) as FloorConnector
		t.check(connector != null, "freeway: %s exists" % connector_name)
		if connector == null:
			continue
		t.check(is_equal_approx(connector.position.x, plate.end.x - EDGE_INSET)
				and connector.from_floor == 2 and connector.to_floor == 1,
			"freeway: %s is 40px inside the plate edge" % connector_name)
		t.check(connector.approach_dir == Vector2.RIGHT and connector.kind == &"edge",
			"freeway: %s drives east over the free-drop edge" % connector_name)
		var entry := connector.position - connector.approach_dir * CONNECTOR_RUNUP
		t.check(_floor_at_structure(freeway, entry) == connector.from_floor,
			"freeway: %s approach run sits on floor %d" %
				[connector_name, connector.from_floor])
	freeway.free()

func test_freeway_f5_landing_grade_and_walls_match_plan() -> void:
	var freeway := FreewayScene.instantiate()
	var landing_cfg: Dictionary = Plan.FLOOR_ZONES[&"FZLanding"]
	var landing := freeway.get_node_or_null(^"FZLanding") as FloorZone
	t.check(landing != null, "freeway: FZLanding exists")
	if landing:
		var actual := Rect2(landing.position - landing.size * 0.5, landing.size)
		t.check(actual == landing_cfg["rect"],
			"freeway: FZLanding rectangle matches the plan")
		t.check(landing.floor_index == int(landing_cfg["floor"]),
			"freeway: FZLanding floor matches the plan")

	var ramp_cfg: Dictionary = Plan.RAMPS[&"RampB"]
	var ramp_rect: Rect2 = ramp_cfg["rect"]
	var ramp := freeway.get_node_or_null(^"RampB") as Ramp
	t.check(ramp != null, "freeway: RampB exists")
	if ramp:
		t.check(ramp.position == ramp_rect.get_center()
				and ramp.size == Vector2(ramp_rect.size.y, ramp_rect.size.x),
			"freeway: RampB uses its rotated plan rectangle with length along local Y")
		t.check(ramp.low_floor == int(ramp_cfg["low"])
				and ramp.high_floor == int(ramp_cfg["high"]),
			"freeway: RampB floors match the plan")
		t.check(ramp.terrain_type == "road"
				and is_equal_approx(ramp.downhill_pull, 120.0) and not ramp.rails,
			"freeway: RampB is an unrailed road grade with the standard pull")
		t.check(absf(angle_difference(ramp.rotation, -PI * 0.5)) < 0.001,
			"freeway: RampB local high end faces west")

	var retaining_grey := Color(0.42, 0.42, 0.5, 1)
	for wall_name: StringName in F5_WALLS:
		var wall := freeway.get_node_or_null(NodePath(wall_name)) as StaticBody2D
		var expected: Dictionary = Plan.WALLS[wall_name]
		t.check(wall != null, "freeway: %s exists" % wall_name)
		if wall == null:
			continue
		var collision := wall.get_node_or_null(^"Col") as CollisionShape2D
		var vis := wall.get_node_or_null(^"Vis") as Polygon2D
		t.check(wall.collision_layer == int(expected["layer"])
				and wall.collision_mask == 0,
			"freeway: %s collision bits match the plan" % wall_name)
		t.check(collision != null and _collision_rect(wall, collision) == expected["rect"],
			"freeway: %s collision rectangle matches the plan" % wall_name)
		t.check(vis != null and vis.color == retaining_grey,
			"freeway: %s uses the retaining grey" % wall_name)
	freeway.free()

func test_freeway_f5_ramp_retrofit_structure() -> void:
	var freeway := FreewayScene.instantiate()
	var ramp := freeway.get_node_or_null(^"RampB") as Ramp
	t.check(ramp != null, "freeway retrofit: RampB exists")
	if ramp:
		# Same end-vector proof as the repo-wide retrofit floor lint.
		var half_len := ramp.size.y * 0.5
		var high_end := ramp.position + Vector2(0, -half_len).rotated(ramp.rotation)
		var low_end := ramp.position + Vector2(0, half_len).rotated(ramp.rotation)
		t.check(_floor_at_structure(freeway, high_end) == ramp.high_floor,
			"freeway retrofit: RampB high end reaches floor 2")
		t.check(_floor_at_structure(freeway, low_end) == ramp.low_floor,
			"freeway retrofit: RampB low end rests on floor 1")

	var connectors := {
		&"ConRampBUp": {"from": 1, "to": 2, "approach": Vector2.LEFT},
		&"ConRampBDown": {"from": 2, "to": 1, "approach": Vector2.RIGHT},
	}
	for connector_name: StringName in connectors:
		var connector := freeway.get_node_or_null(NodePath(connector_name)) as FloorConnector
		var cfg: Dictionary = connectors[connector_name]
		t.check(connector != null, "freeway retrofit: %s exists" % connector_name)
		if connector == null:
			continue
		t.check(connector.position == (Plan.RAMPS[&"RampB"]["rect"] as Rect2).get_center()
				and connector.from_floor == int(cfg["from"])
				and connector.to_floor == int(cfg["to"]),
			"freeway retrofit: %s is centred with the right floors" % connector_name)
		t.check(connector.approach_dir == cfg["approach"]
				and connector.kind == &"grade",
			"freeway retrofit: %s has the signed-off grade approach" % connector_name)
		var entry := connector.position - connector.approach_dir * CONNECTOR_RUNUP
		t.check(_floor_at_structure(freeway, entry) == connector.from_floor,
			"freeway retrofit: %s approach run sits on floor %d" %
				[connector_name, connector.from_floor])
	freeway.free()

func test_freeway_f5_roads_shadows_and_temporary_plugs() -> void:
	var freeway := FreewayScene.instantiate()
	var asphalt := freeway.get_node(^"Asphalt") as Polygon2D
	var road_rects := {
		&"LandingRoad": Plan.rect_of(Plan.FLOOR_ZONES, &"FZLanding"),
		&"CountryRoad": Plan.COUNTRY_ROAD,
	}
	for road_name: StringName in road_rects:
		var road := freeway.get_node_or_null(NodePath(road_name)) as Area2D
		var expected: Rect2 = road_rects[road_name]
		t.check(road != null, "freeway: %s exists" % road_name)
		if road == null:
			continue
		var collision := road.get_node_or_null(^"Col") as CollisionShape2D
		var vis := road.get_node_or_null(^"Vis") as Polygon2D
		t.check(road.get("terrain_type") == &"road"
				and int(road.get("terrain_priority")) == 10,
			"freeway: %s wins over LowlandDirt as priority-10 road" % road_name)
		t.check(collision != null and _collision_rect(road, collision) == expected,
			"freeway: %s collision covers its signed-off rectangle" % road_name)
		t.check(vis != null and vis.material == asphalt.material,
			"freeway: %s uses SM_asphalt" % road_name)

	var centerline := freeway.get_node_or_null(^"CountryCenterline") as Node2D
	t.check(centerline != null, "freeway: CountryCenterline exists")
	if centerline:
		var points: PackedVector2Array = centerline.get("points")
		t.check(centerline.get("style") == &"dashed_yellow" and points.size() == 2,
			"freeway: country road has one dashed yellow centreline run")
		for point in points:
			t.check(_has_point_inclusive(Plan.COUNTRY_ROAD, centerline.to_global(point)),
				"freeway: country centreline point %s lies inside COUNTRY_ROAD" % point)
		var ramp_rect := Plan.rect_of(Plan.RAMPS, &"RampB")
		t.check(points[0] == Vector2(Plan.COUNTRY_ROAD.end.x,
				Plan.COUNTRY_ROAD.get_center().y)
				and points[1] == Vector2(ramp_rect.end.x, ramp_rect.get_center().y),
			"freeway: country centreline runs east end to RampB's foot")

	var shadow_cfg := {
		&"LandingNShadow": {
			"position": Vector2(1600, -952), "low_side": Vector2.UP,
		},
		&"LandingSShadow": {
			"position": Vector2(1600, -584), "low_side": Vector2.DOWN,
		},
	}
	for shadow_name: StringName in shadow_cfg:
		var shadow := freeway.get_node_or_null(NodePath(shadow_name)) as Node2D
		var cfg: Dictionary = shadow_cfg[shadow_name]
		t.check(shadow != null, "freeway: %s exists" % shadow_name)
		if shadow == null:
			continue
		var size: Vector2 = shadow.get("size")
		t.check(shadow.get("kind") == &"ledge_shadow" and size == Vector2(256, 90)
				and shadow.position == cfg["position"],
			"freeway: %s spans the landing edge" % shadow_name)
		t.check(Vector2.DOWN.rotated(shadow.rotation).is_equal_approx(cfg["low_side"]),
			"freeway: %s falls toward the lowland" % shadow_name)

	var temp_rects := {
		&"TempLandingW": TEMP_LANDING_W,
		&"TempDeckGap": Rect2(1088, -928, 24, 320),
	}
	for wall_name: StringName in temp_rects:
		var wall := freeway.get_node_or_null(NodePath(wall_name)) as StaticBody2D
		t.check(wall != null, "freeway: %s is present" % wall_name)
		if wall == null:
			continue
		var collision := wall.get_node_or_null(^"Col") as CollisionShape2D
		t.check(wall.collision_layer == 12 and wall.collision_mask == 0,
			"freeway: %s stays on temporary lowland-wall layer 12" % wall_name)
		t.check(collision != null and _collision_rect(wall, collision) == temp_rects[wall_name],
			"freeway: %s plugs its complete future opening" % wall_name)
	freeway.free()

func test_freeway_campaign_size_matches_plan() -> void:
	var flow: Node = t.root.get_node(^"/root/SceneFlow")
	var found := false
	for profile_v in flow.CAMPAIGN:
		var profile: Dictionary = profile_v
		if String(profile.scene) != "res://levels/freeway/freeway.tscn":
			continue
		found = true
		t.check(profile.arena_size == Plan.ARENA_RECT.size,
			"freeway: campaign arena size matches the plan")
		t.check(profile.target_cars == 8, "freeway: campaign targets all 8 cars")
	t.check(found, "freeway: campaign profile exists")
	var mp_found := false
	for profile_v in flow.MP_MAPS:
		var profile: Dictionary = profile_v
		if String(profile.scene) != "res://levels/freeway/freeway.tscn":
			continue
		mp_found = true
		t.check(profile.cars == 8, "freeway: multiplayer harvests all 8 cars")
	t.check(mp_found, "freeway: multiplayer profile exists")

func test_freeway_north_grade_climbs_live_car_to_shelf() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var ramp := Plan.rect_of(Plan.RAMPS, &"RampN")
	var shelf := Plan.rect_of(Plan.FLOOR_ZONES, &"FZShelfN")
	var runup := Plan.rect_of(Plan.WALLS, &"ShelfN_N").size.x
	player.position = Vector2(ramp.get_center().x, ramp.end.y + runup)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	for i in 180:
		await t.physics_frame
	var final_floor := Floors.floor_of(player)
	t.check(final_floor == 2 and _has_point_inclusive(shelf, player.position),
		"freeway: northbound lowland car climbs RampN onto floor-2 FZShelfN "
			+ "(floor %d at %s)" % [final_floor, player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_country_road_climbs_live_car_to_plugged_landing() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var landing := Plan.rect_of(Plan.FLOOR_ZONES, &"FZLanding")
	player.position = Vector2(2800, -768)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.heading = Vector2.LEFT.angle()
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	var min_x := player.position.x
	for i in 300:
		await t.physics_frame
		min_x = minf(min_x, player.position.x)
	var final_floor := Floors.floor_of(player)
	t.check(final_floor == 2 and _has_point_inclusive(landing, player.position),
		"freeway: westbound country-road car climbs RampB into FZLanding "
			+ "(floor %d at %s)" % [final_floor, player.position])
	t.check(min_x >= landing.position.x,
		"freeway: TempLandingW holds the car at x >= 1472 (min x %.1f)" % min_x)
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_landing_south_wall_holds_live_lowland_car() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var landing := Plan.rect_of(Plan.FLOOR_ZONES, &"FZLanding")
	player.position = Vector2(1600, -300)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	var entered_landing := false
	for i in 180:
		await t.physics_frame
		entered_landing = entered_landing or _has_point_inclusive(landing, player.position)
	t.check(not entered_landing and Floors.floor_of(player) == 1,
		"freeway: LandingS holds a northbound floor-1 car out of FZLanding "
			+ "(floor %d at %s)" % [Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_plate_edge_drops_live_car_to_lowland() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	var ramp_width := Plan.rect_of(Plan.RAMPS, &"RampS").size.x
	var connector := freeway.get_node(^"ConPlateDownS") as FloorConnector
	player.position = Vector2(plate.end.x - ramp_width * 0.5, connector.position.y)
	player.start_floor = 2
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.heading = Vector2.RIGHT.angle()
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	for i in 180:
		await t.physics_frame
	t.check(Floors.floor_of(player) == 1 and player.position.x > plate.end.x,
		"freeway: eastbound highway car takes the free one-floor hop into the lowland")
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_retaining_wall_holds_live_lowland_car() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var wall := Plan.rect_of(Plan.WALLS, &"RetainE_4")
	var ramp_width := Plan.rect_of(Plan.RAMPS, &"RampS").size.x
	var connector := freeway.get_node(^"ConPlateDownS") as FloorConnector
	player.position = Vector2(wall.end.x + ramp_width + SAMPLE_STEP * 4,
		connector.position.y)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.heading = Vector2.LEFT.angle()
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	var min_x := player.position.x
	for i in 180:
		await t.physics_frame
		min_x = minf(min_x, player.position.x)
	t.check(min_x >= wall.end.x,
		"freeway: RetainE_4 holds a westbound floor-1 car (min x %.1f)" % min_x)
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_lowland_sets_live_car_floor() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	player.position = Vector2(2000, 0)
	player.set_driver(Driver.new())
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 6:
		await t.physics_frame
	t.check(Floors.floor_of(player) == 1,
		"freeway: a car spawned in the lowland adopts floor 1")
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_floor_two_car_still_rams_and_shoots_rails() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var ram_rail := freeway.get_node(^"RailW1") as StaticBody2D
	var shot_rail := freeway.get_node(^"RailW4") as StaticBody2D
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.set_driver(Driver.new())
	for i in 4:
		await t.physics_frame
	t.check(Floors.floor_of(player) == 2,
		"freeway: the spawned player adopts the highway's floor 2")

	var ram_health := ram_rail.get_node(^"Health") as Health
	var ram_hp := ram_health.hp
	player.global_position = ram_rail.global_position + Vector2(-130, 0)
	player.heading = 0.0
	player.velocity = Vector2(450, 0)
	for i in 30:
		await t.physics_frame
	t.check(ram_health.hp < ram_hp,
		"freeway: the floor-2 player still collides with and rams a floor-2 rail")

	var shot_health := shot_rail.get_node(^"Health") as Health
	var shot_hp := shot_health.hp
	player.global_position = shot_rail.global_position + Vector2(0, 220)
	player.heading = -PI * 0.5
	player.velocity = Vector2.ZERO
	await t.physics_frame
	var mount := player.get_mg_mount()
	var fired := mount.try_fire(player.global_position + Vector2.UP * 30.0,
		Vector2.UP, player)
	t.check(fired, "freeway: a straight MG round leaves the floor-2 lane")
	for i in 30:
		await t.physics_frame
	t.check(shot_health.hp < shot_hp,
		"freeway: a straight floor-2 MG round still hits a lane rail")
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()
