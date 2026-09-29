extends RefCounted
## Pure contract checks for the signed-off Mountainside Mayhem pass grid.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")
const PassBuilder := preload("res://levels/snowy/pass_builder.gd")
const PassDecoScript := preload("res://levels/snowy/pass_deco.gd")
const AiNoGoScript := preload("res://environment/ai_no_go.gd")
const PitZoneScript := preload("res://environment/pit_zone.gd")
const DestructibleBlockScript := preload("res://environment/destructible_block.gd")
const UnionSkin := preload("res://environment/union_skin.gd")

const GOLDEN := [
	"################################################################",
	"########################################                     |..",
	"######################################                       |..",
	"######################################            E1         |..",
	"####################################                         |..",
	"####################################                       |....",
	"################################                       |........",
	"##############################          E2           |..........",
	"############################                       |............",
	"############################                   |................",
	"############################  Jv               |................",
	"############################                   |................",
	"############################XXXXXX][][][XXXXXXXX................",
	"############################XXXXXX][][][XXXXXXXX................",
	"############################                   |................",
	"############################  J^               |................",
	"##########################                     |................",
	"##################                             |................",
	"################                               |................",
	"##############          /\\/\\/\\/\\             |..................",
	"##############          /\\K*/\\/\\      E3     |..................",
	"##p LL<<<<<<      E4    /\\/\\/\\/\\           |....................",
	"##LLLL<<<<<<            /\\/\\/\\/\\         |......................",
	"########                             |..........................",
	"######              +              |............................",
	"####                         |..................................",
	"##                       |......................................",
	"##                   |..........................................",
	"##      P            |..........................................",
	"##                   |..........................................",
	"##                   |..........................................",
	"######################..........................................",
]

var t

func _init(runner) -> void:
	t = runner

func _driveable_cells() -> Dictionary:
	var out := {}
	for j in PassGrid.N:
		for i in PassGrid.N:
			if PassGrid.is_driveable(i, j):
				out[Vector2i(i, j)] = true
	return out

func _component(cells: Dictionary, diagonal: bool) -> Dictionary:
	var seen := {}
	if cells.is_empty():
		return seen
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
	]
	if diagonal:
		directions.append_array([
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		])
	var start: Vector2i = cells.keys()[0]
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for direction in directions:
			var next := cell + direction
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				stack.append(next)
	return seen

func _rect_driveable(rect: Rect2) -> bool:
	var first := PassGrid.cell_of(rect.position + Vector2.ONE)
	var last := PassGrid.cell_of(rect.end - Vector2.ONE)
	for j in range(first.y, last.y + 1):
		for i in range(first.x, last.x + 1):
			if not PassGrid.is_driveable(i, j):
				return false
	return true

func _side_clearance(point: Vector2) -> float:
	var arena_end := PassGrid.ARENA_RECT.end
	var best := minf(minf(point.x - PassGrid.ORIGIN.x, arena_end.x - point.x),
		minf(point.y - PassGrid.ORIGIN.y, arena_end.y - point.y))
	for j in PassGrid.N:
		if j >= PassGrid.CHASM_ROWS.x and j <= PassGrid.CHASM_ROWS.y:
			continue
		for i in PassGrid.N:
			if PassGrid.is_driveable(i, j):
				continue
			var rect := PassGrid.cell_rect(i, j)
			var nearest := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y))
			best = minf(best, point.distance_to(nearest))
	return best

func _knoll_rect() -> Rect2:
	var center: Vector2 = PassGrid.KNOLL["center"]
	var size := Vector2.ONE * float(PassGrid.KNOLL["footprint"])
	return Rect2(center - size * 0.5, size)

func _base_kind_at(i: int, j: int) -> StringName:
	if not PassGrid.ROWS.has(j):
		return PassGrid.MOUNTAIN if j == 0 or i <= 10 else PassGrid.DROP
	var span: Vector2i = PassGrid.ROWS[j]
	if i < span.x:
		return PassGrid.MOUNTAIN
	if i > span.y:
		return PassGrid.DROP
	return PassGrid.ROAD

func test_every_cell_has_exactly_one_kind() -> void:
	var allowed := {
		PassGrid.MOUNTAIN: true, PassGrid.ROAD: true, PassGrid.DROP: true,
		PassGrid.BRIDGE: true, PassGrid.WEST_PIT: true, PassGrid.EAST_PIT: true,
		PassGrid.SPUR: true, PassGrid.LEDGE: true,
	}
	var invalid: Array[Vector2i] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			var kind: StringName = PassGrid.kind_at(i, j)
			if not allowed.has(kind):
				invalid.append(Vector2i(i, j))
	t.check(invalid.is_empty(), "pass grid: all 1024 cells have one known kind; invalid %s" % [invalid])

func test_driveable_grid_is_one_four_connected_region() -> void:
	var cells := _driveable_cells()
	var seen := _component(cells, false)
	var missing: Array = cells.keys().filter(func(cell): return not seen.has(cell))
	t.check(seen.size() == cells.size(),
		"pass grid: %d driveable cells are one 4-connected region; missing %s" % [cells.size(), missing])

func test_non_chasm_rows_are_at_least_1024_wide() -> void:
	var narrow := []
	for row in PassGrid.ROWS:
		var j: int = row
		if j >= PassGrid.CHASM_ROWS.x and j <= PassGrid.CHASM_ROWS.y:
			continue
		var span: Vector2i = PassGrid.ROWS[j]
		var width := (span.y - span.x + 1) * PassGrid.CELL
		if width < 1024:
			narrow.append(Vector2i(j, width))
	t.check(narrow.is_empty(), "pass grid: non-chasm row widths are >=1024; narrow rows %s" % [narrow])

