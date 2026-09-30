extends RefCounted
## Freeway's floor-2 retrofit and signed-off eastward expansion contract. The
## plan stays dependency-free; these checks prove its grades, islands, retaining
## edge, and today's live floor-masked car/rail combat agree.

const FreewayScene := preload("res://levels/freeway/freeway.tscn")
const Plan := preload("res://levels/freeway/freeway_plan.gd")
const Floors := preload("res://game/floors.gd")
const FLOOR_MID := 16
const SAMPLE_STEP := 8
const SIDES := [&"north", &"east", &"south", &"west"]

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
		"stations": 0, "pickups": 0, "pads": 0, "cars": 0,
	}
	var floor_zones := 0
	for node in nodes:
		var source := String(node.scene_file_path).get_file()
		if node is StaticBody2D and (node.collision_layer & 4) != 0:
			var floor_value: Variant = node.get("floor_index")
			t.check((floor_value is int and int(floor_value) == 2)
					or (node.collision_layer & FLOOR_MID) != 0,
				"freeway: %s is a floor-2 obstacle (layer %d, floor %s)" %
				[node.name, node.collision_layer, floor_value])
		if node is JumpPad:
			counts.pads += 1
			t.check(node.floor_index == 2, "freeway: %s jump pad is on floor 2" % node.name)
		if node is Vehicle:
			counts.cars += 1
			t.check(node.start_floor == 2, "freeway: %s starts on floor 2" % node.name)
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
	t.check(counts.cars == 7, "freeway: 7 cars (got %d)" % counts.cars)
	t.check(floor_zones == 2, "freeway: the plate and lowland are the only live floor zones")
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

func test_freeway_temporary_east_wall_matches_plate_edge() -> void:
	var freeway := FreewayScene.instantiate()
	var wall := freeway.get_node_or_null(^"TempEastWall") as StaticBody2D
	var arena := Plan.ARENA_RECT
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	var expected := Rect2(Vector2(plate.end.x, arena.position.y),
		Vector2(24, arena.size.y))
	t.check(wall != null, "freeway: TempEastWall exists")
	if wall:
		var collisions: Array[CollisionShape2D] = []
		for child in wall.get_children():
			if child is CollisionShape2D:
				collisions.append(child)
		t.check(wall.collision_layer == 2 and wall.collision_mask == 0,
			"freeway: TempEastWall is on the wall layer only")
		t.check(collisions.size() == 1, "freeway: TempEastWall has one collision rectangle")
		if collisions.size() == 1:
			t.check(_collision_rect(wall, collisions[0]) == expected,
				"freeway: TempEastWall spans the plate edge for the full arena height")
		var vis := wall.get_node_or_null(^"Vis") as Polygon2D
		t.check(vis != null, "freeway: TempEastWall is visible")
		if vis:
			var boundary_vis := freeway.get_node(^"Boundary/RightVis") as Polygon2D
			t.check(vis.color == boundary_vis.color,
				"freeway: TempEastWall uses the boundary grey")
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
	t.check(found, "freeway: campaign profile exists")

func test_freeway_temporary_wall_holds_live_car() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	player.global_position = Vector2(1000, 1200)
	player.heading = 0.0
	player.velocity = Vector2.ZERO
	player.set_driver(FullThrottleDriver.new())
	var max_x := player.global_position.x
	for i in 120:
		await t.physics_frame
		max_x = maxf(max_x, player.global_position.x)
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	t.check(max_x <= plate.end.x,
		"freeway: TempEastWall holds an eastbound car on the plate (max x %.1f)" % max_x)
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
