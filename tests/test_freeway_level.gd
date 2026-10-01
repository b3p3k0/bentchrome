extends RefCounted
## Freeway's floor retrofit and signed-off eastward expansion contract. The plan
## stays dependency-free; these checks prove its grades, overpass, islands,
## driveable embankment, and live floor-masked traffic agree.

const FreewayScene := preload("res://levels/freeway/freeway.tscn")
const Plan := preload("res://levels/freeway/freeway_plan.gd")
const Floors := preload("res://game/floors.gd")
const FLOOR_BITS := 8 | 16 | 32
const SAMPLE_STEP := 8
const CONNECTOR_RUNUP := 220.0
const LIVE_ENTRY_SPEED := 600.0
const LIVE_SIM_FRAMES := 90
const JUMP_RUNUP := 150.0
const JUMP_ENTRY_SPEED := 450.0
const JUMP_SIM_FRAMES := 120
const EDGE_INSET := 40.0
const SIDES := [&"north", &"east", &"south", &"west"]
const F4_FLOOR_ZONES := [&"FZShelfN", &"FZShelfS"]
const F4_RAMPS := [&"RampN", &"RampS"]
const F4_WALLS := [
	&"ShelfN_E", &"ShelfN_N", &"ShelfS_E", &"ShelfS_S",
]
const F5_WALLS := [&"LandingN", &"LandingS", &"RampBN", &"RampBS"]
const F6_RAMPS := [&"RampA", &"RampW"]
const F6_WALLS := [&"RampAN", &"RampAS", &"DeckEastStop"]
const LOWLAND_PAD_RUNUP := Rect2(1648, 2208, 450, 384)
const LOWLAND_JUMP_SPEEDS := [JUMP_ENTRY_SPEED, LIVE_ENTRY_SPEED]
const TRUCK_STOP_SOLIDS := [
	&"Store", &"Pump1", &"Pump2", &"Pump3", &"Pump4",
	&"DieselPump1", &"DieselPump2", &"Tanker",
	&"Barrel1", &"Barrel2", &"Barrel3", &"Semi1", &"Semi2",
	&"GarageW", &"GarageE", &"Crate1", &"Crate2",
]
const TRUCK_STOP_BLOCKS := {
	&"Store": {
		"position": Vector2(2400, 448), "size": Vector2(384, 256),
		"deco": &"storefront", "hp": 260.0, "front": "south", "livery": 0,
	},
	&"Pump1": {
		"position": Vector2(2208, 816), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"Pump2": {
		"position": Vector2(2208, 912), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"Pump3": {
		"position": Vector2(2592, 816), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"Pump4": {
		"position": Vector2(2592, 912), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"DieselPump1": {
		"position": Vector2(2880, 1152), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"DieselPump2": {
		"position": Vector2(2880, 1248), "size": Vector2(64, 64),
		"deco": &"pump", "hp": 40.0,
	},
	&"Tanker": {
		"position": Vector2(2624, 1200), "size": Vector2(320, 72),
		"deco": &"tanker", "hp": 90.0, "livery": 2,
	},
	&"Barrel1": {
		"position": Vector2(2900, 1340), "size": Vector2(40, 40),
		"deco": &"barrel", "hp": 30.0,
	},
	&"Barrel2": {
		"position": Vector2(2952, 1372), "size": Vector2(40, 40),
		"deco": &"barrel", "hp": 30.0,
	},
	&"Barrel3": {
		"position": Vector2(2916, 1424), "size": Vector2(40, 40),
		"deco": &"barrel", "hp": 30.0,
	},
	&"Semi1": {
		"position": Vector2(2016, 1650), "size": Vector2(320, 72),
		"deco": &"semi", "hp": 120.0, "livery": 0,
	},
	&"Semi2": {
		"position": Vector2(2496, 1650), "size": Vector2(320, 72),
		"deco": &"semi", "hp": 120.0, "livery": 1,
	},
	&"GarageW": {
		"position": Vector2(2176, 2048), "size": Vector2(256, 256),
		"deco": &"storefront", "hp": 260.0, "front": "east",
	},
	&"GarageE": {
		"position": Vector2(2688, 2048), "size": Vector2(256, 256),
		"deco": &"storefront", "hp": 260.0, "front": "west",
	},
	&"Crate1": {
		"position": Vector2(2660, 600), "size": Vector2(64, 64),
		"deco": &"crate", "hp": 50.0,
	},
	&"Crate2": {
		"position": Vector2(2730, 640), "size": Vector2(64, 64),
		"deco": &"crate", "hp": 50.0,
	},
}
const FARM_BLOCKS := {
	&"Barn": {
		"position": Vector2(2560, -2300), "size": Vector2(320, 256),
		"deco": &"house", "hp": 220.0,
	},
	&"Hay1": {
		"position": Vector2(2300, -1540), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay2": {
		"position": Vector2(2460, -1540), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay3": {
		"position": Vector2(2620, -1540), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay4": {
		"position": Vector2(2780, -1540), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay5": {
		"position": Vector2(2380, -1380), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay6": {
		"position": Vector2(2540, -1380), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Hay7": {
		"position": Vector2(2700, -1380), "size": Vector2(64, 64),
		"deco": &"hay", "hp": 20.0,
	},
	&"Fence1": {
		"position": Vector2(2240, -1232), "size": Vector2(160, 16),
		"deco": &"fence", "hp": 15.0,
	},
	&"Fence2": {
		"position": Vector2(2496, -1232), "size": Vector2(160, 16),
		"deco": &"fence", "hp": 15.0,
	},
	&"Fence3": {
		"position": Vector2(2752, -1232), "size": Vector2(160, 16),
		"deco": &"fence", "hp": 15.0,
	},
	&"FarmJunk": {
		"position": Vector2(2864, -2340), "size": Vector2(96, 96),
		"deco": &"junk", "hp": 60.0,
	},
}
const LOT_CLUTTER := {
	&"LotCone1": {"position": Vector2(2800, 1080), "kind": &"cone"},
	&"LotCone2": {"position": Vector2(2820, 1330), "kind": &"cone"},
	&"LotCone3": {"position": Vector2(2760, 1460), "kind": &"cone"},
	&"Trash1": {"position": Vector2(1900, 800), "kind": &"trash"},
	&"Trash2": {"position": Vector2(2700, 1870), "kind": &"trash"},
	&"Hydrant1": {"position": Vector2(2180, 600), "kind": &"hydrant"},
	&"LotSign1": {"position": Vector2(1700, 720), "kind": &"sign"},
}

var t
var _shared_freeway: Node

class FullThrottleDriver:
	extends Driver
	func get_intent(_vehicle, _delta: float) -> Dictionary:
		return {
			"throttle": 1.0, "steer": 0.0, "fire_mg": false,
			"fire_selected": false, "weapon_prev": false, "weapon_next": false,
			"handbrake": false,
		}

class BlastProbe:
	extends StaticBody2D
	var floor_index := 1
	var health: Health

	func _init() -> void:
		collision_layer = 1
		collision_mask = 0
		var shape := CircleShape2D.new()
		shape.radius = 8.0
		var collision := CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)
		health = Health.new()
		health.max_hp = 100.0
		add_child(health)

func _init(runner) -> void:
	t = runner

func _freeway_structure() -> Node:
	if not is_instance_valid(_shared_freeway):
		_shared_freeway = FreewayScene.instantiate()
	return _shared_freeway

func _free_freeway_structure() -> void:
	if is_instance_valid(_shared_freeway):
		_shared_freeway.free()
	_shared_freeway = null

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

func _collision_rect(owner: Node2D, collision: CollisionShape2D) -> Rect2:
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()
	return Rect2(owner.position + collision.position - rectangle.size * 0.5, rectangle.size)

func _shape_rect(collision: CollisionShape2D) -> Rect2:
	if collision.shape == null or collision.disabled:
		return Rect2()
	var local := collision.shape.get_rect()
	var corners := [
		local.position,
		Vector2(local.end.x, local.position.y),
		local.end,
		Vector2(local.position.x, local.end.y),
	]
	var first: Vector2 = collision.global_transform * corners[0]
	var result := Rect2(first, Vector2.ZERO)
	for corner in corners.slice(1):
		result = result.expand(collision.global_transform * corner)
	return result

func _collect_shape_rects(node: Node, out: Array[Rect2]) -> void:
	if node is CollisionShape2D:
		var rect := _shape_rect(node)
		if rect.has_area():
			out.append(rect)
	for child in node.get_children():
		_collect_shape_rects(child, out)

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

func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))

func _block_rect(block: Node2D) -> Rect2:
	var block_size: Vector2 = block.get("size")
	return Rect2(block.position - block_size * 0.5, block_size)

func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()

func _rotated_rect(center: Vector2, rect_size: Vector2, rotation: float) -> Rect2:
	var half := rect_size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var result := Rect2(center + corners[0].rotated(rotation), Vector2.ZERO)
	for corner in corners.slice(1):
		result = result.expand(center + corner.rotated(rotation))
	return result

func _truck_stop_solids(freeway: Node) -> Array[Node2D]:
	var solids: Array[Node2D] = []
	for node_name: StringName in TRUCK_STOP_SOLIDS:
		var solid := freeway.get_node_or_null(NodePath(node_name)) as Node2D
		if solid:
			solids.append(solid)
	return solids

func _solid_prop_rects(freeway: Node) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for child in freeway.get_children():
		if not child is StaticBody2D:
			continue
		var source := String(child.scene_file_path).get_file()
		if source not in ["destructible_block.tscn", "clutter.tscn", "derelict_car.tscn"]:
			continue
		var rects: Array[Rect2] = []
		_collect_shape_rects(child, rects)
		for rect in rects:
			props.append({"name": child.name, "rect": rect})
	return props

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
	for bank: Dictionary in Plan.BANKS.values():
		if _has_point_inclusive(bank["rect"], point):
			return true
	for ramp: Dictionary in Plan.RAMPS.values():
		if _has_point_inclusive(ramp["rect"], point):
			return true
	return false

func _point_on_wall(point: Vector2) -> bool:
	for wall: Dictionary in Plan.WALLS.values():
		if _has_point_inclusive(wall["rect"], point):
			return true
	return false

func _simulate_pad_landing(pad_name: StringName, direction: Vector2,
		start_floor: int, continue_north_drop := false) -> Dictionary:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var pad := freeway.get_node(NodePath(pad_name)) as JumpPad
	player.position = pad.position - direction * JUMP_RUNUP
	player.start_floor = start_floor
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = direction.angle()
	player.velocity = direction * JUMP_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var result := {
		"launched": false,
		"landed": false,
		"launch_speed": 0.0,
		"landing": Vector2.INF,
		"floor": -1,
		"on_wall": false,
		"dropped": false,
		"drop_floor": -1,
		"drop_position": Vector2.INF,
	}
	for i in JUMP_SIM_FRAMES:
		await t.physics_frame
		if not result.launched and player.height > 0.0:
			result.launched = true
			result.launch_speed = player.velocity.length()
		elif result.launched and not result.landed and player.height <= 0.0 \
				and is_zero_approx(player.vz):
			result.landed = true
			result.landing = player.position
			result.floor = Floors.floor_of(player)
			result.on_wall = _point_on_wall(player.position)
			if not continue_north_drop:
				break
		elif result.landed and continue_north_drop and Floors.floor_of(player) == 2 \
				and player.position.y < Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck").position.y:
			result.dropped = true
			result.drop_floor = Floors.floor_of(player)
			result.drop_position = player.position
			break
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()
	return result

func _simulate_lowland_jump(entry_speed: float) -> Dictionary:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var pad := freeway.get_node(^"JumpLowland") as JumpPad
	player.position = pad.position + Vector2(JUMP_RUNUP, 0.0)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.LEFT.angle()
	player.velocity = Vector2.LEFT * entry_speed
	player.set_driver(FullThrottleDriver.new())
	var result := {
		"launched": false,
		"landed": false,
		"landing": Vector2.INF,
		"landing_floor": -1,
		"on_wall": false,
		"floor_two_after_landing": false,
		"frames_to_floor_two": -1,
	}
	var landing_frame := -1
	for frame in JUMP_SIM_FRAMES + 120:
		await t.physics_frame
		result.on_wall = result.on_wall or _point_on_wall(player.position)
		if not result.launched and player.height > 0.0:
			result.launched = true
		elif result.launched and not result.landed and player.height <= 0.0 \
				and is_zero_approx(player.vz):
			result.landed = true
			result.landing = player.position
			result.landing_floor = Floors.floor_of(player)
			landing_frame = frame
		if result.landed and Floors.floor_of(player) == 2:
			result.floor_two_after_landing = true
			result.frames_to_floor_two = frame - landing_frame
			break
		if result.landed and frame - landing_frame >= 120:
			break
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()
	return result

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

func test_freeway_f11_banks_match_plan_and_skin_order() -> void:
	var freeway := _freeway_structure()
	for bank_name: StringName in Plan.BANKS:
		var bank := freeway.get_node_or_null(NodePath(bank_name)) as Ramp
		var cfg: Dictionary = Plan.BANKS[bank_name]
		var expected: Rect2 = cfg["rect"]
		t.check(bank != null, "freeway embankment: %s exists" % bank_name)
		if bank == null:
			continue
		var actual := _rotated_rect(bank.position, bank.size, bank.rotation)
		t.check(actual.position.is_equal_approx(expected.position)
				and actual.size.is_equal_approx(expected.size),
			"freeway embankment: %s world rectangle matches the plan" % bank_name)
		t.check(bank.position == expected.get_center()
				and bank.size == Vector2(expected.size.y, expected.size.x),
			"freeway embankment: %s uses west-grade local dimensions" % bank_name)
		t.check(bank.low_floor == int(cfg["low"])
				and bank.high_floor == int(cfg["high"]),
			"freeway embankment: %s climbs floor 1 to floor 2" % bank_name)
		t.check(absf(angle_difference(bank.rotation, -PI * 0.5)) < 0.001
				and cfg["toward"] == &"west",
			"freeway embankment: %s climbs west" % bank_name)
		t.check(not bank.surface_paint and not bank.rails
				and bank.terrain_type == "grass"
				and is_equal_approx(bank.downhill_pull, 120.0),
			"freeway embankment: %s is a paintless unrailed grass grade" % bank_name)
		var skin := freeway.get_child(bank.get_index() + 1) as Node2D
		var skin_script := skin.get_script() as Script if skin else null
		t.check(skin != null and skin.get("kind") == &"embankment"
				and skin.position == bank.position and skin.rotation == bank.rotation
				and skin.get("size") == bank.size and skin_script != null
				and skin_script.resource_path == "res://levels/freeway/freeway_deco.gd",
			"freeway embankment: %s skin follows it with the same transform" % bank_name)

func test_freeway_f11_bank_footprints_are_clear() -> void:
	var freeway := _freeway_structure()
	var blockers: Array[Dictionary] = _solid_prop_rects(freeway)
	for child in freeway.get_children():
		var source := String(child.scene_file_path).get_file()
		if not child is JumpPad \
				and source not in ["health_station.tscn", "ammo_pickup.tscn"]:
			continue
		var rects: Array[Rect2] = []
		_collect_shape_rects(child, rects)
		for rect in rects:
			blockers.append({"name": child.name, "rect": rect})

	for bank_name: StringName in Plan.BANKS:
		var bank: Rect2 = Plan.rect_of(Plan.BANKS, bank_name)
		for wall_name: StringName in Plan.WALLS:
			t.check(not bank.intersects(Plan.rect_of(Plan.WALLS, wall_name)),
				"freeway embankment: %s stays outside kept wall %s" %
					[bank_name, wall_name])
		for ramp_name: StringName in Plan.RAMPS:
			t.check(not bank.intersects(Plan.rect_of(Plan.RAMPS, ramp_name)),
				"freeway embankment: %s stays outside grade %s" %
					[bank_name, ramp_name])
		for shelf_name: StringName in F4_FLOOR_ZONES:
			t.check(not bank.intersects(Plan.rect_of(Plan.FLOOR_ZONES, shelf_name)),
				"freeway embankment: %s stays outside shelf %s" %
					[bank_name, shelf_name])
		for blocker: Dictionary in blockers:
			t.check(not bank.intersects(blocker["rect"]),
				"freeway embankment: %s stays outside %s" %
					[bank_name, blocker["name"]])

func test_freeway_f11_removed_retaining_nodes_are_gone() -> void:
	var freeway := _freeway_structure()
	var removed := [
		&"RetainE_1", &"RetainE_2", &"RetainE_3", &"RetainE_4",
		&"RetainE_1Shadow", &"RetainE_2Shadow", &"RetainE_3Shadow",
		&"RetainE_4Shadow", &"ChamferNE", &"ChamferAN", &"ChamferAS",
		&"ChamferSE", &"ConPlateDownS",
	]
	for node_name: StringName in removed:
		t.check(freeway.get_node_or_null(NodePath(node_name)) == null,
			"freeway embankment: removed node %s stays gone" % node_name)

func test_freeway_f11_bank_connector_pairs_match_plan() -> void:
	var freeway := _freeway_structure()
	var pairs := {
		&"ConBankNE": {"bank": &"BankNE", "position": Vector2(1216, -2508)},
		&"ConBankN": {"bank": &"BankN", "position": Vector2(1216, -1116)},
		&"ConBankMid": {"bank": &"BankMid", "position": Vector2(1216, -420)},
		&"ConBankS1": {"bank": &"BankS", "position": Vector2(1216, 1024)},
		&"ConBankS2": {"bank": &"BankS", "position": Vector2(1216, 1740)},
		&"ConBankS3": {"bank": &"BankS", "position": Vector2(1216, 2432)},
	}
	for pair_name: StringName in pairs:
		var cfg: Dictionary = pairs[pair_name]
		var bank: Rect2 = Plan.rect_of(Plan.BANKS, cfg["bank"])
		for suffix in [&"Up", &"Down"]:
			var connector_name := StringName("%s%s" % [pair_name, suffix])
			var connector := freeway.get_node_or_null(
				NodePath(connector_name)) as FloorConnector
			var is_up: bool = suffix == &"Up"
			var from_floor := 1 if is_up else 2
			var to_floor := 2 if is_up else 1
			var approach := Vector2.LEFT if is_up else Vector2.RIGHT
			t.check(connector != null, "freeway embankment: %s exists" % connector_name)
			if connector == null:
				continue
			t.check(connector.position == cfg["position"]
					and connector.from_floor == from_floor
					and connector.to_floor == to_floor,
				"freeway embankment: %s has its signed-off centre and floors" %
					connector_name)
			t.check(connector.kind == &"grade"
					and connector.approach_dir == approach,
				"freeway embankment: %s has its signed-off grade approach" %
					connector_name)
			t.check(_has_point_inclusive(bank, connector.position),
				"freeway embankment: %s lies inside %s" %
					[connector_name, cfg["bank"]])

func test_freeway_floor_stamps_and_counts() -> void:
	var freeway := _freeway_structure()
	var nodes: Array = []
	_walk(freeway, nodes)
	var pad_floors := {&"JumpW": 2, &"JumpE": 2, &"JumpLowland": 1}
	var counts := {
		"deck_rails": 0, "highway_rails": 0, "debris": 0, "clutter": 0, "wrecks": 0,
		"pillars": 0, "stations": 0, "pickups": 0, "pads": 0,
		"cars": 0, "rivals": 0,
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
			t.check(pad_floors.has(node.name),
				"freeway: %s is one of the three signed-off jump pads" % node.name)
			if pad_floors.has(node.name):
				t.check(node.floor_index == int(pad_floors[node.name]),
					"freeway: %s jump pad is on floor %d" %
						[node.name, pad_floors[node.name]])
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
				if node.get("deco") == &"rail":
					if node.floor_index == 3:
						counts.deck_rails += 1
					else:
						counts.highway_rails += 1
						t.check(node.floor_index == 2
								and is_equal_approx(node.max_hp, 20.0)
								and int(node.arena_net_id) == 0,
							"freeway: %s is a 20 HP floor-2 highway rail with no ID" % node.name)
				elif String(node.name).begins_with("Debris"):
					counts.debris += 1
				elif node.get("deco") == &"pillar":
					counts.pillars += 1
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
				var expected_floor := 3 if node.name == &"AmmoHoming1" \
					else (1 if node.name == &"AmmoPower3" else -1)
				t.check(node.floor_index == expected_floor,
					"freeway: %s pickup uses its signed-off floor" % node.name)

	t.check(counts.deck_rails == Plan.RAILS.size(),
		"freeway: %d planned deck rails (got %d)" % [Plan.RAILS.size(), counts.deck_rails])
	t.check(counts.highway_rails == 12,
		"freeway: 12 original highway rails (got %d)" % counts.highway_rails)
	t.check(counts.debris == 4, "freeway: 4 debris blocks (got %d)" % counts.debris)
	t.check(counts.pillars == 4, "freeway: 4 overpass pillars (got %d)" % counts.pillars)
	t.check(counts.clutter == 22, "freeway: 22 clutter props (got %d)" % counts.clutter)
	t.check(counts.wrecks == 2, "freeway: 2 wrecks (got %d)" % counts.wrecks)
	t.check(counts.stations == 3, "freeway: 3 stations (got %d)" % counts.stations)
	t.check(counts.pickups == 11, "freeway: 11 ammo pickups (got %d)" % counts.pickups)
	t.check(counts.pads == 3, "freeway: 3 jump pads (got %d)" % counts.pads)
	t.check(counts.cars == 8, "freeway: 8 cars (got %d)" % counts.cars)
	t.check(counts.rivals == 7, "freeway: 7 rivals (got %d)" % counts.rivals)
	t.check(floor_zones == Plan.FLOOR_ZONES.size(),
		"freeway: every planned floor zone is live")

func test_freeway_jump_pad_construction_and_footprints_are_clear() -> void:
	var freeway := _freeway_structure()
	var expected := {
		&"JumpW": {"position": Vector2(-640, -1280), "floor": 2},
		&"JumpE": {"position": Vector2(640, -256), "floor": 2},
		&"JumpLowland": {"position": Plan.JUMP_LOWLAND, "floor": 1},
	}
	var pads: Array[JumpPad] = []
	var blockers: Array[Node] = []
	for child in freeway.get_children():
		var source := String(child.scene_file_path).get_file()
		if child is JumpPad:
			pads.append(child)
		elif (child is StaticBody2D and child.collision_layer != 0) \
				or source in ["health_station.tscn", "ammo_pickup.tscn"]:
			blockers.append(child)
	t.check(pads.size() == expected.size(),
		"freeway: exactly three jump pads have clear footprints")
	for pad in pads:
		var cfg: Dictionary = expected.get(pad.name, {})
		t.check(not cfg.is_empty(), "freeway: %s is a signed-off jump pad" % pad.name)
		if cfg.is_empty():
			continue
		var collision := pad.get_node_or_null(^"Col") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D if collision else null
		t.check(pad.position == cfg["position"] and pad.floor_index == int(cfg["floor"]),
			"freeway: %s has its signed-off centre and floor" % pad.name)
		t.check(rectangle != null and rectangle.size == Vector2(224, 224),
			"freeway: %s uses the game-wide 224px square collision" % pad.name)
		var pad_rects: Array[Rect2] = []
		_collect_shape_rects(pad, pad_rects)
		for blocker in blockers:
			var blocker_rects: Array[Rect2] = []
			_collect_shape_rects(blocker, blocker_rects)
			for pad_rect in pad_rects:
				for blocker_rect in blocker_rects:
					t.check(not pad_rect.intersects(blocker_rect),
						"freeway: %s does not overlap %s" % [pad.name, blocker.name])

func test_freeway_scene_plate_matches_plan() -> void:
	var freeway := _freeway_structure()
	var plate := freeway.get_node_or_null(^"FZPlate") as FloorZone
	t.check(plate != null, "freeway: FZPlate exists")
	if plate:
		var actual := Rect2(plate.position - plate.size * 0.5, plate.size)
		t.check(plate.floor_index == int(Plan.FLOOR_ZONES[&"FZPlate"]["floor"]),
			"freeway: FZPlate floor matches the plan")
		t.check(actual == Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate"),
			"freeway: FZPlate rectangle matches the plan")

func test_freeway_arena_shell_matches_plan() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_boundary_encloses_arena_only() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_lowland_matches_plan() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_truck_stop_surfaces_match_plan() -> void:
	var freeway := _freeway_structure()
	var asphalt := freeway.get_node(^"Asphalt") as Polygon2D
	for road_name: StringName in Plan.TRUCK_STOP:
		var road := freeway.get_node_or_null(NodePath(road_name)) as Area2D
		var expected: Rect2 = Plan.TRUCK_STOP[road_name]
		t.check(road != null, "freeway truck stop: %s exists" % road_name)
		if road == null:
			continue
		var collision := road.get_node_or_null(^"Col") as CollisionShape2D
		var vis := road.get_node_or_null(^"Vis") as Polygon2D
		t.check(road.get("terrain_type") == &"road"
				and int(road.get("terrain_priority")) == 10,
			"freeway truck stop: %s is priority-10 road" % road_name)
		t.check(collision != null and _collision_rect(road, collision) == expected,
			"freeway truck stop: %s rectangle matches the plan" % road_name)
		t.check(vis != null and vis.material == asphalt.material,
			"freeway truck stop: %s uses SM_asphalt" % road_name)

	var dirt := freeway.get_node(^"LowlandDirt")
	var lot := freeway.get_node(^"TruckStopLot")
	var frontage := freeway.get_node(^"FrontageRoad")
	var pasture := freeway.get_node(^"Pasture")
	var field := freeway.get_node(^"Field")
	var marks := freeway.get_node_or_null(^"LotMarks") as Node2D
	t.check(lot.get_index() == dirt.get_index() + 1
			and frontage.get_index() == lot.get_index() + 1,
		"freeway truck stop: lot and frontage follow LowlandDirt")
	t.check(marks != null and pasture.get_index() == frontage.get_index() + 1
			and field.get_index() == pasture.get_index() + 1
			and marks.get_index() == field.get_index() + 1,
		"freeway truck stop: Pasture, Field, and LotMarks follow both road zones")
	if marks:
		t.check(marks.position == Vector2(1832, 1950)
				and marks.get("kind") == &"lot_marks"
				and marks.get("size") == Vector2(336, 200),
			"freeway truck stop: parking marks match the signed-off rectangle")

func test_freeway_f9_farm_matches_layout() -> void:
	var freeway := _freeway_structure()
	var frontage := freeway.get_node(^"FrontageRoad")
	var pasture := freeway.get_node(^"Pasture")
	var field := freeway.get_node_or_null(^"Field") as Node2D
	var marks := freeway.get_node(^"LotMarks")
	t.check(field != null, "freeway farm: Field exists")
	if field:
		var field_rect := Rect2(field.position - (field.get("size") as Vector2) * 0.5,
			field.get("size"))
		t.check(field_rect == Plan.FARM_FIELD and field.get("kind") == &"crop_rows"
				and field.z_index == 0,
			"freeway farm: Field matches the planned crop-row paint")
		t.check(pasture.get_index() == frontage.get_index() + 1
				and field.get_index() == pasture.get_index() + 1
				and marks.get_index() == field.get_index() + 1,
			"freeway farm: Pasture and Field follow the lot roads before LotMarks")

	for node_name: StringName in FARM_BLOCKS:
		var cfg: Dictionary = FARM_BLOCKS[node_name]
		var block := freeway.get_node_or_null(NodePath(node_name)) as Node2D
		t.check(block != null, "freeway farm: %s exists" % node_name)
		if block == null:
			continue
		t.check(String(block.scene_file_path).ends_with("destructible_block.tscn"),
			"freeway farm: %s uses DestructibleBlock" % node_name)
		t.check(block.position == cfg["position"] and block.get("size") == cfg["size"],
			"freeway farm: %s position and size match" % node_name)
		t.check(block.get("deco") == cfg["deco"] and block.get("floor_index") == 1
				and is_equal_approx(float(block.get("max_hp")), float(cfg["hp"])),
			"freeway farm: %s style, floor, and HP match" % node_name)
		t.check(int(block.get("arena_net_id")) == 0,
			"freeway farm: %s stays local destruction" % node_name)
		if String(node_name).begins_with("Hay"):
			t.check(Plan.FARM_FIELD.encloses(_block_rect(block)),
				"freeway farm: %s sits inside FARM_FIELD" % node_name)
		elif String(node_name).begins_with("Fence"):
			t.check(not Plan.FARM_FIELD.intersects(_block_rect(block)),
				"freeway farm: %s runs outside the field's south edge" % node_name)

	var power := freeway.get_node_or_null(^"AmmoPower3") as Area2D
	t.check(power != null and power.position == Vector2(2560, -2560)
			and power.get("kind") == "power" and power.get("floor_index") == 1,
		"freeway farm: AmmoPower3 is the floor-1 power pickup behind the barn")

func test_freeway_f10_pasture_matches_plan_and_draw_order() -> void:
	var freeway := _freeway_structure()
	var pasture := freeway.get_node_or_null(^"Pasture") as Area2D
	var infield := freeway.get_node(^"InfieldN") as Area2D
	var frontage := freeway.get_node(^"FrontageRoad")
	var field := freeway.get_node(^"Field")
	var marks := freeway.get_node(^"LotMarks")
	t.check(pasture != null, "freeway pasture: Pasture exists")
	if pasture == null:
		return
	var collision := pasture.get_node_or_null(^"Col") as CollisionShape2D
	var vis := pasture.get_node_or_null(^"Vis") as Polygon2D
	var infield_vis := infield.get_node(^"Vis") as Polygon2D
	var shoulder_vis := freeway.get_node(^"ShoulderW/Vis") as Polygon2D
	t.check(pasture.get_script() == infield.get_script()
			and pasture.get("terrain_type") == &"grass"
			and int(pasture.get("terrain_priority")) == 5
			and bool(pasture.get("soften_visual")),
		"freeway pasture: grass terrain matches InfieldN at priority 5")
	t.check(collision != null and _collision_rect(pasture, collision) == Plan.PASTURE,
		"freeway pasture: collision rectangle matches PASTURE")
	t.check(vis != null and vis.material == infield_vis.material
			and vis.material == shoulder_vis.material
			and vis.color == infield_vis.color,
		"freeway pasture: visual shares the shoulder and infield grass treatment")
	t.check(frontage.get_index() + 1 == pasture.get_index()
			and pasture.get_index() + 1 == field.get_index()
			and field.get_index() + 1 == marks.get_index(),
		"freeway pasture: draw order is FrontageRoad -> Pasture -> Field -> LotMarks")
	t.check(not Plan.PASTURE.intersects(Plan.COUNTRY_ROAD),
		"freeway pasture: grass does not overlap the country road")
	for ramp_name: StringName in Plan.RAMPS:
		t.check(not Plan.PASTURE.intersects(Plan.rect_of(Plan.RAMPS, ramp_name)),
			"freeway pasture: grass does not overlap grade %s" % ramp_name)
	var north_shelf := Plan.rect_of(Plan.FLOOR_ZONES, &"FZShelfN")
	t.check(not Plan.PASTURE.intersects(north_shelf),
		"freeway pasture: grass does not overlap the north shelf")

func test_freeway_f10_population_authorship() -> void:
	var freeway := _freeway_structure()
	var life := freeway.get_node_or_null(^"AmbientLife")
	t.check(life != null, "freeway ambient: AmbientLife exists")
	if life == null:
		return
	var expected := {
		&"Truckers": {
			"position": Vector2(2375, 1325), "kind": &"dock_worker", "count": 5,
			"movement": AmbientActor.Movement.WANDER, "bounds": Vector2(1050, 550),
		},
		&"Clerks": {
			"position": Vector2(2400, 630), "kind": &"vendor", "count": 2,
			"movement": AmbientActor.Movement.STATIONARY, "bounds": Vector2(200, 0),
		},
		&"LotDog": {
			"position": Vector2(2400, 1250), "kind": &"dog", "count": 1,
			"movement": AmbientActor.Movement.WANDER, "bounds": Vector2(1100, 1700),
		},
		&"Hitchhiker": {
			"position": Vector2(1400, -1470), "kind": &"vagrant", "count": 1,
			"movement": AmbientActor.Movement.STATIONARY, "bounds": Vector2.ZERO,
		},
		&"FarmHands": {
			"position": Plan.FARM_FIELD.get_center(), "kind": &"construction_worker",
			"count": 2, "movement": AmbientActor.Movement.WANDER,
			"bounds": Plan.FARM_FIELD.size,
		},
	}
	var total := 0
	var seeds := {}
	t.check(life.get_child_count() == expected.size(),
		"freeway ambient: exactly five populations are authored")
	for population_name: StringName in expected:
		var cfg: Dictionary = expected[population_name]
		var population := life.get_node_or_null(NodePath(population_name)) as AmbientPopulation
		t.check(population != null, "freeway ambient: %s exists" % population_name)
		if population == null:
			continue
		total += population.count
		seeds[population.seed_offset] = true
		t.check(population.position == cfg["position"] and population.bounds == cfg["bounds"],
			"freeway ambient: %s position and bounds match" % population_name)
		t.check(population.kinds.size() == 1 and population.kinds[0] == cfg["kind"]
				and population.count == int(cfg["count"]),
			"freeway ambient: %s kind and count match" % population_name)
		t.check(population.movement == int(cfg["movement"])
				and population.floor_index == 1,
			"freeway ambient: %s movement and floor match" % population_name)
	t.check(total == 11, "freeway ambient: five populations total 11 actors")
	t.check(seeds.size() == expected.size() and not seeds.has(0),
		"freeway ambient: every population has a distinct seed offset")
	var clerks := life.get_node(^"Clerks") as AmbientPopulation
	var clerk_points := [
		clerks.position - Vector2(clerks.bounds.x * 0.5, 0),
		clerks.position + Vector2(clerks.bounds.x * 0.5, 0),
	]
	t.check(clerk_points == [Vector2(2300, 630), Vector2(2500, 630)],
		"freeway ambient: clerk station line has the two signed-off endpoints")
	var hitchhiker := life.get_node(^"Hitchhiker") as AmbientPopulation
	var ramp_center := Plan.rect_of(Plan.RAMPS, &"RampN").get_center()
	var facing := Vector2.RIGHT.rotated(hitchhiker.rotation)
	t.check(facing.dot(hitchhiker.position.direction_to(ramp_center)) > 0.9,
		"freeway ambient: Hitchhiker faces RampN")

func test_freeway_f10_ambient_zones_and_stationary_clearances() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	t.root.add_child(freeway)
	var life := freeway.get_node(^"AmbientLife")
	var lowland := Plan.rect_of(Plan.FLOOR_ZONES, &"FZLowland")
	for population_name: StringName in [&"Truckers", &"LotDog", &"FarmHands"]:
		var population := life.get_node(NodePath(population_name)) as AmbientPopulation
		var zone := Rect2(population.position - population.bounds * 0.5, population.bounds)
		t.check(lowland.encloses(zone),
			"freeway ambient: %s wander zone stays inside FZLowland" % population_name)
		t.check(not zone.intersects(LOWLAND_PAD_RUNUP),
			"freeway ambient: %s wander zone avoids the lowland-pad run-up" %
				population_name)
		for ramp_name: StringName in Plan.RAMPS:
			t.check(not zone.intersects(Plan.rect_of(Plan.RAMPS, ramp_name)),
				"freeway ambient: %s wander zone avoids grade %s" %
					[population_name, ramp_name])

	var stationary := {
		&"ClerkW": Vector2(2300, 630),
		&"ClerkE": Vector2(2500, 630),
		&"Hitchhiker": Vector2(1400, -1470),
	}
	var solid_props := _solid_prop_rects(freeway)
	for figure_name: StringName in stationary:
		var point: Vector2 = stationary[figure_name]
		t.check(lowland.has_point(point),
			"freeway ambient: %s station lies inside FZLowland" % figure_name)
		t.check(_point_rect_distance(point, LOWLAND_PAD_RUNUP) >= 48.0,
			"freeway ambient: %s is 48px clear of the lowland-pad run-up" % figure_name)
		for ramp_name: StringName in Plan.RAMPS:
			var grade := Plan.rect_of(Plan.RAMPS, ramp_name)
			t.check(_point_rect_distance(point, grade) >= 48.0,
				"freeway ambient: %s is 48px clear of grade %s" %
					[figure_name, ramp_name])
		for prop: Dictionary in solid_props:
			t.check(_point_rect_distance(point, prop["rect"]) >= 48.0,
				"freeway ambient: %s is 48px clear of solid %s" %
					[figure_name, prop["name"]])
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_f10_live_ambient_actors_are_safe_noncombatants() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	t.root.add_child(freeway)
	t.current_scene = freeway
	for i in 4:
		await t.physics_frame
	var lowland := Plan.rect_of(Plan.FLOOR_ZONES, &"FZLowland")
	var solid_props := _solid_prop_rects(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var actors: Array[AmbientActor] = []
	for population in freeway.get_node(^"AmbientLife").get_children():
		for child in population.get_children():
			if child is AmbientActor:
				actors.append(child)
	t.check(actors.size() == 11,
		"freeway ambient: all 11 actors enter the live scene tree")
	for actor in actors:
		t.check(actor.is_inside_tree() and lowland.has_point(actor.global_position),
			"freeway ambient: %s is live inside FZLowland" % actor.kind)
		for prop: Dictionary in solid_props:
			t.check(not _has_point_inclusive(prop["rect"], actor.global_position),
				"freeway ambient: %s spawned outside solid %s" %
					[actor.kind, prop["name"]])
		var combat_group := actor.is_in_group(&"vehicles") or actor.is_in_group(&"enemies") \
			or actor.is_in_group(&"player") or actor.is_in_group(&"local_player") \
			or actor.is_in_group(&"dummies") or actor.is_in_group(&"targets")
		t.check(not combat_group, "freeway ambient: %s joins no combat group" % actor.kind)
		t.check(actor.collision_layer == AmbientActor.SOFT_TARGET_LAYER
				and actor.collision_mask == 1
				and (actor.collision_layer & (1 | 2 | 4 | FLOOR_BITS)) == 0
				and (player.collision_mask & actor.collision_layer) == 0,
			"freeway ambient: %s uses only the nonblocking soft-target layer" % actor.kind)
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_f9_farm_clearances() -> void:
	var freeway := _freeway_structure()
	var farm_solids: Array[Node2D] = []
	for node_name: StringName in FARM_BLOCKS:
		var solid := freeway.get_node_or_null(NodePath(node_name)) as Node2D
		if solid:
			farm_solids.append(solid)
	for solid in farm_solids:
		var solid_rect := _block_rect(solid)
		for child in freeway.get_children():
			if child is Vehicle:
				var clearance := _point_rect_distance(child.position, solid_rect)
				t.check(clearance >= 256.0,
					"freeway farm: %s is %.0fpx clear of spawn %s" %
						[solid.name, clearance, child.name])
			if String(child.scene_file_path).get_file() == "ammo_pickup.tscn":
				var clearance := _point_rect_distance(child.position, solid_rect)
				t.check(clearance >= 96.0,
					"freeway farm: %s is %.0fpx clear of pickup %s" %
						[solid.name, clearance, child.name])
		for child in freeway.get_children():
			if child is Ramp:
				var grade_rect := _rotated_rect(child.position, child.size, child.rotation)
				var clearance := _rect_distance(solid_rect, grade_rect)
				t.check(clearance >= 64.0,
					"freeway farm: %s is %.0fpx clear of grade %s" %
						[solid.name, clearance, child.name])

		var shelf := freeway.get_node(^"FZShelfN") as FloorZone
		var shelf_rect := Rect2(shelf.position - shelf.size * 0.5, shelf.size)
		var road := freeway.get_node(^"CountryRoad") as Area2D
		var road_rect := _collision_rect(road, road.get_node(^"Col"))
		t.check(_rect_distance(solid_rect, shelf_rect) >= 64.0,
			"freeway farm: %s stays 64px clear of the north shelf" % solid.name)
		t.check(_rect_distance(solid_rect, road_rect) >= 64.0,
			"freeway farm: %s stays 64px clear of the country road" % solid.name)

	for i in farm_solids.size():
		for j in range(i + 1, farm_solids.size()):
			var gap := _rect_distance(_block_rect(farm_solids[i]), _block_rect(farm_solids[j]))
			t.check(gap <= 24.0 or gap >= 96.0,
				"freeway farm: %s and %s leave a safe %.0fpx gap" %
					[farm_solids[i].name, farm_solids[j].name, gap])
	# The arena boundary is a solid too: a prop parked 60px off the east wall
	# is a wedge pocket like any other.
	for solid in farm_solids:
		var r := _block_rect(solid)
		var to_wall := minf(minf(r.position.x - Plan.ARENA_RECT.position.x,
			Plan.ARENA_RECT.end.x - r.end.x), minf(r.position.y - Plan.ARENA_RECT.position.y,
			Plan.ARENA_RECT.end.y - r.end.y))
		t.check(to_wall <= 24.0 or to_wall >= 96.0,
			"freeway farm: %s leaves a safe %.0fpx gap to the arena wall" % [solid.name, to_wall])

func test_freeway_truck_stop_props_match_layout() -> void:
	var freeway := _freeway_structure()
	for node_name: StringName in TRUCK_STOP_BLOCKS:
		var cfg: Dictionary = TRUCK_STOP_BLOCKS[node_name]
		var block := freeway.get_node_or_null(NodePath(node_name))
		t.check(block != null, "freeway truck stop: %s exists" % node_name)
		if block == null:
			continue
		t.check(String(block.scene_file_path).ends_with("destructible_block.tscn"),
			"freeway truck stop: %s uses DestructibleBlock" % node_name)
		t.check(block.position == cfg["position"] and block.get("size") == cfg["size"],
			"freeway truck stop: %s position and size match" % node_name)
		t.check(block.get("deco") == cfg["deco"]
				and block.get("floor_index") == 1
				and is_equal_approx(float(block.get("max_hp")), float(cfg["hp"])),
			"freeway truck stop: %s style, floor, and HP match" % node_name)
		if cfg.has("front"):
			t.check(block.get("front") == cfg["front"],
				"freeway truck stop: %s front faces %s" % [node_name, cfg["front"]])
		if cfg.has("livery"):
			t.check(block.get("livery") == cfg["livery"],
				"freeway truck stop: %s uses livery %d" % [node_name, cfg["livery"]])

	var station := freeway.get_node_or_null(^"HealthStation2") as Area2D
	var enemy := freeway.get_node_or_null(^"Enemy7") as Vehicle
	var standard := freeway.get_node_or_null(^"AmmoStandard3") as Area2D
	var mine := freeway.get_node_or_null(^"AmmoMine2") as Area2D
	t.check(station != null and station.position == Vector2(2432, 2048),
		"freeway truck stop: HealthStation2 is centred in the garage bay")
	t.check(enemy != null and enemy.position == Vector2(1792, 1088)
			and enemy.start_floor == 1,
		"freeway truck stop: Enemy7 moves to the floor-1 lot spawn")
	t.check(standard != null and standard.position == Vector2(2048, 1300)
			and standard.get("kind") == "standard",
		"freeway truck stop: AmmoStandard3 supplies fire missiles")
	t.check(mine != null and mine.position == Vector2(2912, 2040)
			and mine.get("kind") == "mine" and mine.get("amount") == 2,
		"freeway truck stop: AmmoMine2 supplies two mines")

func test_freeway_truck_stop_signage_canopy_and_draw_order() -> void:
	var freeway := _freeway_structure()
	var store := freeway.get_node(^"Store")
	var band := store.get_node_or_null(^"Signage") as Node2D
	t.check(band != null, "freeway truck stop: Store owns its Signage child")
	if band:
		t.check(band.get_parent() == store and band.get("kind") == &"band",
			"freeway truck stop: Store signage is a band")
		t.check(band.position == Vector2(0, 96) and band.z_index == 0
				and band.get("size") == Vector2(340, 56)
				and band.get("text") == "HATE'S TRAVEL STOP",
			"freeway truck stop: Store band copy and placement match")

	var canopy := freeway.get_node_or_null(^"Canopy") as Node2D
	var pylon := freeway.get_node_or_null(^"PylonSign") as Node2D
	t.check(canopy != null and canopy.position == Vector2(2400, 864)
			and canopy.z_index == 1 and canopy.get("kind") == &"canopy"
			and canopy.get("size") == Vector2(512, 288),
		"freeway truck stop: Canopy matches its signed-off roof")
	t.check(pylon != null and pylon.position == Vector2(1760, 400)
			and pylon.z_index == 1 and pylon.get("kind") == &"pylon"
			and pylon.get("size") == Vector2(256, 200)
			and pylon.get("text") == "HATE'S"
			and pylon.get("sub_text") == "DIESEL 4.99",
		"freeway truck stop: PylonSign copy and placement match")
	if canopy == null or pylon == null:
		return
	for node_name: StringName in TRUCK_STOP_SOLIDS + [
			&"HealthStation2", &"AmmoStandard3", &"AmmoMine2",
		]:
		var prop := freeway.get_node(NodePath(node_name))
		t.check(prop.get_index() < canopy.get_index()
				and prop.get_index() < pylon.get_index(),
			"freeway truck stop: %s renders beneath overhead paint" % node_name)
	for child in freeway.get_children():
		if child is Vehicle:
			t.check(child.get_index() > canopy.get_index()
					and child.get_index() > pylon.get_index(),
				"freeway truck stop: %s renders above overhead paint" % child.name)

func test_freeway_f9_billboard_shadow_clutter_and_draw_order() -> void:
	var freeway := _freeway_structure()
	var billboard := freeway.get_node_or_null(^"Billboard") as Signage
	t.check(billboard != null, "freeway farm: Billboard exists as Signage")
	if billboard:
		t.check(billboard.position == Vector2(1650, -1700) and billboard.z_index == 1
				and billboard.kind == &"billboard" and billboard.size == Vector2(448, 160),
			"freeway farm: Billboard placement, size, kind, and depth match")
		t.check(billboard.text == "HATE'S TRAVEL STOP" and billboard.sub_text == "NEXT EXIT"
				and billboard.dead_letters == 1
				and is_equal_approx(billboard.weathering, 0.6) and billboard.text_fits(),
			"freeway farm: Billboard copy and weathering fit the panel")
		for child in freeway.get_children():
			if child == billboard:
				continue
			var floor_value: Variant = child.get("floor_index")
			if floor_value is int and int(floor_value) == 1:
				t.check(child.get_index() < billboard.get_index(),
					"freeway farm: floor-1 prop %s renders before Billboard" % child.name)
			if child is Vehicle:
				t.check(child.get_index() > billboard.get_index(),
					"freeway farm: car %s renders after Billboard" % child.name)

	var marks := freeway.get_node(^"LotMarks")
	var shadow := freeway.get_node_or_null(^"CanopyShadow") as Node2D
	t.check(shadow != null, "freeway truck stop: CanopyShadow exists")
	if shadow:
		t.check(shadow.position == Vector2(2400, 864) and shadow.z_index == 0
				and shadow.get("kind") == &"overpass_shadow"
				and shadow.get("size") == Vector2(512, 288),
			"freeway truck stop: CanopyShadow matches the canopy footprint at z 0")
		t.check(shadow.get_index() == marks.get_index() + 1,
			"freeway truck stop: CanopyShadow draws immediately after LotMarks")

	var solids: Array[Node2D] = []
	for child in freeway.get_children():
		if String(child.scene_file_path).get_file() == "destructible_block.tscn":
			solids.append(child)
	var lot: Rect2 = Plan.TRUCK_STOP[&"TruckStopLot"]
	for node_name: StringName in LOT_CLUTTER:
		var cfg: Dictionary = LOT_CLUTTER[node_name]
		var clutter := freeway.get_node_or_null(NodePath(node_name)) as Node2D
		t.check(clutter != null, "freeway truck stop: %s exists" % node_name)
		if clutter == null:
			continue
		var footprint := Vector2.ONE * float(clutter.get("footprint"))
		var clutter_rect := Rect2(clutter.position - footprint * 0.5, footprint)
		t.check(String(clutter.scene_file_path).ends_with("clutter.tscn")
				and clutter.position == cfg["position"] and clutter.get("kind") == cfg["kind"]
				and clutter.get("floor_index") == 1,
			"freeway truck stop: %s kind, position, and floor match" % node_name)
		t.check(lot.encloses(clutter_rect),
			"freeway truck stop: %s sits inside TruckStopLot" % node_name)
		t.check(not clutter_rect.intersects(LOWLAND_PAD_RUNUP),
			"freeway truck stop: %s stays outside the lowland-pad run-up" % node_name)
		for solid in solids:
			t.check(not clutter_rect.intersects(_block_rect(solid)),
				"freeway truck stop: %s stays outside solid %s" % [node_name, solid.name])

func test_freeway_truck_stop_network_id_ledger() -> void:
	var freeway := _freeway_structure()
	var truck_stop_ids := {}
	for node_name: StringName in Plan.TRUCK_STOP_IDS:
		var node := freeway.get_node_or_null(NodePath(node_name))
		t.check(node != null, "freeway truck stop IDs: %s exists" % node_name)
		if node == null:
			continue
		var net_id := int(node.get("arena_net_id"))
		truck_stop_ids[node_name] = net_id
		t.check(net_id == int(Plan.TRUCK_STOP_IDS[node_name]),
			"freeway truck stop IDs: %s owns %d" % [node_name, net_id])
	t.check(truck_stop_ids == Plan.TRUCK_STOP_IDS,
		"freeway truck stop IDs: scene ledger exactly matches the plan")

	var nodes: Array = []
	_walk(freeway, nodes)
	var seen := {}
	var live_ids := 0
	var duplicate_ids := 0
	for node in nodes:
		var id_v: Variant = node.get("arena_net_id")
		if id_v == null or int(id_v) <= 0:
			continue
		live_ids += 1
		if seen.has(int(id_v)):
			duplicate_ids += 1
		seen[int(id_v)] = node.name
	t.check(duplicate_ids == 0 and seen.size() == live_ids,
		"freeway truck stop IDs: ledger is unique across the whole scene")
	t.check(live_ids == Plan.RAILS.size() + Plan.TRUCK_STOP_IDS.size(),
		"freeway truck stop IDs: only deck rails and truck-stop props are synced")

func test_freeway_truck_stop_clearances() -> void:
	var freeway := _freeway_structure()
	var solids := _truck_stop_solids(freeway)
	for child in freeway.get_children():
		if not child is Vehicle:
			continue
		for solid in solids:
			var clearance := _point_rect_distance(child.position, _block_rect(solid))
			t.check(clearance >= 256.0,
				"freeway truck stop: %s is %.0fpx clear of spawn %s" %
					[solid.name, clearance, child.name])

	for solid in solids:
		t.check(not _block_rect(solid).intersects(LOWLAND_PAD_RUNUP),
			"freeway truck stop: %s stays outside the lowland-pad run-up" % solid.name)

	for child in freeway.get_children():
		if String(child.scene_file_path).get_file() != "ammo_pickup.tscn":
			continue
		for solid in solids:
			var clearance := _point_rect_distance(child.position, _block_rect(solid))
			t.check(clearance >= 96.0,
				"freeway truck stop: %s is %.0fpx clear of pickup %s" %
					[solid.name, clearance, child.name])

	var west := freeway.get_node(^"GarageW")
	var east := freeway.get_node(^"GarageE")
	var station := freeway.get_node(^"HealthStation2") as Node2D
	var west_inner: float = west.position.x + (west.get("size") as Vector2).x * 0.5
	var east_inner: float = east.position.x - (east.get("size") as Vector2).x * 0.5
	t.check(is_equal_approx(east_inner - west_inner, 256.0)
			and is_equal_approx(station.position.x, (west_inner + east_inner) * 0.5),
		"freeway truck stop: garage bay is 256px wide with the station centred")
	t.check(is_equal_approx(station.position.x - west.position.x, 256.0)
			and is_equal_approx(east.position.x - station.position.x, 256.0),
		"freeway truck stop: station has equal 256px garage-side spacing")

func test_freeway_truck_stop_tanker_chain_reaction() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var tanker := freeway.get_node(^"Tanker")
	var diesel_pumps := [
		freeway.get_node(^"DieselPump1"),
		freeway.get_node(^"DieselPump2"),
	]
	var barrels := [
		freeway.get_node(^"Barrel1"),
		freeway.get_node(^"Barrel2"),
		freeway.get_node(^"Barrel3"),
	]
	var probe := BlastProbe.new()
	probe.position = tanker.position + Vector2(0, 300)
	freeway.add_child(probe)
	t.root.add_child(freeway)
	t.current_scene = freeway
	await t.physics_frame
	var probe_hp := probe.health.hp
	(tanker.get_node(^"Health") as Health).take_damage(999.0)
	var pumps_dead := false
	var barrel_dead := false
	for i in 60:
		await t.physics_frame
		pumps_dead = true
		for pump in diesel_pumps:
			pumps_dead = pumps_dead and (pump.get_node(^"Health") as Health).hp <= 0.0
		barrel_dead = false
		for barrel in barrels:
			barrel_dead = barrel_dead or (barrel.get_node(^"Health") as Health).hp <= 0.0
		if pumps_dead and barrel_dead:
			break
	t.check(pumps_dead,
		"freeway truck stop: tanker blast kills both diesel pumps within 60 frames")
	t.check(barrel_dead,
		"freeway truck stop: tanker blast starts the barrel chain within 60 frames")
	t.check(is_equal_approx(probe.health.hp, probe_hp),
		"freeway truck stop: a Health body 300px off the tanker flank is unhurt")
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_f4_floor_zones_and_ramps_match_plan() -> void:
	var freeway := _freeway_structure()
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
		# Sample past the helper's 8px tolerance: BankMid meets RampS exactly
		# along its low-end side edge, where both grade rectangles are valid.
		var half_length := ramp.size.y * 0.5 - 9.0
		var high_end := ramp.position + Vector2.UP.rotated(ramp.rotation) * half_length
		var low_end := ramp.position + Vector2.DOWN.rotated(ramp.rotation) * half_length
		t.check(_floor_at_structure(freeway, high_end) == ramp.high_floor,
			"freeway: %s high end lands on floor %d" % [ramp_name, ramp.high_floor])
		t.check(_floor_at_structure(freeway, low_end) == ramp.low_floor,
			"freeway: %s low end lands on floor %d" % [ramp_name, ramp.low_floor])

func test_freeway_f4_walls_match_plan() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_f4_shelf_roads_match_plan() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_f4_connectors_have_valid_approaches() -> void:
	var freeway := _freeway_structure()
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
	for connector_name: StringName in [&"ConPlateDownN"]:
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

func test_freeway_f5_landing_grade_and_walls_match_plan() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_f5_ramp_retrofit_structure() -> void:
	var freeway := _freeway_structure()
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

func test_freeway_f5_roads_shadows_and_removed_plugs() -> void:
	var freeway := _freeway_structure()
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

	for plug_name: StringName in [&"TempLandingW", &"TempDeckGap"]:
		t.check(freeway.get_node_or_null(NodePath(plug_name)) == null,
			"freeway: %s is removed for the live overpass" % plug_name)

func test_freeway_f6_deck_grades_and_walls_match_plan() -> void:
	var freeway := _freeway_structure()
	var deck_cfg: Dictionary = Plan.FLOOR_ZONES[&"FZDeck"]
	var deck := freeway.get_node_or_null(^"FZDeck") as FloorZone
	t.check(deck != null, "freeway: FZDeck exists")
	if deck:
		var actual := Rect2(deck.position - deck.size * 0.5, deck.size)
		t.check(deck.floor_index == int(deck_cfg["floor"])
				and actual == deck_cfg["rect"],
			"freeway: FZDeck matches the floor-3 plan rectangle")

	for ramp_name: StringName in F6_RAMPS:
		var ramp := freeway.get_node_or_null(NodePath(ramp_name)) as Ramp
		var cfg: Dictionary = Plan.RAMPS[ramp_name]
		var rect: Rect2 = cfg["rect"]
		var toward := _toward_vector(cfg["toward"])
		var expected_size := rect.size if toward.y != 0.0 \
			else Vector2(rect.size.y, rect.size.x)
		t.check(ramp != null, "freeway: %s exists" % ramp_name)
		if ramp == null:
			continue
		t.check(ramp.position == rect.get_center() and ramp.size == expected_size,
			"freeway: %s uses its plan rectangle with length along local Y" % ramp_name)
		t.check(ramp.low_floor == int(cfg["low"])
				and ramp.high_floor == int(cfg["high"]),
			"freeway: %s climbs from floor 2 to floor 3" % ramp_name)
		t.check(ramp.terrain_type == "road"
				and is_equal_approx(ramp.downhill_pull, 120.0),
			"freeway: %s is a road grade with the standard pull" % ramp_name)
		t.check(ramp.rails == (ramp_name == &"RampW"),
			"freeway: only shoulder chokepoint RampW builds rails")
		var expected_rotation := toward.angle() + PI * 0.5
		t.check(absf(angle_difference(ramp.rotation, expected_rotation)) < 0.001,
			"freeway: %s high end faces %s" % [ramp_name, cfg["toward"]])

	for wall_name: StringName in F6_WALLS:
		var wall := freeway.get_node_or_null(NodePath(wall_name)) as StaticBody2D
		var cfg: Dictionary = Plan.WALLS[wall_name]
		t.check(wall != null, "freeway: %s exists" % wall_name)
		if wall == null:
			continue
		var collision := wall.get_node_or_null(^"Col") as CollisionShape2D
		t.check(wall.collision_layer == int(cfg["layer"])
				and wall.collision_mask == 0,
			"freeway: %s collision bits match the plan" % wall_name)
		t.check(collision != null and _collision_rect(wall, collision) == cfg["rect"],
			"freeway: %s rectangle matches the plan" % wall_name)
	for plug_name: StringName in [&"TempLandingW", &"TempDeckGap"]:
		t.check(freeway.get_node_or_null(NodePath(plug_name)) == null,
			"freeway: %s stays gone" % plug_name)

func test_freeway_f6_deck_rails_match_plan() -> void:
	var freeway := _freeway_structure()
	var nodes: Array = []
	_walk(freeway, nodes)
	var rails: Array = []
	var live_ids: Array[int] = []
	for node in nodes:
		var net_id: Variant = node.get("arena_net_id")
		if net_id is int and int(net_id) > 0:
			live_ids.append(int(net_id))
		if String(node.scene_file_path).get_file() == "destructible_block.tscn" \
				and node.get("deco") == &"rail" and node.floor_index == 3:
			rails.append(node)
	t.check(rails.size() == Plan.RAILS.size(),
		"freeway: scene deck-rail count matches the computed table")
	var rail_ids: Array[int] = []
	for rail in rails:
		var net_id := int(rail.get("arena_net_id"))
		var plan_index := net_id - 100
		rail_ids.append(net_id)
		t.check(plan_index >= 0 and plan_index < Plan.RAILS.size(),
			"freeway: %s has a planned ID" % rail.name)
		if plan_index < 0 or plan_index >= Plan.RAILS.size():
			continue
		var actual := Rect2(rail.position - rail.size * 0.5, rail.size)
		t.check(actual == Plan.RAILS[plan_index],
			"freeway: %s rectangle matches RAILS[%d]" % [rail.name, plan_index])
		t.check(rail.floor_index == 3 and rail.z_index == 2
				and is_equal_approx(rail.max_hp, 12.0),
			"freeway: %s is a 12 HP floor-3 breakaway rail" % rail.name)
	rail_ids.sort()
	for i in rail_ids.size():
		t.check(rail_ids[i] == 100 + i,
			"freeway: deck rail IDs are contiguous from 100")
	var unique_ids := {}
	for net_id in live_ids:
		unique_ids[net_id] = true
	t.check(unique_ids.size() == live_ids.size(),
		"freeway: deck rail network IDs collide with no scene ID")

	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	var west_opening := Rect2(deck.position,
		Vector2(Plan.rect_of(Plan.RAMPS, &"RampW").size.x, deck.size.y))
	var east_clear := Rect2(Vector2(deck.end.x - Plan.RAIL_BREAK_CLEARANCE,
		deck.position.y), Vector2(Plan.RAIL_BREAK_CLEARANCE, deck.size.y))
	var north: Array[Rect2] = []
	var south: Array[Rect2] = []
	for rail in Plan.RAILS:
		t.check(rail.size.y == Plan.RAIL_THICKNESS
				and rail.size.x <= Plan.RAIL_MAX_LENGTH,
			"freeway: planned rail is 12px thick and no longer than 256px")
		t.check(is_equal_approx(rail.get_center().y,
				deck.position.y + Plan.RAIL_INSET)
				or is_equal_approx(rail.get_center().y,
					deck.end.y - Plan.RAIL_INSET),
			"freeway: planned rail is centred 8px inside a deck edge")
		t.check(not rail.intersects(west_opening)
				or rail.get_center().y < deck.get_center().y,
			"freeway: RampW's 256px south-edge mouth stays open")
		t.check(not rail.intersects(east_clear),
			"freeway: rails stop 16px short of the east end")
		if rail.get_center().y < deck.get_center().y:
			north.append(rail)
		else:
			south.append(rail)
	for run in [north, south]:
		run.sort_custom(func(a: Rect2, b: Rect2) -> bool:
			return a.position.x < b.position.x)
		for i in range(1, run.size()):
			t.check(is_equal_approx(run[i].position.x - run[i - 1].end.x,
					Plan.RAIL_BREAK_CLEARANCE),
				"freeway: every deck rail break leaves 16px clearance")
	t.check(north.front().position.x == deck.position.x
			and south.front().position.x == west_opening.end.x,
		"freeway: rail runs begin at the north-west corner and after RampW")
	t.check(north.back().end.x == east_clear.position.x
			and south.back().end.x == east_clear.position.x,
		"freeway: both rail runs end at the east clearance")

func test_freeway_f6_retrofit_structure_and_connectors() -> void:
	var freeway := _freeway_structure()
	for ramp_name: StringName in F6_RAMPS:
		var ramp := freeway.get_node_or_null(NodePath(ramp_name)) as Ramp
		t.check(ramp != null, "freeway retrofit: %s exists" % ramp_name)
		if ramp == null:
			continue
		var half_len := ramp.size.y * 0.5
		var high_end := ramp.position + Vector2.UP.rotated(ramp.rotation) * half_len
		var low_end := ramp.position + Vector2.DOWN.rotated(ramp.rotation) * half_len
		t.check(_floor_at_structure(freeway, high_end) == ramp.high_floor,
			"freeway retrofit: %s high end reaches floor 3" % ramp_name)
		t.check(_floor_at_structure(freeway, low_end) == ramp.low_floor,
			"freeway retrofit: %s low end rests on floor 2" % ramp_name)

	var connectors := {
		&"ConRampAUp": {"position": Vector2(1280, -768), "from": 2, "to": 3,
			"approach": Vector2.LEFT, "kind": &"grade"},
		&"ConRampADown": {"position": Vector2(1280, -768), "from": 3, "to": 2,
			"approach": Vector2.RIGHT, "kind": &"grade"},
		&"ConRampWUp": {"position": Vector2(-960, -416), "from": 2, "to": 3,
			"approach": Vector2.UP, "kind": &"grade"},
		&"ConRampWDown": {"position": Vector2(-960, -416), "from": 3, "to": 2,
			"approach": Vector2.DOWN, "kind": &"grade"},
		&"ConDeckDownN": {"position": Vector2(0, -968), "from": 3, "to": 2,
			"approach": Vector2.UP, "kind": &"edge"},
		&"ConDeckDownS": {"position": Vector2(0, -568), "from": 3, "to": 2,
			"approach": Vector2.DOWN, "kind": &"edge"},
		&"ConDeckJump": {"position": Vector2(-640, -1280), "from": 2, "to": 3,
			"approach": Vector2.DOWN, "kind": &"jump"},
		&"ConDeckJumpE": {"position": Vector2(640, -256), "from": 2, "to": 3,
			"approach": Vector2.UP, "kind": &"jump"},
		&"ConLowlandJump": {"position": Plan.JUMP_LOWLAND, "from": 1, "to": 2,
			"approach": Vector2.LEFT, "kind": &"jump"},
	}
	for connector_name: StringName in connectors:
		var connector := freeway.get_node_or_null(NodePath(connector_name)) as FloorConnector
		var cfg: Dictionary = connectors[connector_name]
		t.check(connector != null, "freeway retrofit: %s exists" % connector_name)
		if connector == null:
			continue
		t.check(connector.position == cfg["position"]
				and connector.from_floor == int(cfg["from"])
				and connector.to_floor == int(cfg["to"]),
			"freeway retrofit: %s has the signed-off position and floors" % connector_name)
		t.check(connector.approach_dir == cfg["approach"]
				and connector.kind == cfg["kind"],
			"freeway retrofit: %s has the signed-off route kind" % connector_name)
		var entry := connector.position - connector.approach_dir * CONNECTOR_RUNUP
		t.check(_floor_at_structure(freeway, entry) == connector.from_floor,
			"freeway retrofit: %s approach run sits on floor %d" %
				[connector_name, connector.from_floor])
	var jump_connectors := 0
	for child in freeway.get_children():
		if child is FloorConnector and child.kind == &"jump":
			jump_connectors += 1
	t.check(jump_connectors == 3,
		"freeway retrofit: exactly three jump connectors are live")

func test_freeway_f6_pillars_paint_reward_and_draw_order() -> void:
	var freeway := _freeway_structure()
	var deck_rect := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	var shoulder_w := _collision_rect(freeway.get_node(^"ShoulderW"),
		freeway.get_node(^"ShoulderW/Col"))
	var shoulder_e := _collision_rect(freeway.get_node(^"ShoulderE"),
		freeway.get_node(^"ShoulderE/Col"))
	var infield := _collision_rect(freeway.get_node(^"InfieldN"),
		freeway.get_node(^"InfieldN/Col"))
	var lane_w := Rect2(Vector2(shoulder_w.end.x, deck_rect.position.y),
		Vector2(infield.position.x - shoulder_w.end.x, deck_rect.size.y))
	var lane_e := Rect2(Vector2(infield.end.x, deck_rect.position.y),
		Vector2(shoulder_e.position.x - infield.end.x, deck_rect.size.y))
	var lane_marks := [freeway.get_node(^"RoadMarks/LaneW"),
		freeway.get_node(^"RoadMarks/LaneE")]
	t.check((lane_marks[0].get("points") as PackedVector2Array)[0].x \
			== lane_w.get_center().x
			and (lane_marks[1].get("points") as PackedVector2Array)[0].x \
			== lane_e.get_center().x,
		"freeway: lane rectangles derive from their marks and infield edges")

	var expected_xs := [lane_w.position.x, lane_w.end.x, lane_e.position.x, lane_e.end.x]
	var pillars: Array = []
	for child in freeway.get_children():
		if child.get("deco") == &"pillar":
			pillars.append(child)
	t.check(pillars.size() == expected_xs.size(),
		"freeway: four destructible pillars support the deck")
	for i in mini(pillars.size(), expected_xs.size()):
		var pillar = pillars[i]
		var inside_lane := false
		for lane in [lane_w, lane_e]:
			inside_lane = inside_lane or (pillar.position.x > lane.position.x
				and pillar.position.x < lane.end.x)
		t.check(pillar.position == Vector2(expected_xs[i], deck_rect.get_center().y)
				and pillar.size == Vector2(64, 96),
			"freeway: %s stands at its signed-off lane edge" % pillar.name)
		t.check(not inside_lane and pillar.floor_index == 2
				and is_equal_approx(pillar.max_hp, 400.0),
			"freeway: %s is floor-2 cover outside the traffic lane" % pillar.name)

	var shadow := freeway.get_node_or_null(^"OverpassShadow") as Node2D
	var deck := freeway.get_node_or_null(^"OverpassDeck") as Node2D
	t.check(shadow != null and deck != null,
		"freeway: overpass shadow and deck paint exist")
	if shadow and deck:
		t.check(shadow.position == deck_rect.get_center() and shadow.get("size") == deck_rect.size
				and shadow.get("kind") == &"overpass_shadow" and shadow.z_index == 0,
			"freeway: OverpassShadow matches the deck at z 0")
		t.check(deck.position == deck_rect.get_center() and deck.get("size") == deck_rect.size
				and deck.get("kind") == &"overpass_deck" and deck.z_index == 1,
			"freeway: OverpassDeck matches the deck at z 1")
		for child in freeway.get_children():
			if child.get("floor_index") == 2:
				t.check(child.get_index() < deck.get_index(),
					"freeway: floor-2 prop %s renders before OverpassDeck" % child.name)
			if child is Vehicle or (child.get("deco") == &"rail"
					and child.get("floor_index") == 3):
				t.check(child.get_index() > deck.get_index(),
					"freeway: %s renders after OverpassDeck" % child.name)
	var reward := freeway.get_node_or_null(^"AmmoHoming1")
	t.check(reward != null and reward.position == Vector2(0, -704)
			and int(reward.get("floor_index")) == 3,
		"freeway: AmmoHoming1 is the floor-3 deck reward")
	var jump := freeway.get_node_or_null(^"JumpW") as JumpPad
	t.check(jump != null and jump.position == Vector2(-640, -1280)
			and jump.floor_index == 2,
		"freeway: JumpW launches south from its floor-2 run-up")

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

func test_freeway_frontage_road_reaches_the_lot_live() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	player.position = Vector2(2688, -500)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.DOWN.angle()
	player.velocity = Vector2.DOWN * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var stayed_low := true
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		var floor := Floors.floor_of(player)
		stayed_low = stayed_low and (floor < 1 or floor == 1)
		if player.position.y > Plan.TRUCK_STOP[&"TruckStopLot"].position.y:
			break
	t.check(stayed_low and player.position.y > 320.0,
		"freeway truck stop: southbound frontage-road car reaches the lot on floor 1 "
			+ "(floor %d at %s)" % [Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_live_car_drives_through_repair_garage() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var station := freeway.get_node(^"HealthStation2") as Node2D
	player.position = Vector2(2432, 2300)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.UP * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var passed_station := false
	var stayed_low := true
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		var floor := Floors.floor_of(player)
		stayed_low = stayed_low and (floor < 1 or floor == 1)
		passed_station = passed_station or player.position.y < station.position.y
		if player.position.y < 1900.0:
			break
	t.check(passed_station and stayed_low and player.position.y < 1900.0,
		"freeway truck stop: northbound car passes the repair station and exits the bay "
			+ "(floor %d at %s)" % [Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_jump_w_lands_southbound_on_deck() -> void:
	var result := await _simulate_pad_landing(&"JumpW", Vector2.DOWN, 2)
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	t.check(result.launched and result.landed and int(result.floor) == 3
			and _has_point_inclusive(deck, result.landing),
		"freeway: JumpW southbound lands on floor-3 FZDeck "
			+ "(launch %.1f, landing %s, floor %d)" %
				[result.launch_speed, result.landing, result.floor])

func test_freeway_jump_e_lands_northbound_on_deck() -> void:
	var result := await _simulate_pad_landing(&"JumpE", Vector2.UP, 2, true)
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	t.check(result.launched and result.landed and int(result.floor) == 3
			and _has_point_inclusive(deck, result.landing),
		"freeway: JumpE northbound lands on floor-3 FZDeck "
			+ "(launch %.1f, landing %s, floor %d)" %
				[result.launch_speed, result.landing, result.floor])
	var final_floor := int(result.drop_floor)
	var final_position: Vector2 = result.drop_position
	t.check(result.dropped and final_floor == 2 and final_position.y < deck.position.y,
		"freeway: floor-3 car breaks through the north edge and lands on floor 2 "
			+ "(floor %d at %s)" % [final_floor, final_position])

func test_freeway_lowland_jump_lands_westbound_clear_of_walls() -> void:
	var plate := Plan.rect_of(Plan.FLOOR_ZONES, &"FZPlate")
	var bank := Plan.rect_of(Plan.BANKS, &"BankS")
	for entry_speed: float in LOWLAND_JUMP_SPEEDS:
		var result := await _simulate_lowland_jump(entry_speed)
		var landing_on_grade_or_plate := _has_point_inclusive(plate, result.landing) \
			or _has_point_inclusive(bank, result.landing)
		t.check(result.launched and result.landed and result.landing.x < bank.end.x
				and landing_on_grade_or_plate and not result.on_wall,
			("freeway: %.0f px/s JumpLowland run launches and lands west of the bank "
				+ "clear of walls (landing %s, floor %d)") %
					[entry_speed, result.landing, result.landing_floor])
		t.check(result.floor_two_after_landing
				and int(result.frames_to_floor_two) <= 120,
			"freeway: %.0f px/s JumpLowland run reaches floor 2 within 120 frames "
				% entry_speed)

func test_freeway_north_grade_climbs_live_car_to_shelf() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var ramp := Plan.rect_of(Plan.RAMPS, &"RampN")
	var shelf := Plan.rect_of(Plan.FLOOR_ZONES, &"FZShelfN")
	player.position = Vector2(ramp.get_center().x, ramp.end.y + 96.0)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.UP * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var final_floor := Floors.floor_of(player)
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		final_floor = Floors.floor_of(player)
		if final_floor == 2 and _has_point_inclusive(shelf, player.position):
			break
	t.check(final_floor == 2 and _has_point_inclusive(shelf, player.position),
		"freeway: northbound lowland car climbs RampN onto floor-2 FZShelfN "
			+ "(floor %d at %s)" % [final_floor, player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_ramp_a_climbs_live_car_onto_deck() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	var ramp := Plan.rect_of(Plan.RAMPS, &"RampA")
	player.position = Vector2(ramp.end.x + 96.0, ramp.get_center().y)
	player.start_floor = 2
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.LEFT.angle()
	player.velocity = Vector2.LEFT * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var final_floor := Floors.floor_of(player)
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		final_floor = Floors.floor_of(player)
		if final_floor == 3 and _has_point_inclusive(deck, player.position):
			break
	t.check(final_floor == 3 and _has_point_inclusive(deck, player.position),
		"freeway: westbound landing car climbs RampA onto the floor-3 deck "
			+ "(floor %d at %s)" % [final_floor, player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_live_car_passes_under_deck_on_floor_two() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	player.position = Vector2(-640, deck.end.y + 96.0)
	player.start_floor = 2
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.UP * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var crossed_deck_xy := false
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		crossed_deck_xy = crossed_deck_xy or _has_point_inclusive(deck, player.position)
		if crossed_deck_xy and Floors.floor_of(player) == 2 \
				and player.position.y < deck.position.y:
			break
	t.check(crossed_deck_xy and Floors.floor_of(player) == 2
			and player.position.y < deck.position.y,
		"freeway: northbound highway car passes beneath the deck on floor 2 "
			+ "(floor %d at %s)" % [Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_ramp_w_climbs_live_car_onto_deck() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var deck := Plan.rect_of(Plan.FLOOR_ZONES, &"FZDeck")
	var ramp := Plan.rect_of(Plan.RAMPS, &"RampW")
	player.position = Vector2(ramp.get_center().x, ramp.end.y + 96.0)
	player.start_floor = 2
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.UP * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var final_floor := Floors.floor_of(player)
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		final_floor = Floors.floor_of(player)
		if final_floor == 3 and _has_point_inclusive(deck, player.position):
			break
	t.check(final_floor == 3 and _has_point_inclusive(deck, player.position),
		"freeway: northbound shoulder car climbs RampW onto the floor-3 deck "
			+ "(floor %d at %s)" % [final_floor, player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_landing_south_wall_holds_live_lowland_car() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var landing := Plan.rect_of(Plan.FLOOR_ZONES, &"FZLanding")
	var wall := Plan.rect_of(Plan.WALLS, &"LandingS")
	player.position = Vector2(landing.get_center().x, wall.end.y + 96.0)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.UP.angle()
	player.velocity = Vector2.UP * LIVE_ENTRY_SPEED
	player.set_driver(FullThrottleDriver.new())
	var entered_landing := false
	var best_y := player.position.y
	var stalled_frames := 0
	for i in LIVE_SIM_FRAMES:
		await t.physics_frame
		entered_landing = entered_landing or _has_point_inclusive(landing, player.position)
		if player.position.y < best_y - 1.0:
			best_y = player.position.y
			stalled_frames = 0
		else:
			stalled_frames += 1
		if player.position.y <= wall.end.y + 64.0 and not entered_landing \
				and Floors.floor_of(player) == 1 and stalled_frames >= 3:
			break
	t.check(not entered_landing and Floors.floor_of(player) == 1,
		"freeway: LandingS holds a northbound floor-1 car out of FZLanding "
			+ "(floor %d at %s)" % [Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_bank_s_climbs_live_car_to_plate() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	player.position = Vector2(1500, 1728)
	player.start_floor = 1
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.LEFT.angle()
	player.velocity = Vector2.LEFT * 300.0
	player.set_driver(FullThrottleDriver.new())
	var airborne := false
	for i in 180:
		await t.physics_frame
		airborne = airborne or player.height > 0.0 or not is_zero_approx(player.vz)
		if Floors.floor_of(player) == 2 and player.position.x < 1088.0:
			break
	t.check(Floors.floor_of(player) == 2 and player.position.x < 1088.0
			and not airborne,
		"freeway: westbound floor-1 car drives up BankS onto floor 2 "
			+ "without a hop (floor %d at %s)" %
				[Floors.floor_of(player), player.position])
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()

func test_freeway_bank_s_descends_live_car_to_lowland() -> void:
	var freeway := FreewayScene.instantiate()
	_remove_other_cars(freeway)
	var player := freeway.get_node(^"Vehicle") as Vehicle
	player.position = Vector2(1000, 1728)
	player.start_floor = 2
	t.root.add_child(freeway)
	t.current_scene = freeway
	player.heading = Vector2.RIGHT.angle()
	player.velocity = Vector2.RIGHT * 300.0
	player.set_driver(FullThrottleDriver.new())
	var airborne := false
	for i in 180:
		await t.physics_frame
		airborne = airborne or player.height > 0.0 or not is_zero_approx(player.vz)
		if Floors.floor_of(player) == 1 and player.position.x > 1344.0:
			break
	t.check(Floors.floor_of(player) == 1 and player.position.x > 1344.0
			and not airborne,
		"freeway: eastbound floor-2 car drives down BankS onto floor 1 "
			+ "without a hop (floor %d at %s)" %
				[Floors.floor_of(player), player.position])
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
		if Floors.floor_of(player) == 1:
			break
	t.check(Floors.floor_of(player) == 1,
		"freeway: a car spawned in the lowland adopts floor 1")
	t.current_scene = null
	t.root.remove_child(freeway)
	freeway.free()
	_free_freeway_structure()