func test_640_disc_can_travel_each_half() -> void:
	var north := {}
	var south := {}
	for cell in _driveable_cells():
		var c: Vector2i = cell
		if PassGrid.clearance(PassGrid.cell_center(c.x, c.y)) < 320.0:
			continue
		if c.y < PassGrid.CHASM_ROWS.x:
			north[c] = true
		elif c.y > PassGrid.CHASM_ROWS.y:
			south[c] = true
	for half in [{"name": "north", "cells": north}, {"name": "south", "cells": south}]:
		var name: String = half["name"]
		var cells: Dictionary = half["cells"]
		var seen := _component(cells, true)
		var missing: Array = cells.keys().filter(func(cell): return not seen.has(cell))
		t.check(not cells.is_empty() and seen.size() == cells.size(),
			"pass grid: 640px disc traverses %s half; missing %s" % [name, missing])
	var north_rows: Array = north.keys().map(func(cell): return (cell as Vector2i).y)
	var south_rows: Array = south.keys().map(func(cell): return (cell as Vector2i).y)
	t.check(not north_rows.is_empty() and PassGrid.CHASM_ROWS.x - north_rows.max() <= 4,
		"pass grid: north wide route reaches within 4 rows of chasm (rows %s)" % [north_rows])
	t.check(not south_rows.is_empty() and south_rows.min() - PassGrid.CHASM_ROWS.y <= 4,
		"pass grid: south wide route reaches within 4 rows of chasm (rows %s)" % [south_rows])

func test_bridge_width_and_straight_approach() -> void:
	var width := PassGrid.BRIDGE_COLS.y - PassGrid.BRIDGE_COLS.x + 1
	t.check(width == 3, "pass grid: bridge is exactly 3 cells wide (got %d)" % width)
	var blocked: Array[Vector2i] = []
	for j in [9, 10, 11, 14, 15, 16]:
		for i in range(PassGrid.BRIDGE_COLS.x, PassGrid.BRIDGE_COLS.y + 1):
			if not PassGrid.is_driveable(i, j):
				blocked.append(Vector2i(i, j))
	t.check(blocked.is_empty(), "pass grid: three bridge approach rows per side are open; blocked %s" % [blocked])

func test_knoll_footprint_approaches_and_side_lanes() -> void:
	var footprint := _knoll_rect()
	t.check(_rect_driveable(footprint), "pass grid: complete 512px knoll footprint is driveable")
	var approaches := PassGrid.knoll_approaches()
	var bad := []
	for approach_name in approaches:
		var name: StringName = approach_name
		var point: Vector2 = approaches[name]
		var cell := PassGrid.cell_of(point)
		var clear := PassGrid.clearance(point)
		if not PassGrid.is_driveable(cell.x, cell.y) or clear < 100.0:
			bad.append({"name": name, "cell": cell, "clearance": clear})
	t.check(approaches.size() == 8 and bad.is_empty(),
		"pass grid: 8 knoll approaches are driveable with >=100 clearance; bad %s" % [bad])
	var cells: Rect2i = PassGrid.KNOLL["cells"]
	var west := PassGrid.N * PassGrid.CELL
	var east := west
	for j in range(cells.position.y, cells.end.y):
		var west_cells := 0
		var east_cells := 0
		for i in range(0, cells.position.x):
			west_cells += 1 if PassGrid.is_driveable(i, j) else 0
		for i in range(cells.end.x, PassGrid.N):
			east_cells += 1 if PassGrid.is_driveable(i, j) else 0
		west = mini(west, west_cells * PassGrid.CELL)
		east = mini(east, east_cells * PassGrid.CELL)
	t.check(mini(west, east) >= 384 and maxi(west, east) >= 512,
		"pass grid: knoll lanes W %d / E %d meet 384/512 bands" % [west, east])

func test_jump_pad_routes() -> void:
	var knoll := _knoll_rect()
	var approaches := PassGrid.knoll_approaches()
	for pad_name in PassGrid.PADS:
		var name: StringName = pad_name
		var pad: Dictionary = PassGrid.PADS[name]
		var center: Vector2 = pad["center"]
		var pad_rect := Rect2(center - Vector2(112, 112), Vector2(224, 224))
		var north: bool = pad["launch"] == &"north"
		var runup := Rect2(Vector2(center.x - 112.0, center.y + (112.0 if north else -412.0)),
			Vector2(224, 300))
		t.check(_rect_driveable(pad_rect), "pass grid: pad %s square is driveable" % name)
		var side := _side_clearance(center)
		t.check(side >= 192.0, "pass grid: pad %s side clearance %.1f >=192" % [name, side])
		t.check(_rect_driveable(runup), "pass grid: pad %s has a driveable 300px run-up" % name)
		t.check(not runup.intersects(knoll), "pass grid: pad %s run-up avoids knoll" % name)
		var pad_approaches := []
		for approach_name in approaches:
			var approach: Vector2 = approaches[approach_name]
			if pad_rect.grow(64.0).has_point(approach):
				pad_approaches.append(approach_name)
		t.check(pad_approaches.is_empty(),
			"pass grid: pad %s grown by 64 avoids knoll approaches %s" % [name, pad_approaches])
		var bridge_start := PassGrid.ORIGIN.x + PassGrid.BRIDGE_COLS.x * PassGrid.CELL
		var bridge_end := PassGrid.ORIGIN.x + (PassGrid.BRIDGE_COLS.y + 1) * PassGrid.CELL
		t.check(pad_rect.end.x <= bridge_start or pad_rect.position.x >= bridge_end,
			"pass grid: pad %s is outside bridge columns" % name)
		var far := (center.y - 112.0) - (PassGrid.ORIGIN.y + PassGrid.CHASM_ROWS.x * PassGrid.CELL) \
			if north else (PassGrid.ORIGIN.y + (PassGrid.CHASM_ROWS.y + 1) * PassGrid.CELL) - (center.y + 112.0)
		t.check(far > 0.0 and far <= 520.0,
			"pass grid: pad %s far rim is %.1fpx from leading edge" % [name, far])
		var rows: Array[int] = []
		rows.append(11 if north else 14)
		rows.append(10 if north else 15)
		var cols: Vector2i = pad["lane_cols"]
		var bad_landings := []
		for j in rows:
			for i in range(cols.x, cols.y + 1):
				var clear := _side_clearance(PassGrid.cell_center(i, j))
				if not PassGrid.is_driveable(i, j) or clear < 192.0:
					bad_landings.append({"cell": Vector2i(i, j), "clearance": clear})
		t.check(bad_landings.is_empty(),
			"pass grid: pad %s has two clear landing rows; bad %s" % [name, bad_landings])
		var bad_pits: Array[Vector2i] = []
		for j in range(PassGrid.CHASM_ROWS.x, PassGrid.CHASM_ROWS.y + 1):
			for i in range(cols.x, cols.y + 1):
				var kind: StringName = PassGrid.kind_at(i, j)
				if kind != PassGrid.WEST_PIT and kind != PassGrid.EAST_PIT:
					bad_pits.append(Vector2i(i, j))
		t.check(bad_pits.is_empty(), "pass grid: pad %s faces pit cells; bad %s" % [name, bad_pits])

