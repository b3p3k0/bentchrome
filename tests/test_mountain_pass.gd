extends RefCounted
## Pure contract checks for the signed-off Mountainside Mayhem pass grid.

const PassGrid := preload("res://levels/snowy/pass_grid.gd")

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
	"############################            J^     |................",
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
	t.check(got == PackedStringArray(GOLDEN), "pass grid: render matches signed-off golden character for character")
