extends RefCounted
## Retrofit floor hygiene for Downtown + Snowy Pass. Every bit-4 solid carries
## its terrace (raw statics by
## layer bits, instanced props by floor_index — one forgotten static means
## cars drive through it), jump pads are floor-stamped, spawns start on the
## zone under them, grade Ramp nodes land their ends on the right floors,
## and every connector's approach run begins on its from_floor.

const LEVELS := ["res://levels/arena/arena.tscn", "res://levels/snowy/snowy.tscn"]
const FLOOR_BITS := 8 | 16 | 32

var t

func _init(runner) -> void:
	t = runner

func _zone_rect(z: Node2D) -> Rect2:
	var size: Vector2 = z.get("size")
	return Rect2(z.position - size * 0.5, size)

func _floor_at(zones: Array, point: Vector2) -> int:
	var best := -1
	for z in zones:
		if (z.rect as Rect2).grow(8.0).has_point(point):
			best = maxi(best, int(z.floor))
	return best

func _script_path(n: Node) -> String:
	var sc := n.get_script() as Script
	return sc.resource_path if sc else ""

func test_retrofit_structure() -> void:
	for path in LEVELS:
		var tag: String = path.get_file()
		var lvl: Node = (load(path) as PackedScene).instantiate()
		var zones: Array = []
		var connectors: Array = []
		var ramps: Array = []
		for child in lvl.get_children():
			if child is Area2D and child.scene_file_path.ends_with("floor_zone.tscn"):
				zones.append({"rect": _zone_rect(child), "floor": int(child.floor_index)})
			elif child is DriveableHill:
				zones.append({"rect": Rect2(child.position - child.summit_size * 0.5,
					child.summit_size), "floor": int(child.high_floor)})
			elif child.get("from_floor") != null:
				connectors.append(child)
			elif _script_path(child).ends_with("/ramp.gd"):
				ramps.append(child)
		t.check(zones.size() >= 2, "%s: floor zones present (got %d)" % [tag, zones.size()])

		for child in lvl.get_children():
			# Solids: raw statics prove it by layer bits, instances by export.
			if child is StaticBody2D and (child.collision_layer & 4):
				if child.scene_file_path == "":
					t.check((child.collision_layer & FLOOR_BITS) != 0,
						"%s: %s carries a floor bit (layer %d)" % [tag, child.name, child.collision_layer])
				else:
					t.check(int(child.get("floor_index")) >= 1,
						"%s: %s has floor_index" % [tag, child.name])
			elif child is Area2D and _script_path(child).ends_with("jump_pad.gd"):
				t.check(int(child.get("floor_index")) >= 1,
					"%s: jump pad %s is floor-stamped" % [tag, child.name])
			elif String(child.name) == "Vehicle" or String(child.name).begins_with("Enemy"):
				var sf := int(child.get("start_floor"))
				t.check(sf >= 1, "%s: %s authors start_floor" % [tag, child.name])
				t.check(_floor_at(zones, child.position) == sf,
					"%s: %s start_floor matches the zone under it" % [tag, child.name])

		for r in ramps:
			var low := int(r.get("low_floor"))
			var high := int(r.get("high_floor"))
			t.check(low >= 1 and high > low, "%s: %s floors ascend (%d->%d)" % [tag, r.name, low, high])
			var half_len: float = (r.get("size") as Vector2).y * 0.5
			var high_end: Vector2 = r.position + Vector2(0, -half_len).rotated(r.rotation)
			var low_end: Vector2 = r.position + Vector2(0, half_len).rotated(r.rotation)
			t.check(_floor_at(zones, high_end) == high,
				"%s: %s high end reaches floor %d" % [tag, r.name, high])
			t.check(_floor_at(zones, low_end) == low,
				"%s: %s low end rests on floor %d" % [tag, r.name, low])

		for c in connectors:
			var entry: Vector2 = c.position - (c.get("approach_dir") as Vector2).normalized() * 220.0
			t.check(_floor_at(zones, entry) == int(c.get("from_floor")),
				"%s: %s approach run sits on floor %d" % [tag, c.name, int(c.get("from_floor"))])
		lvl.free()