func test_no_go_rects_seal_the_west_pit_lane() -> void:
	var north: Rect2 = PassGrid.NO_GO[&"lane_north"]
	var south: Rect2 = PassGrid.NO_GO[&"lane_south"]
	t.check(PassGrid.NO_GO == {
		&"lane_north": Rect2(-256, -896, 384, 384),
		&"lane_south": Rect2(-256, -256, 384, 384),
	}, "pass grid: exactly two west-lane no-go rects have the approved extents")
	var west_pit := Rect2(PassGrid.cell_rect(14, PassGrid.CHASM_ROWS.x).position,
		Vector2((PassGrid.BRIDGE_COLS.x - 14) * PassGrid.CELL,
			(PassGrid.CHASM_ROWS.y - PassGrid.CHASM_ROWS.x + 1) * PassGrid.CELL))
	var whole_column := Rect2(-256, -896, 384, 1024)
	t.check(north.position == whole_column.position and north.size.x == whole_column.size.x
			and north.end.y == west_pit.position.y and west_pit.end.y == south.position.y
			and south.end == whole_column.end,
		"pass grid: no-go rects and west pit form one unbroken y -896..128 column")
	var bad_pit_cells: Array[Vector2i] = []
	for j in range(PassGrid.CHASM_ROWS.x, PassGrid.CHASM_ROWS.y + 1):
		for i in range(14, PassGrid.BRIDGE_COLS.x):
			if PassGrid.kind_at(i, j) != PassGrid.WEST_PIT:
				bad_pit_cells.append(Vector2i(i, j))
	t.check(bad_pit_cells.is_empty(),
		"pass grid: the column's middle is entirely west pit; bad %s" % [bad_pit_cells])

func test_no_go_rects_avoid_bridge_and_authored_gameplay() -> void:
	var bridge_start := PassGrid.ORIGIN.x + PassGrid.BRIDGE_COLS.x * PassGrid.CELL
	var bridge_width := (PassGrid.BRIDGE_COLS.y - PassGrid.BRIDGE_COLS.x + 1) \
		* PassGrid.CELL
	var bridge_columns := Rect2(Vector2(bridge_start, PassGrid.ORIGIN.y),
		Vector2(bridge_width, PassGrid.ARENA_SIZE.y))
	var occupied_cells := {
		&"crate": PassGrid.LEDGE_DATA["crate"]["cell"],
		&"station": PassGrid.STATION["cell"],
	}
	for spawn_name in PassGrid.SPAWNS:
		occupied_cells[spawn_name] = PassGrid.SPAWNS[spawn_name]["cell"]
	var overlaps := []
	for no_go_name in PassGrid.NO_GO:
		var rect: Rect2 = PassGrid.NO_GO[no_go_name]
		if rect.intersects(bridge_columns):
			overlaps.append({"no_go": no_go_name, "feature": &"bridge"})
		for feature_name in occupied_cells:
			var cell: Vector2i = occupied_cells[feature_name]
			if rect.intersects(PassGrid.cell_rect(cell.x, cell.y)):
				overlaps.append({"no_go": no_go_name, "feature": feature_name})
	t.check(overlaps.is_empty(),
		"pass grid: no-go rects avoid bridge columns, spawns, crate, and station; bad %s"
		% [overlaps])

func test_spawn_contract() -> void:
	var knoll := _knoll_rect()
	var bad := []
	for spawn_name in PassGrid.SPAWNS:
		var name: StringName = spawn_name
		var spawn: Dictionary = PassGrid.SPAWNS[name]
		var cell: Vector2i = spawn["cell"]
		var center: Vector2 = spawn["center"]
		if center != PassGrid.cell_center(cell.x, cell.y) or int(spawn["start_floor"]) != 2 \
				or not PassGrid.is_driveable(cell.x, cell.y) or PassGrid.clearance(center) < 256.0 \
				or knoll.has_point(center):
			bad.append({"name": name, "cell": cell, "clearance": PassGrid.clearance(center)})
		for pad_name in PassGrid.PADS:
			var pad: Dictionary = PassGrid.PADS[pad_name]
			var pad_center: Vector2 = pad["center"]
			if center.distance_to(pad_center) < 300.0:
				bad.append({"spawn": name, "near_pad": pad_name, "distance": center.distance_to(pad_center)})
	t.check(bad.is_empty(), "pass grid: spawns are valid, clear, off knoll/pads; bad %s" % [bad])
	var player: Dictionary = PassGrid.SPAWNS[&"P"]
	var player_center: Vector2 = player["center"]
	var names: Array = PassGrid.SPAWNS.keys()
	for enemy_name in names:
		if enemy_name == &"P":
			continue
		var enemy: Dictionary = PassGrid.SPAWNS[enemy_name]
		var enemy_center: Vector2 = enemy["center"]
		t.check(enemy_center.distance_to(player_center) >= 700.0,
			"pass grid: %s is %.1fpx from P (>=700)" % [enemy_name, enemy_center.distance_to(player_center)])
	for a in range(1, names.size()):
		for b in range(a + 1, names.size()):
			var spawn_a: Dictionary = PassGrid.SPAWNS[names[a]]
			var spawn_b: Dictionary = PassGrid.SPAWNS[names[b]]
			var center_a: Vector2 = spawn_a["center"]
			var center_b: Vector2 = spawn_b["center"]
			t.check(center_a.distance_to(center_b) >= 600.0,
			"pass grid: %s/%s separation %.1fpx >=600" % [names[a], names[b], center_a.distance_to(center_b)])

