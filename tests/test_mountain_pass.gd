extends RefCounted
## Pure contract checks for the signed-off Mountainside Mayhem pass grid.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")
const PassBuilder := preload("res://levels/snowy/pass_builder.gd")
const PassDecoScript := preload("res://levels/snowy/pass_deco.gd")
const PitZoneScript := preload("res://environment/pit_zone.gd")
const DestructibleBlockScript := preload("res://environment/destructible_block.gd")
const TerrainFieldScript := preload("res://environment/terrain_field.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const RoadMarksScript := preload("res://environment/road_marks.gd")
const UnionSkin := preload("res://environment/union_skin.gd")
const FurnitureChecks := preload("res://tests/mountain_pass_furniture_checks.gd")

const GOLDEN := [
	"################################################################",
	"########################################                     |..",
	"######################################  ======iiii========   |..",
	"######################################  ======iiiiE1======   |..",
	"####################################          ====           |..",
	"####################################          ====         |....",
	"################################              ====     |........",
	"##############################    iiii==E2========   |..........",
	"############################      iiii============ |............",
	"############################  ==========       |................",
	"############################  Jv========       |................",
	"############################  ==========       |................",
	"############################XXXXXX][][][XXXXXXXX................",
	"############################XXXXXX][][][XXXXXXXX................",
	"############################  ==========       |................",
	"############################  J^========       |................",
	"##########################    ==========       |................",
	"##################              ====           |................",
	"################                ====           |................",
	"##############          /\\/\\/\\/\\====         |..................",
	"##############          /\\K*/\\/\\====  E3     |..................",
	"##p LL<<<<<<      E4    /\\/\\/\\/\\====       |....................",
	"##LLLL<<<<<<            /\\/\\/\\/\\====     |......................",
	"########        iiii================ |..........................",
	"######          iiii+ ==============............................",
	"####            ====         |..................................",
	"##              ====     |......................................",
	"##  ================ |..........................................",
	"##  ====P ========== |..........................................",
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

func _rect_road(rect: Rect2) -> bool:
	var first := PassGrid.cell_of(rect.position + Vector2.ONE)
	var last := PassGrid.cell_of(rect.end - Vector2.ONE)
	for j in range(first.y, last.y + 1):
		for i in range(first.x, last.x + 1):
			if not PassGrid.is_road(i, j):
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

func _colors_equal_approx(a: Color, b: Color, tolerance: float) -> bool:
	return (is_equal_approx(a.r, b.r) or absf(a.r - b.r) <= tolerance) \
		and (is_equal_approx(a.g, b.g) or absf(a.g - b.g) <= tolerance) \
		and (is_equal_approx(a.b, b.b) or absf(a.b - b.b) <= tolerance) \
		and (is_equal_approx(a.a, b.a) or absf(a.a - b.a) <= tolerance)

func _cell_span_rect(cells: Rect2i) -> Rect2:
	return Rect2(PassGrid.ORIGIN + Vector2(cells.position) * PassGrid.CELL,
		Vector2(cells.size) * PassGrid.CELL)

func _road_mark_segments(marks: Node2D) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for mark: Node2D in marks.get_children():
		var points: PackedVector2Array = mark.get("points")
		for i in points.size() - 1:
			segments.append({"mark": mark.name, "index": i, "a": points[i], "b": points[i + 1]})
	return segments

func _point_on_road_line(point: Vector2) -> bool:
	for leg_name in PassGrid.ROAD_LEGS:
		var cells: Rect2i = PassGrid.ROAD_LEGS[leg_name]
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				var rect := PassGrid.cell_rect(i, j)
				if point.x < rect.position.x or point.x > rect.end.x \
						or point.y < rect.position.y or point.y > rect.end.y:
					continue
				if is_equal_approx(point.x, rect.position.x) \
						or is_equal_approx(point.x, rect.end.x) \
						or is_equal_approx(point.y, rect.position.y) \
						or is_equal_approx(point.y, rect.end.y) \
						or is_equal_approx(point.x, rect.get_center().x) \
						or is_equal_approx(point.y, rect.get_center().y):
					return true
	return false

func _segment_hits_rect_interior(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var interior := rect.grow(-0.01)
	if is_equal_approx(a.y, b.y):
		var start := minf(a.x, b.x)
		var end := maxf(a.x, b.x)
		return a.y >= interior.position.y and a.y <= interior.end.y \
			and start < interior.end.x and end > interior.position.x
	var start := minf(a.y, b.y)
	var end := maxf(a.y, b.y)
	return a.x >= interior.position.x and a.x <= interior.end.x \
		and start < interior.end.y and end > interior.position.y

func _segments_share_endpoint(a: Dictionary, b: Dictionary) -> bool:
	return a["a"] == b["a"] or a["a"] == b["b"] \
		or a["b"] == b["a"] or a["b"] == b["b"]

func _axis_segments_conflict(a: Dictionary, b: Dictionary) -> bool:
	var allowed_endpoint: bool = a["mark"] == b["mark"] and _segments_share_endpoint(a, b)
	var a_horizontal: bool = is_equal_approx(a["a"].y, a["b"].y)
	var b_horizontal: bool = is_equal_approx(b["a"].y, b["b"].y)
	if a_horizontal and b_horizontal:
		if not is_equal_approx(a["a"].y, b["a"].y):
			return false
		var overlap_start := maxf(minf(a["a"].x, a["b"].x), minf(b["a"].x, b["b"].x))
		var overlap_end := minf(maxf(a["a"].x, a["b"].x), maxf(b["a"].x, b["b"].x))
		return overlap_start < overlap_end \
			or is_equal_approx(overlap_start, overlap_end) and not allowed_endpoint
	if not a_horizontal and not b_horizontal:
		if not is_equal_approx(a["a"].x, b["a"].x):
			return false
		var overlap_start := maxf(minf(a["a"].y, a["b"].y), minf(b["a"].y, b["b"].y))
		var overlap_end := minf(maxf(a["a"].y, a["b"].y), maxf(b["a"].y, b["b"].y))
		return overlap_start < overlap_end \
			or is_equal_approx(overlap_start, overlap_end) and not allowed_endpoint
	var horizontal: Dictionary = a if a_horizontal else b
	var vertical: Dictionary = b if a_horizontal else a
	var intersects: bool = vertical["a"].x >= minf(horizontal["a"].x, horizontal["b"].x) \
		and vertical["a"].x <= maxf(horizontal["a"].x, horizontal["b"].x) \
		and horizontal["a"].y >= minf(vertical["a"].y, vertical["b"].y) \
		and horizontal["a"].y <= maxf(vertical["a"].y, vertical["b"].y)
	return intersects and not allowed_endpoint

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

func test_road_legs_are_the_signed_off_connected_route() -> void:
	var expected := {
		&"trailhead_ew": Rect2i(2, 27, 8, 2),
		&"climb_ns": Rect2i(8, 23, 2, 6),
		&"saddle_ew": Rect2i(8, 23, 10, 2),
		&"knoll_ns": Rect2i(16, 17, 2, 8),
		&"apron": Rect2i(15, 9, 5, 8),
		&"upper_ew": Rect2i(17, 7, 8, 2),
		&"summit_ns": Rect2i(23, 3, 2, 6),
		&"overlook_ew": Rect2i(20, 2, 9, 2),
	}
	t.check(PassGrid.ROAD_LEGS == expected,
		"pass surfaces: road legs retain the reviewer-approved grid rectangles")
	var road_cells := {}
	var invalid: Array[Vector2i] = []
	var knoll: Rect2i = PassGrid.KNOLL["cells"]
	for leg_name in PassGrid.ROAD_LEGS:
		var cells: Rect2i = PassGrid.ROAD_LEGS[leg_name]
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				var cell := Vector2i(i, j)
				road_cells[cell] = true
				var apron_chasm: bool = leg_name == &"apron" \
					and _is_pit_kind(PassGrid.kind_at(i, j))
				if (not PassGrid.is_driveable(i, j) and not apron_chasm) \
						or knoll.has_point(cell):
					invalid.append(cell)
	var seen := _component(road_cells, false)
	t.check(invalid.is_empty() and seen.size() == road_cells.size(),
		"pass surfaces: road is one 4-connected driveable route off the knoll; bad %s"
		% [invalid])
	t.check(PassGrid.road_rects().size() == PassGrid.ROAD_LEGS.size(),
		"pass surfaces: every road leg has one world rectangle")

func test_ice_cells_are_signed_off_road_bends() -> void:
	var expected := {
		&"bend_low": Rect2i(8, 23, 2, 2),
		&"bend_mid": Rect2i(17, 7, 2, 2),
		&"bend_top": Rect2i(23, 2, 2, 2),
	}
	t.check(PassGrid.ICE == expected,
		"pass surfaces: ice retains the three reviewer-approved bend rectangles")
	var invalid: Array[Vector2i] = []
	for bend_name in PassGrid.ICE:
		var cells: Rect2i = PassGrid.ICE[bend_name]
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				if not PassGrid.is_road(i, j):
					invalid.append(Vector2i(i, j))
	t.check(invalid.is_empty() and PassGrid.ice_rects().size() == PassGrid.ICE.size(),
		"pass surfaces: all ice cells lie on road and every bend has a world rectangle; bad %s"
		% [invalid])

func test_snow_tiles_exactly_cover_driveable_non_road_cells() -> void:
	var tiles := PassGrid.snow_tiles()
	var invalid: Array[Vector3i] = []
	for j in PassGrid.N:
		for i in PassGrid.N:
			var hits := 0
			for rect: Rect2 in tiles:
				hits += 1 if rect.has_point(PassGrid.cell_center(i, j)) else 0
			var want := 1 if PassGrid.is_driveable(i, j) and not PassGrid.is_road(i, j) else 0
			if hits != want:
				invalid.append(Vector3i(i, j, hits))
	t.check(not tiles.is_empty() and invalid.is_empty(),
		"pass surfaces: snow tiles cover every driveable non-road cell exactly once; bad %s"
		% [invalid])

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
		var paved_lane := Rect2(Vector2(center.x - 112.0,
			center.y + (-412.0 if north else 112.0)), Vector2(224, 300))
		t.check(_rect_driveable(pad_rect), "pass grid: pad %s square is driveable" % name)
		t.check(_rect_road(pad_rect) and _rect_road(paved_lane),
			"pass surfaces: pad %s and its 300px apron lane are asphalt" % name)
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
		if child_a.name.begins_with("Block") or child_a.name.begins_with("Snow"):
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
			if child_a.name.begins_with("Snow") \
					and child_a.get("terrain_type") != child_b.get("terrain_type"):
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

func test_furniture_geometry_contract() -> void:
	var errors := FurnitureChecks.geometry_errors()
	t.check(errors.is_empty(), "pass furniture: placement geometry is safe; %s" % [errors])

func test_furniture_generated_scene_contract() -> void:
	var errors := FurnitureChecks.scene_errors()
	t.check(errors.is_empty(), "pass furniture: builder and generated scene agree; %s" % [errors])

func test_furniture_economy_and_ambient_contract() -> void:
	var errors := FurnitureChecks.level_errors()
	t.check(errors.is_empty(), "pass furniture: economy and ambient routes are safe; %s" % [errors])

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

func test_built_snow_is_one_field_of_collision_only_tiles() -> void:
	var root := PassBuilder.build_snow()
	var rects := PassGrid.snow_tiles()
	var invalid: Array[StringName] = []
	for i in root.get_child_count():
		var zone := root.get_child(i) as Area2D
		var col := zone.get_node_or_null(^"Col") as CollisionShape2D if zone else null
		var shape := col.shape as RectangleShape2D if col else null
		var actual := Rect2(zone.position - shape.size * 0.5, shape.size) \
			if zone != null and shape != null else Rect2()
		if zone == null or zone.name != "Snow%02d" % (i + 1) \
				or zone.get_script() != TerrainZoneScript or zone.collision_layer != 128 \
				or zone.collision_mask != 0 or zone.get("terrain_type") != &"snow" \
				or zone.get_node_or_null(^"Vis") != null or actual != rects[i]:
			invalid.append(root.get_child(i).name)
	t.check(root.name == &"SnowCover" and root.get_script() == TerrainFieldScript \
			and root.get("bounds") == PassGrid.ARENA_RECT and root.get("paint_seed") == 4096 \
			and root.get_child_count() == rects.size() and invalid.is_empty(),
		"pass snow: TerrainField root owns ordered collision-only snow tiles; bad %s"
		% [invalid])
	root.free()

func test_generated_snow_scene_builds_one_valid_skin() -> void:
	var packed: PackedScene = load("res://levels/snowy/pass_snow.tscn")
	var snow := packed.instantiate() as Node2D
	t.root.add_child(snow)
	await t.process_frame
	var warnings: PackedStringArray = snow.call("validation_warnings")
	var loops: Array = snow.call("outline_loops")
	var valid := not loops.is_empty()
	for loop: PackedVector2Array in loops:
		valid = valid and UnionSkin.triangulates(loop)
	t.check(warnings.is_empty() and valid,
		"pass snow: generated field has one valid warning-free union skin; warnings %s"
		% [warnings])
	t.root.remove_child(snow)
	snow.free()

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
	var built_snow := PassBuilder.build_snow()
	var built_mountain := PassBuilder.build_mountain()
	var built_drop := PassBuilder.build_drop()
	var built_rails := PassBuilder.build_rails()
	var saved_snow: Node2D = load("res://levels/snowy/pass_snow.tscn").instantiate()
	var saved_mountain: Node2D = load(
		"res://levels/snowy/pass_mountain.tscn").instantiate()
	var saved_drop: Node2D = load("res://levels/snowy/pass_drop.tscn").instantiate()
	var saved_rails: Node2D = load("res://levels/snowy/pass_rails.tscn").instantiate()
	var same := _same_built_tree(built_snow, saved_snow) \
		and _same_built_tree(built_mountain, saved_mountain) \
		and _same_built_tree(built_drop, saved_drop) \
		and _same_built_tree(built_rails, saved_rails)
	t.check(same, "pass carve: generated scenes are current; run tools/carve_pass.gd")
	for tree: Node2D in [built_snow, built_mountain, built_drop, built_rails,
			saved_snow, saved_mountain, saved_drop, saved_rails]:
		tree.free()

func test_pass_builder_is_deterministic() -> void:
	var snow_a := PassBuilder.build_snow()
	var snow_b := PassBuilder.build_snow()
	var mountain_a := PassBuilder.build_mountain()
	var mountain_b := PassBuilder.build_mountain()
	var drop_a := PassBuilder.build_drop()
	var drop_b := PassBuilder.build_drop()
	var rails_a := PassBuilder.build_rails()
	var rails_b := PassBuilder.build_rails()
	t.check(_same_built_tree(snow_a, snow_b),
		"pass carve: two snow builds have identical trees")
	t.check(_same_built_tree(mountain_a, mountain_b),
		"pass carve: two mountain builds have identical trees")
	t.check(_same_built_tree(drop_a, drop_b),
		"pass carve: two drop builds have identical trees")
	t.check(_same_built_tree(rails_a, rails_b),
		"pass carve: two rail builds have identical trees")
	for tree: Node2D in [snow_a, snow_b, mountain_a, mountain_b, drop_a, drop_b,
			rails_a, rails_b]:
		tree.free()

func test_level_instances_generated_geometry_before_gameplay() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var grid := level.get_node_or_null(^"GridFloor") as Node2D
	var snow := level.get_node_or_null(^"SnowCover") as Node2D
	var drop := level.get_node_or_null(^"Drop") as Node2D
	var mountain := level.get_node_or_null(^"Mountain") as Node2D
	var bridge := level.get_node_or_null(^"BridgeDeck") as Node2D
	var rails := level.get_node_or_null(^"Rails") as Node2D
	t.check(snow != null and snow.scene_file_path == "res://levels/snowy/pass_snow.tscn",
		"pass level: SnowCover is a direct instance of the generated snow scene")
	t.check(drop != null and drop.scene_file_path == "res://levels/snowy/pass_drop.tscn",
		"pass level: Drop is a direct instance of the generated drop scene")
	t.check(mountain != null
			and mountain.scene_file_path == "res://levels/snowy/pass_mountain.tscn",
		"pass level: Mountain is a direct instance of the generated mountain scene")
	t.check(rails != null and rails.scene_file_path == "res://levels/snowy/pass_rails.tscn",
		"pass level: Rails is a direct instance of the generated rail scene")
	if grid != null and snow != null and drop != null and mountain != null \
			and bridge != null and rails != null:
		t.check(drop.get_parent() == level and mountain.get_parent() == level
				and snow.get_parent() == level and rails.get_parent() == level \
				and snow.get_index() == grid.get_index() + 1 \
				and snow.get_index() < drop.get_index() and snow.get_index() < mountain.get_index() \
				and drop.get_index() < mountain.get_index()
				and bridge.get_index() < rails.get_index(),
			"pass level: generated snow/drop/mountain/rails use the required root order")
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

func test_level_runaway_ramp_and_reward_ledge_match_grid() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var ramp := level.get_node_or_null(^"RunawayRamp") as Ramp
	var floor_zone := level.get_node_or_null(^"FZLedge") as Area2D
	var terrain := level.get_node_or_null(^"LedgeTerrain") as TerrainZone
	var bed := level.get_node_or_null(^"RunawayBed") as Node2D
	var crate := level.get_node_or_null(^"AmmoPowerLedge") as Area2D
	var up := level.get_node_or_null(^"ConRunawayUp") as FloorConnector
	var down := level.get_node_or_null(^"ConRunawayDown") as FloorConnector
	var spur: Rect2i = PassGrid.SPUR_DATA["cells"]
	var ledge: Rect2i = PassGrid.LEDGE_DATA["cells"]
	var spur_rect := Rect2(PassGrid.ORIGIN + Vector2(spur.position) * PassGrid.CELL,
		Vector2(spur.size) * PassGrid.CELL)
	var ledge_rect := Rect2(PassGrid.ORIGIN + Vector2(ledge.position) * PassGrid.CELL,
		Vector2(ledge.size) * PassGrid.CELL)
	t.check(ramp != null and ramp.get_parent() == level
			and ramp.position == spur_rect.get_center()
			and is_equal_approx(ramp.rotation, -PI * 0.5)
			and ramp.size == Vector2(spur_rect.size.y, spur_rect.size.x)
			and ramp.low_floor == int(PassGrid.SPUR_DATA["from_floor"])
			and ramp.high_floor == int(PassGrid.SPUR_DATA["to_floor"])
			and ramp.terrain_type == "mud" and is_equal_approx(ramp.downhill_pull, 120.0)
			and not ramp.rails and ramp.surface_color == Color(0.36, 0.33, 0.30),
		"pass runaway: ramp exactly fills the west-climbing signed-off spur")
	t.check(floor_zone != null and floor_zone.scene_file_path.ends_with("floor_zone.tscn")
			and floor_zone.position == ledge_rect.get_center()
			and floor_zone.get("size") == ledge_rect.size
			and int(floor_zone.get("floor_index")) == int(PassGrid.LEDGE_DATA["floor"]),
		"pass runaway: floor-3 zone exactly fills the signed-off ledge")
	var vis := terrain.get_node_or_null(^"Vis") as Polygon2D if terrain else null
	var col := terrain.get_node_or_null(^"Col") as CollisionShape2D if terrain else null
	var shape := col.shape as RectangleShape2D if col else null
	var expected_ledge_color := ramp.surface_color.blend(
		Color(1.0, 1.0, 1.0, Ramp.HILITE_A)) if ramp else Color()
	t.check(terrain != null and terrain.position == ledge_rect.get_center()
			and terrain.terrain_type == &"mud" and not terrain.soften_visual
			and vis != null
			and shape != null and shape.size == ledge_rect.size,
		"pass runaway: ledge gravel paint and mud handling share one footprint")
	var got_ledge_color := vis.color if vis else Color()
	t.check(vis != null and _colors_equal_approx(got_ledge_color, expected_ledge_color, 0.002),
		"pass runaway: ledge color %s matches ramp high-end %s within 0.002 per channel"
		% [got_ledge_color, expected_ledge_color])
	var crate_cell: Vector2i = PassGrid.LEDGE_DATA["crate"]["cell"]
	t.check(crate != null and crate.position == PassGrid.cell_center(crate_cell.x, crate_cell.y)
			and crate.get("kind") == "power" and int(crate.get("amount")) == 1
			and int(crate.get("floor_index")) == 3,
		"pass runaway: one power crate is floor-gated at the signed-off ledge cell")
	var routes := [
		{"node": up, "from": 2, "to": 3, "approach": Vector2.LEFT},
		{"node": down, "from": 3, "to": 2, "approach": Vector2.RIGHT},
	]
	for route in routes:
		var connector := route["node"] as FloorConnector
		t.check(connector != null and connector.position == spur_rect.get_center()
				and connector.from_floor == route["from"] and connector.to_floor == route["to"]
				and connector.approach_dir == route["approach"]
				and connector.kind == &"grade",
			"pass runaway: paired grade connector matches %s->%s route" %
				[route["from"], route["to"]])
	t.check(bed != null and bed.get_script() == PassDecoScript
			and bed.position == (spur_rect.merge(ledge_rect)).get_center()
			and bed.get("size") == spur_rect.merge(ledge_rect).size
			and bed.get("kind") == &"runaway_bed",
		"pass runaway: paint-only bed exactly spans the ledge and spur")
	if ramp != null and terrain != null and bed != null and crate != null:
		t.check(ramp.get_index() < bed.get_index() and terrain.get_index() < bed.get_index()
				and bed.get_index() < crate.get_index(),
			"pass runaway: gravel detail draws over both surfaces and below the crate")
	level.free()

func test_level_runaway_notch_is_clear_and_deco_is_paint_only() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var mountain := level.get_node_or_null(^"Mountain") as Node2D
	var bed := level.get_node_or_null(^"RunawayBed") as Node2D
	var occupied: Array[Vector2i] = []
	for area in [PassGrid.SPUR_DATA["cells"], PassGrid.LEDGE_DATA["cells"]]:
		var cells: Rect2i = area
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				var interior := PassGrid.cell_rect(i, j).grow(-0.01)
				for block: Node2D in mountain.get_children() if mountain else []:
					if not block is StaticBody2D:
						continue
					var col := block.get_node_or_null(^"Col") as CollisionShape2D
					var shape := col.shape as RectangleShape2D if col else null
					if shape and Rect2(block.position - shape.size * 0.5,
							shape.size).intersects(interior):
						occupied.append(Vector2i(i, j))
	t.check(mountain != null and occupied.is_empty(),
		"pass runaway: instanced mountain blocks leave every spur and ledge cell clear; bad %s"
		% [occupied])
	var collisions := bed.find_children("*", "CollisionObject2D", true, false) if bed else []
	t.check(bed != null and not bed is CollisionObject2D and collisions.is_empty(),
		"pass runaway: RunawayBed and all descendants stay paint-only")
	if bed != null:
		level.remove_child(bed)
		bed.owner = null
		t.root.add_child(bed)
		await t.process_frame
		t.check(bed.is_inside_tree(), "pass runaway: RunawayBed draws for one frame")
		t.root.remove_child(bed)
		bed.free()
	level.free()

func test_level_mountain_uses_level_materials() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var mountain := level.get_node_or_null(^"Mountain") as MountainWall
	var snow := level.get_node_or_null(^"SnowCover") as TerrainField
	var asphalt := level.get_node_or_null(^"Asphalt") as Polygon2D
	var hill := level.get_node_or_null(^"SnowyHill") as DriveableHill
	t.check(mountain != null and snow != null and asphalt != null and hill != null
			and mountain.substrate_material == asphalt.material
			and mountain.terrain_material == hill.terrain_material
			and snow.terrain_material == hill.terrain_material,
		"pass level: Mountain and SnowCover receive the scene asphalt/snow materials")
	level.free()

func test_level_ice_zones_match_the_grid() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var snow := level.get_node_or_null(^"SnowCover") as Node2D
	var expected := {
		&"IceBendLow": &"bend_low",
		&"IceBendMid": &"bend_mid",
		&"IceBendTop": &"bend_top",
	}
	var material: Material
	var invalid: Array[StringName] = []
	for node_name: StringName in expected:
		var zone := level.get_node_or_null(NodePath(node_name)) as Area2D
		var cells: Rect2i = PassGrid.ICE[expected[node_name]]
		var rect := Rect2(PassGrid.ORIGIN + Vector2(cells.position) * PassGrid.CELL,
			Vector2(cells.size) * PassGrid.CELL)
		var vis := zone.get_node_or_null(^"Vis") as Polygon2D if zone else null
		var col := zone.get_node_or_null(^"Col") as CollisionShape2D if zone else null
		var shape := col.shape as RectangleShape2D if col else null
		if material == null and vis != null:
			material = vis.material
		if zone == null or zone.get_script() != TerrainZoneScript \
				or zone.position != rect.get_center() or zone.collision_layer != 128 \
				or zone.collision_mask != 0 or zone.get("terrain_type") != &"ice" \
				or vis == null or vis.material != material or shape == null \
				or shape.size != Vector2(256, 256) or zone.get_index() < snow.get_index():
			invalid.append(node_name)
	t.check(invalid.is_empty(),
		"pass level: three material-matched 256px ice zones follow snow on ICE cells; bad %s"
		% [invalid])
	level.free()

func test_level_road_marks_turn_without_crossing_and_clear_features() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var marks := level.get_node_or_null(^"RoadMarks") as Node2D
	var trailhead := _cell_span_rect(PassGrid.ROAD_LEGS[&"trailhead_ew"])
	var climb := _cell_span_rect(PassGrid.ROAD_LEGS[&"climb_ns"])
	var saddle := _cell_span_rect(PassGrid.ROAD_LEGS[&"saddle_ew"])
	var knoll := _cell_span_rect(PassGrid.ROAD_LEGS[&"knoll_ns"])
	var apron := _cell_span_rect(PassGrid.ROAD_LEGS[&"apron"])
	var upper := _cell_span_rect(PassGrid.ROAD_LEGS[&"upper_ew"])
	var summit := _cell_span_rect(PassGrid.ROAD_LEGS[&"summit_ns"])
	var overlook := _cell_span_rect(PassGrid.ROAD_LEGS[&"overlook_ew"])
	var low_ice := _cell_span_rect(PassGrid.ICE[&"bend_low"])
	var mid_ice := _cell_span_rect(PassGrid.ICE[&"bend_mid"])
	var top_ice := _cell_span_rect(PassGrid.ICE[&"bend_top"])
	var bridge_start := PassGrid.ORIGIN + Vector2(
		PassGrid.BRIDGE_COLS.x, PassGrid.CHASM_ROWS.x) * PassGrid.CELL
	var bridge_size := Vector2(
		(PassGrid.BRIDGE_COLS.y - PassGrid.BRIDGE_COLS.x + 1) * PassGrid.CELL,
		(PassGrid.CHASM_ROWS.y - PassGrid.CHASM_ROWS.x + 1) * PassGrid.CELL)
	var bridge := Rect2(bridge_start, bridge_size)
	var expected := {
		&"Trailhead": PackedVector2Array([
			Vector2(trailhead.position.x, trailhead.get_center().y),
			Vector2(climb.get_center().x, trailhead.get_center().y),
			Vector2(climb.get_center().x, low_ice.end.y),
		]),
		&"Saddle": PackedVector2Array([
			Vector2(PassGrid.STATION["center"].x + 96.0, saddle.get_center().y),
			Vector2(knoll.get_center().x, saddle.get_center().y),
			Vector2(knoll.get_center().x, apron.end.y + PassGrid.CELL),
		]),
		&"Bridge": PackedVector2Array([
			Vector2(bridge.get_center().x, apron.end.y - PassGrid.CELL),
			Vector2(bridge.get_center().x, mid_ice.end.y),
		]),
		&"Upper": PackedVector2Array([
			Vector2(mid_ice.end.x, upper.get_center().y),
			Vector2(summit.get_center().x, upper.get_center().y),
			Vector2(summit.get_center().x, top_ice.end.y),
		]),
		&"OverlookWest": PackedVector2Array([
			Vector2(overlook.position.x, overlook.get_center().y),
			Vector2(top_ice.position.x, overlook.get_center().y),
		]),
		&"OverlookEast": PackedVector2Array([
			Vector2(top_ice.end.x, overlook.get_center().y),
			Vector2(overlook.end.x, overlook.get_center().y),
		]),
	}
	var invalid: Array[StringName] = []
	for mark_name: StringName in expected:
		var mark := marks.get_node_or_null(NodePath(mark_name)) as Node2D if marks else null
		var points: PackedVector2Array = mark.get("points") if mark else PackedVector2Array()
		var valid: bool = mark != null and mark.get_script() == RoadMarksScript \
			and mark.get("style") == &"dashed_yellow" and points == expected[mark_name]
		if not valid:
			invalid.append(mark_name)
	if marks:
		for mark: Node2D in marks.get_children():
			if not expected.has(mark.name):
				invalid.append(mark.name)
	t.check(marks != null and marks.get_child_count() == expected.size() and invalid.is_empty(),
		"pass marks: six dashed polylines match the grid-derived switchback route; bad %s"
		% [invalid])
	var segments := _road_mark_segments(marks) if marks else []
	var bad_vertices := PackedVector2Array()
	var bad_segments: Array[Dictionary] = []
	for mark: Node2D in marks.get_children() if marks else []:
		var points: PackedVector2Array = mark.get("points")
		for point: Vector2 in points:
			if not _point_on_road_line(point):
				bad_vertices.append(point)
	for segment: Dictionary in segments:
		var a: Vector2 = segment["a"]
		var b: Vector2 = segment["b"]
		if a == b or (not is_equal_approx(a.x, b.x) and not is_equal_approx(a.y, b.y)):
			bad_segments.append(segment)
	t.check(bad_vertices.is_empty() and bad_segments.is_empty(),
		("pass marks: every vertex is on a road-cell line and every segment is "
		+ "axis-aligned; bad vertices %s segments %s") % [bad_vertices, bad_segments])
	var conflicts: Array = []
	for i in segments.size():
		for j in range(i + 1, segments.size()):
			if _axis_segments_conflict(segments[i], segments[j]):
				conflicts.append([segments[i], segments[j]])
	t.check(conflicts.is_empty(),
		"pass marks: no two painted segments cross or overlap; conflicts %s" % [conflicts])
	var unsafe: Array[Dictionary] = []
	var bridge_segments: Array[Dictionary] = []
	for segment: Dictionary in segments:
		var a: Vector2 = segment["a"]
		var b: Vector2 = segment["b"]
		var bad := false
		for ice: Rect2 in PassGrid.ice_rects():
			bad = bad or _segment_hits_rect_interior(a, b, ice)
		var station: Vector2 = PassGrid.STATION["center"]
		bad = bad or station.distance_to(
			Geometry2D.get_closest_point_to_segment(station, a, b)) < 96.0
		for pad_name in PassGrid.PADS:
			var center: Vector2 = PassGrid.PADS[pad_name]["center"]
			bad = bad or center.distance_to(
				Geometry2D.get_closest_point_to_segment(center, a, b)) < 96.0
		if bad:
			unsafe.append(segment)
		if _segment_hits_rect_interior(a, b, bridge):
			bridge_segments.append(segment)
	t.check(unsafe.is_empty(),
		"pass marks: segments clear ice, the repair station, and jump pads; bad %s" % [unsafe])
	var bridge_centered := bridge_segments.size() == 1
	if bridge_centered:
		var segment: Dictionary = bridge_segments[0]
		bridge_centered = is_equal_approx(segment["a"].x, bridge.get_center().x) \
			and is_equal_approx(segment["b"].x, bridge.get_center().x)
	t.check(bridge_centered,
		"pass marks: exactly one segment crosses bridge cells at centre x; got %s"
		% [bridge_segments])
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

func test_level_places_pads_station_and_knoll_on_grid() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	var jump_nw := level.get_node_or_null(^"JumpNW") as Area2D
	var jump_sw := level.get_node_or_null(^"JumpSW") as Area2D
	var station := level.get_node_or_null(^"HealthStation1") as Node2D
	var hill := level.get_node_or_null(^"SnowyHill") as DriveableHill
	t.check(jump_nw != null and jump_nw.position == PassGrid.PADS[&"north_west"]["center"]
			and int(jump_nw.get("floor_index")) == 2
			and not bool(jump_nw.get("launch_rivals")),
		"pass level: JumpNW matches the floor-2 rival-filtered grid pad")
	t.check(jump_sw != null and jump_sw.position == PassGrid.PADS[&"south_west"]["center"]
			and int(jump_sw.get("floor_index")) == 2
			and not bool(jump_sw.get("launch_rivals")),
		"pass level: JumpSW matches the floor-2 rival-filtered grid pad")
	t.check(station != null and station.position == PassGrid.STATION["center"],
		"pass level: repair station matches the grid")
	t.check(hill != null and hill.position == PassGrid.KNOLL["center"]
			and hill.summit_size == Vector2.ONE * float(PassGrid.KNOLL["summit"])
			and is_equal_approx(hill.grade_length, float(PassGrid.KNOLL["grade_length"])),
		"pass level: SnowyHill matches the signed-off knoll")
	level.free()

func test_level_lethal_hazards_are_only_pits() -> void:
	var level := (load("res://levels/snowy/snowy.tscn") as PackedScene).instantiate()
	level.set("mp_managed", true)
	var economy = preload("res://game/economy.gd")
	var economy_enabled: bool = economy.enabled
	t.root.add_child(level)
	var hazards: Array[Node] = []
	var wrong_scripts := PackedStringArray()
	for node: Node in t.get_nodes_in_group(&"lethal_hazards"):
		if node != level and not level.is_ancestor_of(node):
			continue
		hazards.append(node)
		if node.get_script() != PitZoneScript:
			var script := node.get_script() as Script
			wrong_scripts.append(script.resource_path if script != null else node.get_class())
	t.check(not hazards.is_empty() and wrong_scripts.is_empty(),
		"pass level: lethal hazards are pit zones only; bad scripts %s" % [wrong_scripts])
	t.root.remove_child(level)
	level.free()
	economy.enabled = economy_enabled

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
		&"CenterMidW", &"CenterMidE", &"CenterS", &"Sign1", &"Enemy5",
		&"Enemy6", &"AmmoPower2",
	]
	var survivors: Array[StringName] = []
	for old_name: StringName in removed:
		if level.find_child(String(old_name), true, false) != null:
			survivors.append(old_name)
	var road_marks := level.get_node_or_null(^"RoadMarks")
	t.check(survivors.is_empty(), "pass level: removed snowfield nodes stay gone; found %s" %
		[survivors])
	t.check(road_marks != null and road_marks.get_child_count() == 6,
		"pass level: RoadMarks owns the six switchback centerline polylines")
	level.free()
