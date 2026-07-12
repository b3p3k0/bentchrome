extends RefCounted
## Retrofit floor hygiene for Downtown + Snowy Pass. Instantiate-only (no
## tree, no _ready): every bit-4 solid carries its terrace (raw statics by
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
	var cardinals: Array = []
	var corners: Array = []
	var grade_up := 0
	var grade_down := 0
	for child in snowy.get_children():
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
		t.check(ramp.size == Vector2(896, 240) and not ramp.rails
				and ramp.terrain_type == "snow" and is_equal_approx(ramp.downhill_pull, 120.0),
			"snowy hill: %s is a broad seamless snow grade" % ramp.name)
	for corner in corners:
		t.check(is_equal_approx(corner.leg_size, 240.0)
				and corner.terrain_type == "snow"
				and is_equal_approx(corner.downhill_pull, 120.0),
			"snowy hill: %s fills its diagonal with the same grade language" % corner.name)
	t.check(grade_up == 8 and grade_down == 8,
		"snowy hill: AI has paired routes over all eight faces")
	t.check(snowy.get_node_or_null(^"AmmoPowerSummit") != null
			and snowy.get_node_or_null(^"AmmoStandardSummit") != null,
		"snowy hill: summit traversal rewards stay authored")
	snowy.free()