func test_station_contract() -> void:
	var cell: Vector2i = PassGrid.STATION["cell"]
	var center: Vector2 = PassGrid.STATION["center"]
	t.check(center == PassGrid.cell_center(cell.x, cell.y) and int(PassGrid.STATION["floor"]) == 2,
		"pass grid: station world centre and floor match its cell")
	t.check(PassGrid.is_driveable(cell.x, cell.y) and PassGrid.clearance(center) >= 256.0,
		"pass grid: station is driveable with %.1fpx clearance" % PassGrid.clearance(center))
	t.check(not _knoll_rect().has_point(center), "pass grid: station is off the knoll")

func test_spur_and_ledge_contract() -> void:
	var spur: Rect2i = PassGrid.SPUR_DATA["cells"]
	var ledge: Rect2i = PassGrid.LEDGE_DATA["cells"]
	var bad_base: Array[Vector2i] = []
	for area in [spur, ledge]:
		var cells: Rect2i = area
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				if _base_kind_at(i, j) != PassGrid.MOUNTAIN:
					bad_base.append(Vector2i(i, j))
	t.check(bad_base.is_empty(), "pass grid: spur/ledge carve only base mountain; bad %s" % [bad_base])
	t.check(ledge.end.x == spur.position.x and ledge.position.y <= spur.position.y \
		and ledge.end.y >= spur.end.y, "pass grid: ledge meets spur west end")
	var blocked: Array[Vector2i] = []
	for j in range(spur.position.y, spur.end.y):
		for i in [spur.end.x, spur.end.x + 1]:
			if not PassGrid.is_driveable(i, j):
				blocked.append(Vector2i(i, j))
	t.check(blocked.is_empty(), "pass grid: two cells east of spur mouth are open; blocked %s" % [blocked])
	t.check(ledge.position.x >= 1, "pass grid: ledge does not touch column 0")
	var crate: Dictionary = PassGrid.LEDGE_DATA["crate"]
	t.check(crate["kind"] == &"power" and crate["cell"] == Vector2i(1, 21),
		"pass grid: power crate occupies ledge cell (1,21)")

func test_golden_render() -> void:
	var got := PassGrid.render()
	var bad_lengths := []
	for j in got.size():
		if got[j].length() != 64:
			bad_lengths.append(Vector2i(j, got[j].length()))
	t.check(got.size() == 32 and bad_lengths.is_empty(),
		"pass grid: render is 32 lines of 64 chars; bad lengths %s" % [bad_lengths])
	t.check(got == PackedStringArray(GOLDEN),
		"pass grid: render matches signed-off golden character for character")

func _is_pit_kind(kind: StringName) -> bool:
	return kind == PassGrid.DROP or kind == PassGrid.WEST_PIT or kind == PassGrid.EAST_PIT

func _rim_edges() -> Array[PackedVector2Array]:
	var edges: Array[PackedVector2Array] = []
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for j in PassGrid.N:
		for i in PassGrid.N:
			if not _is_pit_kind(PassGrid.kind_at(i, j)):
				continue
			var rect := PassGrid.cell_rect(i, j)
			for direction: Vector2i in directions:
				if not PassGrid.is_driveable(i + direction.x, j + direction.y):
					continue
				var a: Vector2
				var b: Vector2
				if direction == Vector2i.LEFT:
					a = rect.position
					b = Vector2(rect.position.x, rect.end.y)
				elif direction == Vector2i.RIGHT:
					a = Vector2(rect.end.x, rect.position.y)
					b = rect.end
				elif direction == Vector2i.UP:
					a = rect.position
					b = Vector2(rect.end.x, rect.position.y)
				else:
					a = Vector2(rect.position.x, rect.end.y)
					b = rect.end
				edges.append(PackedVector2Array([a, b, -Vector2(direction)]))
	return edges

func _rim_samples() -> PackedVector2Array:
	var samples := PackedVector2Array()
	for edge: PackedVector2Array in _rim_edges():
		var tangent := (edge[1] - edge[0]).normalized()
		var length := edge[0].distance_to(edge[1])
		var distance := 0.0
		while distance < length:
			samples.append(edge[0] + tangent * distance + edge[2] * 8.0)
			distance += 64.0
	return samples

func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(nearest)

func _distance_to_rim(point: Vector2) -> float:
	var best := INF
	for edge: PackedVector2Array in _rim_edges():
		var nearest := Geometry2D.get_closest_point_to_segment(point, edge[0], edge[1])
		best = minf(best, point.distance_to(nearest))
	return best

func _rail_rect(node: Node2D) -> Rect2:
	var size: Vector2 = node.get("size")
	return Rect2(node.position - size * 0.5, size)

func _same_built_tree(a: Node2D, b: Node2D) -> bool:
	if a.name != b.name or a.get_script() != b.get_script() \
			or a.get("bounds") != b.get("bounds") \
			or a.get("paint_seed") != b.get("paint_seed") \
			or a.get_child_count() != b.get_child_count():
		return false
	if a.name == &"Mountain" \
			and a.get("chamfer_exclusions") != b.get("chamfer_exclusions"):
		return false
	for i in a.get_child_count():
		var child_a := a.get_child(i) as Node2D
		var child_b := b.get_child(i) as Node2D
		if child_a.name != child_b.name or child_a.get_class() != child_b.get_class() \
				or child_a.position != child_b.position or child_a.scale != child_b.scale \
				or child_a.z_index != child_b.z_index \
				or child_a.get_script() != child_b.get_script():
			return false
		if child_a is CollisionObject2D:
			var collision_a := child_a as CollisionObject2D
			var collision_b := child_b as CollisionObject2D
			if collision_a.collision_layer != collision_b.collision_layer \
					or collision_a.collision_mask != collision_b.collision_mask:
				return false
		if child_a.name.begins_with("Block"):
			var col_a := child_a.get_node_or_null(^"Col") as CollisionShape2D
			var col_b := child_b.get_node_or_null(^"Col") as CollisionShape2D
			if col_a == null or col_b == null \
					or not col_a.shape is RectangleShape2D \
					or not col_b.shape is RectangleShape2D:
				return false
			var shape_a := col_a.shape as RectangleShape2D
			var shape_b := col_b.shape as RectangleShape2D
			if shape_a.size != shape_b.size:
				return false
		else:
			if child_a.get("size") != child_b.get("size"):
				return false
			if child_a.name.begins_with("Pit") \
					and child_a.get("paint") != child_b.get("paint"):
				return false
			if child_a.name.begins_with("Rail") and (
					child_a.get("deco") != child_b.get("deco") \
					or child_a.get("max_hp") != child_b.get("max_hp") \
					or child_a.get("floor_index") != child_b.get("floor_index") \
					or child_a.get("arena_net_id") != child_b.get("arena_net_id")):
				return false
	return true