func test_snowy_hill_has_eight_driveable_faces() -> void:
	var snowy := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	t.root.add_child(snowy)  # DriveableHill builds its authored recipe at ready.
	var hill := snowy.get_node_or_null(^"SnowyHill") as DriveableHill
	t.check(hill != null and hill.summit_size == Vector2(848, 848)
			and is_equal_approx(hill.grade_length, 240.0),
		"snowy hill: one reusable authoring root owns summit and grade depth")
	var cardinals: Array = []
	var corners: Array = []
	var grade_up := 0
	var grade_down := 0
	var generated := hill.get_node_or_null(^"_Generated") if hill else null
	for child in generated.get_children() if generated else []:
		if child is Ramp and String(child.name).begins_with("Ramp"):
			cardinals.append(child)
		elif child is CornerRamp:
			corners.append(child)
		elif child.get("from_floor") != null and String(child.get("kind")) == "grade":
			if int(child.get("from_floor")) == 2 and int(child.get("to_floor")) == 3:
				grade_up += 1
			elif int(child.get("from_floor")) == 3 and int(child.get("to_floor")) == 2:
				grade_down += 1
		t.check(not String(child.name).begins_with("PlateauWall")
				and not String(child.name).begins_with("Ledge"),
			"snowy hill: no hard plateau wall/ledge survives (%s)" % child.name)
	t.check(cardinals.size() == 4 and corners.size() == 4,
		"snowy hill: four cardinal and four diagonal faces")
	for ramp in cardinals:
		t.check(ramp.size == Vector2(848, 240) and not ramp.rails and not ramp.surface_paint
				and ramp.terrain_type == "snow" and is_equal_approx(ramp.downhill_pull, 120.0),
			"snowy hill: %s yields paint to the seamless snow skin" % ramp.name)
	for corner in corners:
		t.check(is_equal_approx(corner.leg_size, 120.0) and not corner.surface_paint
				and corner.terrain_type == "snow"
				and is_equal_approx(corner.downhill_pull, 120.0),
			"snowy hill: %s exactly fills its 120px corner gap" % corner.name)
	var skin := hill.get_node_or_null(^"_Generated/Surface") as Polygon2D
	var expected_skin := PackedVector2Array([
		Vector2(-424, -544), Vector2(424, -544),
		Vector2(544, -424), Vector2(544, 424),
		Vector2(424, 544), Vector2(-424, 544),
		Vector2(-544, 424), Vector2(-544, -424),
	])
	t.check(skin != null and skin.polygon == expected_skin,
		"snowy hill: one compact snow-textured octagon owns the complete silhouette")
	var substrate := hill.get_node_or_null(^"_Generated/Substrate") as Polygon2D
	var edge := hill.get_node_or_null(^"_Generated/Edge") as Line2D
	var surface_mat := skin.material as ShaderMaterial if skin else null
	t.check(substrate != null and substrate.material != hill.substrate_material
			and surface_mat != null and surface_mat != hill.terrain_material,
		"snowy hill: local material copies prevent substrate stacking and shared mutation")
	t.check(bool(surface_mat.get_shader_parameter("relief_enabled"))
			and is_equal_approx(float(surface_mat.get_shader_parameter("relief_strength")), 0.14)
			and edge != null and is_equal_approx(edge.width, 2.0),
		"snowy hill: restrained opt-in relief owns one crisp edge")
	t.check(grade_up == 8 and grade_down == 8,
		"snowy hill: AI has paired routes over all eight faces")
	t.check(hill.get_node_or_null(^"AmmoPowerSummit") != null
			and hill.get_node_or_null(^"AmmoStandardSummit") != null
			and hill.get_node_or_null(^"DeerHerd") != null,
		"snowy hill: summit traversal rewards stay authored")
	t.check(hill.position == Vector2(896, -672) and hill.outer_size() == Vector2(1088, 1088),
		"snowy hill: exact-fit root is 1088px at the selected snowfield center")
	var world_bounds := Rect2(hill.position - hill.outer_size() * 0.5, hill.outer_size())
	t.check(is_equal_approx(world_bounds.position.y, -1216.0)
			and is_equal_approx(world_bounds.end.y, -128.0),
		"snowy hill: north and south edges stop exactly at both road boundaries")
	var slope_building := snowy.get_node_or_null(^"SlopeBuilding") as StaticBody2D
	var player := snowy.get_node_or_null(^"Vehicle") as Vehicle
	t.check(slope_building != null and slope_building.collision_layer == (4 | 16 | 32),
		"snowy hill: slope structure blocks both adjoining terrace floors")
	t.check(hill.get_index() < slope_building.get_index()
			and slope_building.get_index() < player.get_index(),
		"snowy hill: skin draws before slope structure, which draws before vehicles")
	var power := hill.get_node(^"AmmoPowerSummit") as Node2D
	var standard := hill.get_node(^"AmmoStandardSummit") as Node2D
	var deer := hill.get_node(^"DeerHerd") as Node2D
	t.check(power.position == Vector2.ZERO and standard.position == Vector2(204, 196)
			and deer.position == Vector2.ZERO,
		"snowy hill: pickups and deer remain hill-relative for future moves")
	t.root.remove_child(snowy)
	snowy.free()
