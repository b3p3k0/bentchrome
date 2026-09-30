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

func _init(runner) -> void:
	t = runner

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

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
	t.check(floor_zones == 1, "freeway: only the floor-2 plate is live this card")
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

func test_freeway_floor_two_car_still_rams_and_shoots_rails() -> void:
	var freeway := FreewayScene.instantiate()
	for child in freeway.get_children():
		if child is Vehicle and child.name != &"Vehicle":
			freeway.remove_child(child)
			child.free()
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