func test_generated_mountain_tiles_only_mountain_cells() -> void:
	var blocks := PassGrid.mountain_blocks()
	var bad: Array[Vector3i] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			var hits := 0
			for rect: Rect2 in blocks:
				hits += 1 if rect.has_point(PassGrid.cell_center(i, j)) else 0
			var want := 1 if PassGrid.kind_at(i, j) == PassGrid.MOUNTAIN else 0
			if hits != want:
				bad.append(Vector3i(i, j, hits))
	t.check(bad.is_empty(),
		"pass carve: mountain cells have one block and all other cells have none; bad %s" % [bad])

func test_drop_bands_cover_lethal_cells_without_touching_road() -> void:
	var bands := PassGrid.drop_bands()
	var uncovered: Array[Vector2i] = []
	var unsafe: Array[Vector2i] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			var kind := PassGrid.kind_at(i, j)
			if _is_pit_kind(kind):
				var covered := false
				for rect: Rect2 in bands:
					covered = covered or rect.grow(-24.0).has_point(
						PassGrid.cell_center(i, j))
				if not covered:
					uncovered.append(Vector2i(i, j))
			elif PassGrid.is_driveable(i, j):
				var interior := PassGrid.cell_rect(i, j).grow(-0.01)
				for rect: Rect2 in bands:
					if rect.intersects(interior):
						unsafe.append(Vector2i(i, j))
						break
	t.check(bands.size() == 33 and uncovered.is_empty(),
		"pass carve: 33 bands cover every lethal cell kill interior; missing %s" % [uncovered])
	t.check(unsafe.is_empty(),
		"pass carve: no painted band overlaps driveable cell interiors; unsafe %s" % [unsafe])

func test_drop_scene_has_no_kill_seams() -> void:
	var packed: PackedScene = load("res://levels/snowy/pass_drop.tscn")
	var drop := packed.instantiate() as Node2D
	t.root.add_child(drop)
	var gaps: PackedVector2Array = drop.call("kill_gaps")
	var warnings: PackedStringArray = drop.call("validation_warnings")
	t.check(gaps.is_empty(), "pass carve: generated drop has no kill gaps; gaps %s" % [gaps])
	t.check(warnings.is_empty(),
		"pass carve: generated drop has no validation warnings; warnings %s" % [warnings])
	t.root.remove_child(drop)
	drop.free()

func test_drop_fall_pull_stays_local() -> void:
	var bands := PassGrid.drop_bands()
	var missing := PackedVector2Array()
	var worst := 0.0
	for point: Vector2 in _rim_samples():
		var found := false
		for rect: Rect2 in bands:
			if not rect.has_point(point):
				continue
			var pit := PitZoneScript.new() as Node2D
			pit.position = rect.get_center()
			pit.set("size", rect.size)
			var target: Vector2 = pit.call("fall_target_for", point)
			worst = maxf(worst, point.distance_to(target))
			pit.free()
			found = true
			break
		if not found:
			missing.append(point)
	t.check(missing.is_empty() and worst <= 200.0,
		"pass carve: every rim sample falls locally (worst %.1f); missing %s" % [worst, missing])

func test_rim_curbs_cover_edges_without_blocking_solids() -> void:
	var curbs := PassGrid.rim_curbs()
	var blocks := PassGrid.mountain_blocks()
	var bands := PassGrid.drop_bands()
	var missed := PackedVector2Array()
	var invalid: Array[Rect2] = []
	for point: Vector2 in _rim_samples():
		var best := INF
		for curb: Rect2 in curbs:
			best = minf(best, _distance_to_rect(point, curb))
		if best > 32.0:
			missed.append(point)
	for curb: Rect2 in curbs:
		var bad := _distance_to_rim(curb.get_center()) > 40.0
		for block: Rect2 in blocks:
			bad = bad or curb.intersects(block)
		for band: Rect2 in bands:
			bad = bad or curb.intersects(band.grow(-24.0))
		if bad:
			invalid.append(curb)
	t.check(missed.is_empty(),
		"pass carve: every exposed rim sample is within 32px of a curb; missed %s" % [missed])
	t.check(invalid.is_empty(),
		"pass carve: curbs stay within 40px of rims and avoid blocks/kill rects; bad %s" % [invalid])

func test_rail_segments_cover_guarded_rims_and_clear_hazards() -> void:
	var rails := PassGrid.rail_segments()
	var curbs := PassGrid.rim_curbs()
	var blocks := PassGrid.mountain_blocks()
	var bands := PassGrid.drop_bands()
	var invalid: Array = []
	for rail: Rect2 in rails:
		var thin := minf(rail.size.x, rail.size.y)
		var long := maxf(rail.size.x, rail.size.y)
		var curb_distance := INF
		for curb: Rect2 in curbs:
			curb_distance = minf(curb_distance, _distance_to_rect(rail.get_center(), curb))
		var bad := not is_equal_approx(thin, 12.0) or long > 256.0 \
			or curb_distance > 32.0
		for block: Rect2 in blocks:
			bad = bad or rail.intersects(block)
		for band: Rect2 in bands:
			bad = bad or rail.intersects(band)
		for pad_name in PassGrid.PADS:
			var pad: Dictionary = PassGrid.PADS[pad_name]
			var pad_size: Vector2 = pad["size"]
			bad = bad or rail.intersects(Rect2(pad["center"] - pad_size * 0.5, pad_size))
		bad = bad or rail.intersects(_knoll_rect())
		if bad:
			invalid.append({"rail": rail, "curb_distance": curb_distance})
	t.check(not rails.is_empty() and rails.size() <= 60 and invalid.is_empty(),
		"pass rails: 1..60 short rim-aligned segments clear hazards; bad %s" % [invalid])

