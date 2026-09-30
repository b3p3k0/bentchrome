extends RefCounted
## Freeway's floor-stamp staging contract: every future floor-masked solid is
## already assigned to the current highway (floor 2), while the absent FloorZone
## keeps today's live player on the legacy collision mask until the terrace lands.

const FreewayScene := preload("res://levels/freeway/freeway.tscn")
const Floors := preload("res://game/floors.gd")
const FLOOR_MID := 16

var t

func _init(runner) -> void:
	t = runner

func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)

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
	t.check(floor_zones == 0, "freeway: no FloorZone is added in the staging card")
	freeway.free()

func test_freeway_remains_live_legacy_until_floor_zones_arrive() -> void:
	var freeway := FreewayScene.instantiate()
	for child in freeway.get_children():
		if child is Vehicle and child.name != &"Vehicle":
			freeway.remove_child(child)
			child.free()
	var player := freeway.get_node(^"Vehicle") as Vehicle
	var rail := freeway.get_node(^"RailW1") as StaticBody2D
	t.root.add_child(freeway)
	player.set_driver(Driver.new())
	await t.physics_frame
	t.check(Floors.floor_of(player) == -1,
		"freeway: without a FloorZone the spawned player remains legacy")

	var health := rail.get_node(^"Health") as Health
	var start_hp := health.hp
	player.global_position = rail.global_position + Vector2(-130, 0)
	player.heading = 0.0
	player.velocity = Vector2(450, 0)
	for i in 30:
		await t.physics_frame
	t.check(health.hp < start_hp,
		"freeway: the legacy player still collides with and rams a floor-2 rail")
	t.root.remove_child(freeway)
	freeway.free()
