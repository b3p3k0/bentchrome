extends RefCounted
## Permanent boulder geometry, floor collision, radar classification, and
## terminal weapon contact.

const BoulderScript := preload("res://environment/boulder.gd")
const RadarScript := preload("res://ui/radar.gd")
const ProjectileScene := preload("res://weapons/projectile.tscn")

const SIZES := [Vector2(128, 128), Vector2(192, 128), Vector2(128, 256)]

var t

func _init(runner) -> void:
	t = runner

func _boulder(body_size := Vector2(128, 128), seed := 0, has_snow := true,
		floor := 2) -> Boulder:
	var boulder := BoulderScript.new()
	boulder.size = body_size
	boulder.paint_seed = seed
	boulder.snow = has_snow
	boulder.floor_index = floor
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	boulder.add_child(col)
	return boulder

func _area(points: PackedVector2Array) -> float:
	var twice := 0.0
	for i in points.size():
		twice += points[i].cross(points[(i + 1) % points.size()])
	return absf(twice) * 0.5

func _distance_to_fill(point: Vector2, polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var closest := INF
	for i in polygon.size():
		var edge_point := Geometry2D.get_closest_point_to_segment(point, polygon[i],
			polygon[(i + 1) % polygon.size()])
		closest = minf(closest, point.distance_to(edge_point))
	return closest

func _radar_body(parent: Node, at: Vector2, body_size: Vector2,
		layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body

func test_outline_is_seeded_and_deterministic() -> void:
	var first := _boulder(Vector2(128, 128), 17)
	var same := _boulder(Vector2(128, 128), 17)
	var different := _boulder(Vector2(128, 128), 18)
	t.check(first.outline() == same.outline(), "boulder: same seed and size repeat outline")
	t.check(first.outline() != different.outline(), "boulder: different seeds change outline")
	first.free()
	same.free()
	different.free()

func test_outline_covers_collision_rect() -> void:
	for body_size in SIZES:
		for seed in range(1, 21):
			var boulder := _boulder(body_size, seed)
			var rim := boulder.outline()
			var grown := Rect2(-body_size * 0.5, body_size).grow(6.0)
			var all_in_bounds := true
			for point in rim:
				all_in_bounds = all_in_bounds and point.x >= grown.position.x \
					and point.x <= grown.end.x and point.y >= grown.position.y \
					and point.y <= grown.end.y
			t.check(all_in_bounds, "boulder: %s seed %d outline stays within bleed" %
				[body_size, seed])
			t.check(_area(rim) >= body_size.x * body_size.y * 0.78,
				"boulder: %s seed %d paint covers at least 78%%" % [body_size, seed])
			var collision_is_covered := true
			for y in 9:
				for x in 9:
					var point: Vector2 = -body_size * 0.5 \
						+ body_size * Vector2(x / 8.0, y / 8.0)
					collision_is_covered = collision_is_covered \
						and _distance_to_fill(point, rim) <= 40.0
			t.check(collision_is_covered,
				"boulder: %s seed %d collision stays within 40px of paint" %
				[body_size, seed])
			boulder.free()

func test_outlines_triangulate_across_supported_sizes() -> void:
	for body_size in SIZES:
		for seed in range(1, 21):
			var boulder := _boulder(body_size, seed)
			t.check(not Geometry2D.triangulate_polygon(boulder.outline()).is_empty(),
				"boulder: %s seed %d triangulates" % [body_size, seed])
			boulder.free()

func test_snow_is_inside_rock_and_optional() -> void:
	for body_size in SIZES:
		for seed in range(1, 21):
			var boulder := _boulder(body_size, seed)
			var rim := boulder.outline()
			var cap := boulder.snow_outline()
			var inner_edge := boulder.snow_inner_edge()
			t.check(not cap.is_empty(), "boulder: %s seed %d has a snow cap" %
				[body_size, seed])
			var all_inside := true
			for point in cap:
				all_inside = all_inside and Geometry2D.is_point_in_polygon(point, rim)
			t.check(all_inside, "boulder: %s seed %d snow stays inside rock" %
				[body_size, seed])
			t.check(not Geometry2D.triangulate_polygon(cap).is_empty(),
				"boulder: %s seed %d snow triangulates" % [body_size, seed])
			var snow_ratio := _area(cap) / _area(rim)
			# A shoulder of snow, not a blanket: the rock has to stay readable.
			t.check(snow_ratio >= 0.12 and snow_ratio <= 0.34,
				"boulder: %s seed %d snow covers 12-34%% of rock (got %.2f)" %
				[body_size, seed, snow_ratio])
			var scalloped := false
			for i in range(1, inner_edge.size() - 1):
				var line_point := Geometry2D.get_closest_point_to_segment(inner_edge[i],
					inner_edge[0], inner_edge[-1])
				scalloped = scalloped or inner_edge[i].distance_to(line_point) > 4.0
			t.check(inner_edge.size() == 7 and scalloped,
				"boulder: %s seed %d snow edge has five scallop points" %
				[body_size, seed])
			boulder.free()
	var bare := _boulder(Vector2(128, 128), 1, false)
	t.check(bare.snow_outline().is_empty(), "boulder: snow false returns an empty outline")
	t.check(bare.snow_inner_edge().is_empty(), "boulder: snow false returns an empty inner edge")
	bare.free()

func test_ready_stamps_floor_collision_layers() -> void:
	for floor in [2, 3]:
		var boulder := _boulder(Vector2(128, 128), floor, true, floor)
		t.root.add_child(boulder)
		var floor_bit := 16 if floor == 2 else 32
		t.check(boulder.collision_layer == (4 | floor_bit),
			"boulder: floor %d carries obstacle and floor bits" % floor)
		t.check(boulder.collision_mask == 0, "boulder: floor %d mask is zero" % floor)
		t.root.remove_child(boulder)
		boulder.free()

func test_radar_classifies_boulder_as_permanent_solid() -> void:
	var arena := Node2D.new()
	t.root.add_child(arena)
	t.current_scene = arena
	_radar_body(arena, Vector2(500, 0), Vector2(1000, 20), 2)
	_radar_body(arena, Vector2(500, 1000), Vector2(1000, 20), 2)
	_radar_body(arena, Vector2(0, 500), Vector2(20, 1000), 2)
	_radar_body(arena, Vector2(1000, 500), Vector2(20, 1000), 2)
	var boulder := _boulder()
	boulder.position = Vector2(400, 600)
	arena.add_child(boulder)
	var radar := RadarScript.new()
	arena.add_child(radar)
	radar._scan()
	var expected := Rect2(boulder.global_position - boulder.size * 0.5, boulder.size)
	var found_solid := false
	for entry_v in radar._solids:
		var entry: Dictionary = entry_v
		found_solid = found_solid or entry.rect == expected
	var found_breakable := false
	for entry_v in radar._breakables:
		var entry: Dictionary = entry_v
		found_breakable = found_breakable or entry.rect == expected
	t.check(found_solid, "boulder: radar includes authored Col rect in solids")
	t.check(not found_breakable, "boulder: radar does not classify it as breakable")
	t.current_scene = null
	t.root.remove_child(arena)
	arena.free()

func test_projectile_stops_without_changing_boulder() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var boulder := _boulder(Vector2(128, 128), 23)
	container.add_child(boulder)
	var before_outline := boulder.outline()
	var before_layer := boulder.collision_layer
	var shot: Projectile = ProjectileScene.instantiate()
	container.add_child(shot)
	shot.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 50.0, 1.0, null)
	shot._on_body_entered(boulder)
	t.check(boulder.get_node_or_null(^"Health") == null, "boulder: carries no Health child")
	t.check(shot._spent, "boulder: projectile hit is terminal")
	t.check(boulder.collision_layer == before_layer and boulder.outline() == before_outline,
		"boulder: weapon fire leaves permanent cover unchanged")
	t.root.remove_child(container)
	container.free()