func test_rail_segments_cover_samples_except_jump_lane() -> void:
	var rails := PassGrid.rail_segments()
	var missed := PackedVector2Array()
	var lane_start := PassGrid.N
	var lane_end := -1
	for pad_name in PassGrid.PADS:
		var columns: Vector2i = PassGrid.PADS[pad_name]["lane_cols"]
		lane_start = mini(lane_start, columns.x)
		lane_end = maxi(lane_end, columns.y)
	var lane_x := Vector2(PassGrid.ORIGIN.x + lane_start * PassGrid.CELL,
		PassGrid.ORIGIN.x + (lane_end + 1) * PassGrid.CELL)
	var north_y := PassGrid.ORIGIN.y + PassGrid.CHASM_ROWS.x * PassGrid.CELL
	var south_y := PassGrid.ORIGIN.y + (PassGrid.CHASM_ROWS.y + 1) * PassGrid.CELL
	for edge: PackedVector2Array in _rim_edges():
		var horizontal := is_equal_approx(edge[0].y, edge[1].y)
		var edge_middle := (edge[0] + edge[1]) * 0.5
		var jump_lane := horizontal and (is_equal_approx(edge_middle.y, north_y) \
			or is_equal_approx(edge_middle.y, south_y)) \
			and edge_middle.x >= lane_x.x and edge_middle.x <= lane_x.y
		if jump_lane:
			continue
		var tangent := (edge[1] - edge[0]).normalized()
		for distance in [32.0, 96.0]:
			var sample: Vector2 = edge[0] + tangent * distance - edge[2] * 8.0
			var best := INF
			for rail: Rect2 in rails:
				best = minf(best, _distance_to_rect(sample, rail))
			if best > 24.0:
				missed.append(sample)
	var jump_strips := [
		Rect2(Vector2(lane_x.x, north_y - 16.0), Vector2(lane_x.y - lane_x.x, 32.0)),
		Rect2(Vector2(lane_x.x, south_y - 16.0), Vector2(lane_x.y - lane_x.x, 32.0)),
	]
	var blocked_jump: Array[Rect2] = []
	for rail: Rect2 in rails:
		for strip: Rect2 in jump_strips:
			if rail.intersects(strip):
				blocked_jump.append(rail)
	t.check(missed.is_empty(),
		"pass rails: every non-jump rim sample is within 24px; missed %s" % [missed])
	t.check(blocked_jump.is_empty(),
		"pass rails: west-pit pad lane stays open on both faces; blocked %s" % [blocked_jump])

func test_built_rails_are_floor_stamped_and_networked() -> void:
	var root := PassBuilder.build_rails()
	var ids: Array[int] = []
	var invalid := []
	for i in root.get_child_count():
		var rail := root.get_child(i) as Node2D
		ids.append(int(rail.get("arena_net_id")))
		if rail.name != "Rail%03d" % (i + 1) or rail.scale != Vector2.ONE \
				or rail.get_script() != DestructibleBlockScript \
				or rail.get("deco") != &"rail" or not is_equal_approx(rail.get("max_hp"), 12.0) \
				or rail.get("floor_index") != 2 or rail.get("arena_net_id") != 100 + i:
			invalid.append(rail.name)
	t.check(root.name == &"Rails" and root.get_script() == null and invalid.is_empty(),
		"pass rails: plain root owns ordered 12 HP floor-2 rail destructibles; bad %s" % [invalid])
	t.check(ids == range(100, 100 + root.get_child_count()),
		"pass rails: arena IDs are unique and contiguous from 100; got %s" % [ids])
	root.free()

func test_built_rails_stay_at_ground_draw_order() -> void:
	var root := PassBuilder.build_rails()
	var elevated: Array[StringName] = []
	# Ground-floor rails stay at z 0; the z 2 recipe is for floor-3 decks.
	for rail: Node2D in root.get_children():
		if rail.z_index != 0:
			elevated.append(rail.name)
	t.check(elevated.is_empty(),
		"pass rails: every ground-floor rail stays at z 0; elevated %s" % [elevated])
	root.free()

func test_generated_mountain_scene_builds_valid_skin() -> void:
	var packed: PackedScene = load("res://levels/snowy/pass_mountain.tscn")
	var mountain := packed.instantiate() as Node2D
	t.root.add_child(mountain)
	var paint_loops: Array = mountain.call("outline_loops")
	var snow_loops: Array = mountain.call("snow_loops")
	var valid := not snow_loops.is_empty()
	for loop: PackedVector2Array in paint_loops:
		valid = valid and UnionSkin.triangulates(loop)
	for loop: PackedVector2Array in snow_loops:
		valid = valid and UnionSkin.triangulates(loop)
	var blocks_valid := true
	for child: Node in mountain.get_children():
		if child.name.begins_with("Block"):
			var body := child as StaticBody2D
			blocks_valid = blocks_valid and body.collision_layer == 54 \
				and body.scale == Vector2.ONE
	var pines: PackedVector2Array = mountain.call("pine_points")
	t.check(valid and not pines.is_empty(),
		"pass carve: mountain paint/snow triangulate and deterministic pines exist")
	t.check(blocks_valid, "pass carve: mountain blocks use layer 54 at unit scale")
	t.root.remove_child(mountain)
	mountain.free()

func test_generated_scenes_are_up_to_date() -> void:
	var built_mountain := PassBuilder.build_mountain()
	var built_drop := PassBuilder.build_drop()
	var built_rails := PassBuilder.build_rails()
	var saved_mountain: Node2D = load(
		"res://levels/snowy/pass_mountain.tscn").instantiate()
	var saved_drop: Node2D = load("res://levels/snowy/pass_drop.tscn").instantiate()
	var saved_rails: Node2D = load("res://levels/snowy/pass_rails.tscn").instantiate()
	var same := _same_built_tree(built_mountain, saved_mountain) \
		and _same_built_tree(built_drop, saved_drop) \
		and _same_built_tree(built_rails, saved_rails)
	t.check(same, "pass carve: generated scenes are current; run tools/carve_pass.gd")
	for tree: Node2D in [built_mountain, built_drop, built_rails,
			saved_mountain, saved_drop, saved_rails]:
		tree.free()

