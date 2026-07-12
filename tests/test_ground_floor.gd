extends RefCounted
## Ground Floor Gore graybox: capacity, exact foundation fit, and complete
## three-floor route grammar before flavor content lands.

const ArenaScene := preload("res://levels/construction/ground_floor_gore.tscn")
const DeckScene := preload("res://environment/scaffold_deck.tscn")

var t

func _init(runner) -> void:
	t = runner

func test_profile_geometry_and_spawn_capacity() -> void:
	var arena := ArenaScene.instantiate()
	var foundation := arena.get_node(^"Foundation")
	t.check(foundation.position == Vector2(896, -640)
		and foundation.size == Vector2(2048, 1792),
		"ground floor: foundation owns the exact northeast footprint")
	var bounds := Rect2(foundation.position - foundation.size * 0.5, foundation.size)
	t.check(bounds.position == Vector2(-128, -1536) and bounds.end == Vector2(1920, 256),
		"ground floor: foundation bounds leave the promised alleys")
	t.check(2304.0 - bounds.end.x == 384.0 and bounds.position.y - (-1920.0) == 384.0,
		"ground floor: north/east racing alley is exactly 384px")

	var cars: Array[Vehicle] = []
	var floor_counts := {1: 0, 2: 0, 3: 0}
	for child in arena.get_children():
		if child is Vehicle:
			cars.append(child)
			floor_counts[int(child.start_floor)] += 1
	t.check(cars.size() == 8 and floor_counts == {1: 4, 2: 3, 3: 1},
		"ground floor: eight starts distribute 4/3/1 across floors")
	var separated := true
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			separated = separated and cars[i].position.distance_to(cars[j].position) >= 700.0
	t.check(separated, "ground floor: every baked start clears the 700px safety floor")
	arena.free()

func test_route_graph_and_surface_budget() -> void:
	var arena := ArenaScene.instantiate()
	var connectors := arena.get_node(^"FloorConnectors").get_children()
	var grades := 0
	var edges := 0
	var pairs := {}
	for connector in connectors:
		if connector.kind == &"grade":
			grades += 1
			pairs[Vector2i(connector.from_floor, connector.to_floor)] = true
		elif connector.kind == &"edge":
			edges += 1
	t.check(grades == 8 and edges == 2,
		"ground floor: four bidirectional grades plus two deliberate drops")
	for key in [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 3), Vector2i(3, 2)]:
		t.check(pairs.has(key), "ground floor: connector direction %s exists" % key)
	var mud := 0
	var water := 0
	for child in arena.get_children():
		if child is TerrainZone:
			mud += 1 if child.terrain_type == &"mud" else 0
			water += 1 if child.terrain_type == &"water" else 0
	t.check(mud == 3 and water == 2,
		"ground floor: three mud basins and two shallow puddles establish route choices")
	var station1 = arena.get_node(^"HealthStationFloor1")
	var station3 = arena.get_node(^"HealthStationFloor3")
	t.check(station1.floor_index == 1 and station3.floor_index == 3,
		"ground floor: both repair bays are explicitly floor stamped")
	arena.free()

func test_scaffold_primitive_builds_floor_terrain_and_unscaled_rails() -> void:
	var deck := DeckScene.instantiate() as ScaffoldDeck
	deck.size = Vector2(640, 448)
	deck.rail_edges = ScaffoldDeck.EDGE_TOP | ScaffoldDeck.EDGE_RIGHT
	t.root.add_child(deck)
	var floor := deck.get_node_or_null(^"Floor") as FloorZone
	var terrain := deck.get_node_or_null(^"Terrain") as TerrainZone
	var rails := deck.find_children("Rail*", "StaticBody2D", false, false)
	t.check(floor != null and floor.floor_index == 3 and floor.size == deck.size,
		"scaffold: deck owns its complete floor-3 footprint")
	t.check(terrain != null and terrain.terrain_type == &"road"
		and terrain.terrain_priority == Ramp.TERRAIN_PRIORITY,
		"scaffold: steel deck overrides broad dirt handling")
	t.check(rails.size() == 2, "scaffold: authored edge mask builds only selected rails")
	for rail in rails:
		t.check(rail.scale == Vector2.ONE and rail.collision_layer == (4 | 32),
			"scaffold: floor-3 rail is unscaled and floor-correct")
	t.root.remove_child(deck)
	deck.free()

func test_scene_readies_as_mp_geometry_without_campaign_actors() -> void:
	var arena := ArenaScene.instantiate()
	arena.mp_managed = true
	t.root.add_child(arena)
	await t.process_frame
	t.check(arena.mp_spawns.size() == 8,
		"ground floor: shared combat shell derives all eight MP starts")
	t.check(arena.get_node(^"Scaffold").get_child_count() == 10,
		"ground floor: scaffold network retains four platforms and six runs")
	t.root.remove_child(arena)
	arena.free()