func test_pass_builder_is_deterministic() -> void:
	var mountain_a := PassBuilder.build_mountain()
	var mountain_b := PassBuilder.build_mountain()
	var drop_a := PassBuilder.build_drop()
	var drop_b := PassBuilder.build_drop()
	var rails_a := PassBuilder.build_rails()
	var rails_b := PassBuilder.build_rails()
	t.check(_same_built_tree(mountain_a, mountain_b),
		"pass carve: two mountain builds have identical trees")
	t.check(_same_built_tree(drop_a, drop_b),
		"pass carve: two drop builds have identical trees")
	t.check(_same_built_tree(rails_a, rails_b),
		"pass carve: two rail builds have identical trees")
	for tree: Node2D in [mountain_a, mountain_b, drop_a, drop_b, rails_a, rails_b]:
		tree.free()

func test_level_instances_generated_geometry_before_gameplay() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var drop := level.get_node_or_null(^"Drop") as Node2D
	var mountain := level.get_node_or_null(^"Mountain") as Node2D
	var bridge := level.get_node_or_null(^"BridgeDeck") as Node2D
	var rails := level.get_node_or_null(^"Rails") as Node2D
	t.check(drop != null and drop.scene_file_path == "res://levels/snowy/pass_drop.tscn",
		"pass level: Drop is a direct instance of the generated drop scene")
	t.check(mountain != null
			and mountain.scene_file_path == "res://levels/snowy/pass_mountain.tscn",
		"pass level: Mountain is a direct instance of the generated mountain scene")
	t.check(rails != null and rails.scene_file_path == "res://levels/snowy/pass_rails.tscn",
		"pass level: Rails is a direct instance of the generated rail scene")
	if drop != null and mountain != null and bridge != null and rails != null:
		t.check(drop.get_parent() == level and mountain.get_parent() == level
				and rails.get_parent() == level and drop.get_index() < mountain.get_index()
				and bridge.get_index() < rails.get_index(),
			"pass level: Rails follows BridgeDeck as direct root geometry")
		for child: Node in level.get_children():
			var scene_path := child.scene_file_path
			var gameplay := child is Vehicle or String(child.name).begins_with("Jump") \
				or scene_path.ends_with("ammo_pickup.tscn") \
				or scene_path.ends_with("health_station.tscn")
			if gameplay:
				t.check(rails.get_index() < child.get_index(),
					"pass level: generated geometry precedes %s" % child.name)
	level.free()

func test_level_bridge_deck_matches_grid_and_stays_paint_only() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var bridge := level.get_node_or_null(^"BridgeDeck") as Node2D
	var drop := level.get_node_or_null(^"Drop") as Node2D
	var mountain := level.get_node_or_null(^"Mountain") as Node2D
	var bridge_start := PassGrid.ORIGIN + Vector2(
		PassGrid.BRIDGE_COLS.x, PassGrid.CHASM_ROWS.x) * PassGrid.CELL
	var bridge_size := Vector2(
		(PassGrid.BRIDGE_COLS.y - PassGrid.BRIDGE_COLS.x + 1) * PassGrid.CELL,
		(PassGrid.CHASM_ROWS.y - PassGrid.CHASM_ROWS.x + 1) * PassGrid.CELL)
	var bridge_rect := Rect2(bridge.position - bridge_size * 0.5, bridge_size) \
		if bridge != null else Rect2()
	t.check(bridge != null and bridge.get_parent() == level
			and bridge.get_script() == PassDecoScript
			and bridge.get("kind") == &"bridge_deck" and bridge.get("size") == bridge_size,
		"pass level: BridgeDeck is the direct paint-only pass deco")
	t.check(bridge_rect == Rect2(bridge_start, bridge_size),
		"pass level: BridgeDeck rect exactly matches the signed-off bridge cells")
	if bridge != null and drop != null and mountain != null:
		t.check(drop.get_index() < bridge.get_index()
				and mountain.get_index() < bridge.get_index(),
			"pass level: BridgeDeck follows Drop and Mountain")
		for child: Node in level.get_children():
			var scene_path := child.scene_file_path
			var gameplay := child is Vehicle or String(child.name).begins_with("Jump") \
				or scene_path.ends_with("ammo_pickup.tscn") \
				or scene_path.ends_with("health_station.tscn")
			if gameplay:
				t.check(bridge.get_index() < child.get_index(),
					"pass level: BridgeDeck precedes %s" % child.name)
	var collisions := bridge.find_children("*", "CollisionObject2D", true, false) \
		if bridge != null else []
	t.check(bridge != null and not bridge is CollisionObject2D and collisions.is_empty(),
		"pass level: BridgeDeck and its descendants contain no collision objects")
	if bridge != null:
		level.remove_child(bridge)
		bridge.owner = null
		t.root.add_child(bridge)
		await t.process_frame
		t.check(bridge.is_inside_tree(), "pass level: BridgeDeck draws for one frame")
		t.root.remove_child(bridge)
		bridge.free()
	level.free()

func test_level_mountain_uses_level_materials() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var mountain := level.get_node_or_null(^"Mountain") as MountainWall
	var asphalt := level.get_node_or_null(^"Asphalt") as Polygon2D
	var hill := level.get_node_or_null(^"SnowyHill") as DriveableHill
	t.check(mountain != null and asphalt != null and hill != null
			and mountain.substrate_material == asphalt.material
			and mountain.terrain_material == hill.terrain_material,
		"pass level: Mountain receives the scene asphalt and snow materials")
	level.free()

func test_level_fields_exactly_five_grid_spawns() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var expected := {
		&"Vehicle": PassGrid.SPAWNS[&"P"],
		&"Enemy1": PassGrid.SPAWNS[&"E1"],
		&"Enemy2": PassGrid.SPAWNS[&"E2"],
		&"Enemy3": PassGrid.SPAWNS[&"E3"],
		&"Enemy4": PassGrid.SPAWNS[&"E4"],
	}
	var cars: Array[Node] = []
	for child: Node in level.get_children():
		if child is Vehicle:
			cars.append(child)
	t.check(cars.size() == 5, "pass level: exactly five vehicles are direct root children")
	for car_name: StringName in expected:
		var car := level.get_node_or_null(NodePath(car_name)) as Vehicle
		var spawn: Dictionary = expected[car_name]
		t.check(car != null and car.get_parent() == level
				and car.position == spawn["center"] and car.start_floor == 2,
			"pass level: %s matches its grid spawn on floor 2" % car_name)
	level.free()

func test_level_places_pads_no_go_station_and_knoll_on_grid() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var jump_nw := level.get_node_or_null(^"JumpNW") as Area2D
	var jump_sw := level.get_node_or_null(^"JumpSW") as Area2D
	var station := level.get_node_or_null(^"HealthStation1") as Node2D
	var hill := level.get_node_or_null(^"SnowyHill") as DriveableHill
	t.check(jump_nw != null and jump_nw.position == PassGrid.PADS[&"north_west"]["center"]
			and int(jump_nw.get("floor_index")) == 2,
		"pass level: JumpNW matches the floor-2 grid pad")
	t.check(jump_sw != null and jump_sw.position == PassGrid.PADS[&"south_west"]["center"]
			and int(jump_sw.get("floor_index")) == 2,
		"pass level: JumpSW matches the floor-2 grid pad")
	var no_go_nodes := {
		&"NoGoLaneNorth": &"lane_north",
		&"NoGoLaneSouth": &"lane_south",
	}
	var scene_no_go_count := 0
	for child: Node in level.get_children():
		if child.get_script() == AiNoGoScript:
			scene_no_go_count += 1
	t.check(scene_no_go_count == PassGrid.NO_GO.size(),
		"pass level: exactly two direct no-go nodes match the grid")
	for node_name in no_go_nodes:
		var no_go := level.get_node_or_null(NodePath(node_name)) as Node2D
		var rect: Rect2 = PassGrid.NO_GO[no_go_nodes[node_name]]
		t.check(no_go != null and no_go.get_parent() == level
				and no_go.get_script() == AiNoGoScript and no_go.position == rect.get_center()
				and no_go.get("size") == rect.size,
			"pass level: %s exactly matches its grid no-go rect" % node_name)
	t.check(station != null and station.position == PassGrid.STATION["center"],
		"pass level: repair station matches the grid")
	t.check(hill != null and hill.position == PassGrid.KNOLL["center"]
			and hill.summit_size == Vector2.ONE * float(PassGrid.KNOLL["summit"])
			and is_equal_approx(hill.grade_length, float(PassGrid.KNOLL["grade_length"])),
		"pass level: SnowyHill matches the signed-off knoll")
	level.free()

func test_level_boundary_encloses_exactly_4096_square() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var boundary := level.get_node_or_null(^"Boundary") as StaticBody2D
	var top := boundary.get_node_or_null(^"TopCol") as CollisionShape2D if boundary else null
	var bottom := boundary.get_node_or_null(^"BottomCol") as CollisionShape2D if boundary else null
	var left := boundary.get_node_or_null(^"LeftCol") as CollisionShape2D if boundary else null
	var right := boundary.get_node_or_null(^"RightCol") as CollisionShape2D if boundary else null
	var all_present := top != null and bottom != null and left != null and right != null
	t.check(all_present, "pass level: boundary retains all four collision shapes")
	if all_present:
		var top_shape := top.shape as RectangleShape2D
		var bottom_shape := bottom.shape as RectangleShape2D
		var left_shape := left.shape as RectangleShape2D
		var right_shape := right.shape as RectangleShape2D
		var top_rect := Rect2(top.position - top_shape.size * 0.5, top_shape.size)
		var bottom_rect := Rect2(bottom.position - bottom_shape.size * 0.5,
			bottom_shape.size)
		var left_rect := Rect2(left.position - left_shape.size * 0.5, left_shape.size)
		var right_rect := Rect2(right.position - right_shape.size * 0.5, right_shape.size)
		t.check(top_shape.size == Vector2(4176, 40)
				and bottom_shape.size == Vector2(4176, 40)
				and left_shape.size == Vector2(40, 4176)
				and right_shape.size == Vector2(40, 4176),
			"pass level: boundary walls are 40px thick and close the corners")
		t.check(is_equal_approx(top_rect.end.y, -2048.0)
				and is_equal_approx(bottom_rect.position.y, 2048.0)
				and is_equal_approx(left_rect.end.x, -2048.0)
				and is_equal_approx(right_rect.position.x, 2048.0),
			"pass level: boundary inner faces enclose exactly +/-2048")
	var visuals_hidden := boundary != null
	for visual_name in [&"TopVis", &"BottomVis", &"LeftVis", &"RightVis"]:
		var visual := boundary.get_node_or_null(NodePath(visual_name)) as CanvasItem \
			if boundary else null
		visuals_hidden = visuals_hidden and visual != null and not visual.visible
	t.check(visuals_hidden, "pass level: all boundary visuals stay hidden")
	level.free()

func test_level_removes_old_snowfield_layout() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var removed := [
		&"SnowTop", &"SnowBottom", &"SnowNW", &"SnowN", &"SnowS", &"SnowSE",
		&"Ice1", &"Ice2", &"Ice3", &"Ice4", &"CliffWest", &"Chasm",
		&"CurbCliffE", &"CurbCliffN", &"CurbCliffS", &"CurbChasmN",
		&"CurbChasmS", &"CurbChasmE", &"CurbChasmW", &"Jump", &"Rock1",
		&"Rock3", &"Rock4", &"Rock5", &"SlopeBuilding", &"CenterN",
		&"CenterMidW", &"CenterMidE", &"CenterS", &"Drift1", &"Drift2",
		&"Drift3", &"Drift4", &"Drift5", &"Drift6", &"Drift7", &"PineGroves",
		&"Cone1", &"Cone2", &"Sign1", &"Enemy5", &"Enemy6", &"AmmoPower2",
	]
	var survivors: Array[StringName] = []
	for old_name: StringName in removed:
		if level.find_child(String(old_name), true, false) != null:
			survivors.append(old_name)
	var road_marks := level.get_node_or_null(^"RoadMarks")
	t.check(survivors.is_empty(), "pass level: removed snowfield nodes stay gone; found %s" %
		[survivors])
	t.check(road_marks != null and road_marks.get_child_count() == 0,
		"pass level: RoadMarks survives only as an empty grouping node")
	level.free()
