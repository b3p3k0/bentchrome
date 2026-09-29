extends RefCounted
## Signed-off Mountainside Mayhem pass layout. Dependency-free on purpose:
## no class_name, nodes, drawing, or preloads. Consumers preload by path.

const CELL := 128
const N := 32
const OVERLAP := 64
const ORIGIN := Vector2(-2048, -2048)
const ARENA_SIZE := Vector2(4096, 4096)
const ARENA_RECT := Rect2(ORIGIN, ARENA_SIZE)

const MOUNTAIN := &"mountain"
const ROAD := &"road"
const DROP := &"drop"
const BRIDGE := &"bridge"
const WEST_PIT := &"west_pit"
const EAST_PIT := &"east_pit"
const SPUR := &"spur"
const LEDGE := &"ledge"

const ROWS := {
	1: Vector2i(20, 30), 2: Vector2i(19, 30), 3: Vector2i(19, 30),
	4: Vector2i(18, 30), 5: Vector2i(18, 29), 6: Vector2i(16, 27),
	7: Vector2i(15, 26), 8: Vector2i(14, 25), 9: Vector2i(14, 23),
	10: Vector2i(14, 23), 11: Vector2i(14, 23), 12: Vector2i(14, 23),
	13: Vector2i(14, 23), 14: Vector2i(14, 23), 15: Vector2i(14, 23),
	16: Vector2i(13, 23), 17: Vector2i(9, 23), 18: Vector2i(8, 23),
	19: Vector2i(7, 22), 20: Vector2i(7, 22), 21: Vector2i(6, 21),
	22: Vector2i(6, 20), 23: Vector2i(4, 18), 24: Vector2i(3, 17),
	25: Vector2i(2, 14), 26: Vector2i(1, 12), 27: Vector2i(1, 10),
	28: Vector2i(1, 10), 29: Vector2i(1, 10), 30: Vector2i(1, 10),
}
const CHASM_ROWS := Vector2i(12, 13)
const BRIDGE_COLS := Vector2i(17, 19)
# The south cap row is mountain up to this column and drop beyond it.
const SOUTH_CAP_MOUNTAIN_COLS := 10

const KNOLL := {
	"center": Vector2(-256, 640), "footprint": 512, "summit": 320,
	"grade_length": 192, "cells": Rect2i(12, 19, 4, 4),
	"from_floor": 2, "to_floor": 3,
}
const PADS := {
	&"south_west": {
		"center": Vector2(0, -64), "size": Vector2(224, 224),
		"floor": 2, "launch": &"north", "lane_cols": Vector2i(15, 16),
	},
	&"north_west": {
		"center": Vector2(0, -704), "size": Vector2(224, 224),
		"floor": 2, "launch": &"south", "lane_cols": Vector2i(15, 16),
	},
}
const NO_GO := {
	&"lane_north": Rect2(-256, -896, 384, 384),
	&"lane_south": Rect2(-256, -256, 384, 384),
}
const SPUR_DATA := {
	"cells": Rect2i(3, 21, 3, 2), "size": Vector2(384, 256),
	"from_floor": 2, "to_floor": 3, "terrain": &"mud", "climbs": &"west",
}
const LEDGE_DATA := {
	"cells": Rect2i(1, 21, 2, 2), "size": Vector2(256, 256), "floor": 3,
	"crate": {"kind": &"power", "cell": Vector2i(1, 21)},
}
const SPAWNS := {
	&"P": {"cell": Vector2i(4, 28), "center": Vector2(-1472, 1600), "start_floor": 2},
	&"E1": {"cell": Vector2i(25, 3), "center": Vector2(1216, -1600), "start_floor": 2},
	&"E2": {"cell": Vector2i(20, 7), "center": Vector2(576, -1088), "start_floor": 2},
	&"E3": {"cell": Vector2i(19, 20), "center": Vector2(448, 576), "start_floor": 2},
	&"E4": {"cell": Vector2i(9, 21), "center": Vector2(-832, 704), "start_floor": 2},
}
const STATION := {"cell": Vector2i(10, 24), "center": Vector2(-704, 1088), "floor": 2}

const RAIL_THICKNESS := 12.0
const RAIL_RIM_INSET := 8.0
const RAIL_END_CLEARANCE := 16.0
const RAIL_MAX_LENGTH := 256.0

static func kind_at(i: int, j: int) -> StringName:
	if i < 0 or i >= N or j < 0 or j >= N:
		return MOUNTAIN
	var cell := Vector2i(i, j)
	var ledge_cells: Rect2i = LEDGE_DATA["cells"]
	var spur_cells: Rect2i = SPUR_DATA["cells"]
	if ledge_cells.has_point(cell):
		return LEDGE
	if spur_cells.has_point(cell):
		return SPUR
	if not ROWS.has(j):
		return MOUNTAIN if j == 0 or i <= SOUTH_CAP_MOUNTAIN_COLS else DROP
	var span: Vector2i = ROWS[j]
	if i < span.x:
		return MOUNTAIN
	if i > span.y:
		return DROP
	if j >= CHASM_ROWS.x and j <= CHASM_ROWS.y:
		if i >= BRIDGE_COLS.x and i <= BRIDGE_COLS.y:
			return BRIDGE
		return WEST_PIT if i < BRIDGE_COLS.x else EAST_PIT
	return ROAD

static func is_driveable(i: int, j: int) -> bool:
	var kind := kind_at(i, j)
	return kind == ROAD or kind == BRIDGE

static func cell_rect(i: int, j: int) -> Rect2:
	return Rect2(ORIGIN + Vector2(i, j) * CELL, Vector2(CELL, CELL))

static func cell_center(i: int, j: int) -> Vector2:
	return ORIGIN + (Vector2(i, j) + Vector2(0.5, 0.5)) * CELL

static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(
		floori((point.x - ORIGIN.x) / CELL),
		floori((point.y - ORIGIN.y) / CELL))

## Mountain collision rectangles, merged first across rows and then down only
## while the complete horizontal run remains identical.
static func mountain_blocks() -> Array[Rect2]:
	var blocks: Array[Rect2] = []
	var open_runs := {}
	for j in N:
		var runs: Array[Vector2i] = []
		var run_start := -1
		for i in N + 1:
			var mountain := i < N and kind_at(i, j) == MOUNTAIN
			if mountain and run_start < 0:
				run_start = i
			elif not mountain and run_start >= 0:
				runs.append(Vector2i(run_start, i))
				run_start = -1
		var next_runs := {}
		for run: Vector2i in runs:
			if open_runs.has(run):
				var index: int = open_runs[run]
				var block: Rect2 = blocks[index]
				block.size.y += CELL
				blocks[index] = block
				next_runs[run] = index
			else:
				var position := ORIGIN + Vector2(run.x, j) * CELL
				var size := Vector2((run.y - run.x) * CELL, CELL)
				blocks.append(Rect2(position, size))
				next_runs[run] = blocks.size() - 1
		open_runs = next_runs
	_sort_rects(blocks)
	return blocks

## Thin overlapping kill bands. Keeping every main-drop row separate limits a
## fall to the band's short centreline instead of pulling along the whole void.
static func drop_bands() -> Array[Rect2]:
	var bands: Array[Rect2] = []
	bands.append(_cell_span_rect(Rect2i(14, 12, 3, 2)))
	var east := _cell_span_rect(Rect2i(20, 12, 4, 2))
	east.size.x += OVERLAP
	bands.append(east)
	for j in range(1, N):
		var first_drop := SOUTH_CAP_MOUNTAIN_COLS + 1
		if ROWS.has(j):
			var span: Vector2i = ROWS[j]
			first_drop = span.y + 1
		var position := ORIGIN + Vector2(first_drop, j) * CELL
		var height := CELL if j == N - 1 else CELL + OVERLAP
		bands.append(Rect2(position,
			Vector2(ARENA_RECT.end.x - position.x, height)))
	_sort_rects(bands)
	return bands

## Invisible AI rails along each lethal edge which directly faces road or
## bridge. Runs merge on the grid before their guarded endcaps are considered.
static func rim_curbs() -> Array[Rect2]:
	var curbs: Array[Rect2] = []
	for boundary in range(1, N):
		_append_horizontal_curbs(curbs, boundary, -1)
		_append_horizontal_curbs(curbs, boundary, 1)
		_append_vertical_curbs(curbs, boundary, -1)
		_append_vertical_curbs(curbs, boundary, 1)
	_sort_rects(curbs)
	return curbs

## Breakaway guardrails follow the same lethal lips as the AI curbs. The west
## jump lane stays open so its facing pads can launch cleanly across the pit.
static func rail_segments() -> Array[Rect2]:
	var rails: Array[Rect2] = []
	for boundary in range(1, N):
		_append_horizontal_rails(rails, boundary, -1)
		_append_horizontal_rails(rails, boundary, 1)
		_append_vertical_rails(rails, boundary, -1)
		_append_vertical_rails(rails, boundary, 1)
	_sort_rects(rails)
	return rails

static func _cell_span_rect(cells: Rect2i) -> Rect2:
	return Rect2(ORIGIN + Vector2(cells.position) * CELL,
		Vector2(cells.size) * CELL)

static func _is_pit(i: int, j: int) -> bool:
	var kind := kind_at(i, j)
	return kind == DROP or kind == WEST_PIT or kind == EAST_PIT

static func _append_horizontal_curbs(
		curbs: Array[Rect2], boundary: int, road_side: int) -> void:
	var pit_row := boundary if road_side < 0 else boundary - 1
	var road_row := boundary - 1 if road_side < 0 else boundary
	var start := -1
	for i in N + 1:
		var exposed := i < N and _is_pit(i, pit_row) and is_driveable(i, road_row)
		if exposed and start < 0:
			start = i
		elif not exposed and start >= 0:
			var rim_start := ORIGIN.x + start * CELL
			var rim_end := ORIGIN.x + i * CELL
			var rim_y := ORIGIN.y + boundary * CELL
			var center_y := rim_y + road_side * 14.0
			var before := 24.0 if _curb_end_clear(Vector2(rim_start - 12.0,
				center_y)) else 0.0
			var after := 24.0 if _curb_end_clear(Vector2(rim_end + 12.0,
				center_y)) else 0.0
			curbs.append(Rect2(Vector2(rim_start - before, center_y - 12.0),
				Vector2(rim_end - rim_start + before + after, 24.0)))
			start = -1

static func _append_vertical_curbs(
		curbs: Array[Rect2], boundary: int, road_side: int) -> void:
	var pit_col := boundary if road_side < 0 else boundary - 1
	var road_col := boundary - 1 if road_side < 0 else boundary
	var start := -1
	for j in N + 1:
		var exposed := j < N and _is_pit(pit_col, j) and is_driveable(road_col, j)
		if exposed and start < 0:
			start = j
		elif not exposed and start >= 0:
			var rim_start := ORIGIN.y + start * CELL
			var rim_end := ORIGIN.y + j * CELL
			var rim_x := ORIGIN.x + boundary * CELL
			var center_x := rim_x + road_side * 14.0
			var before := 24.0 if _curb_end_clear(Vector2(center_x,
				rim_start - 12.0)) else 0.0
			var after := 24.0 if _curb_end_clear(Vector2(center_x,
				rim_end + 12.0)) else 0.0
			curbs.append(Rect2(Vector2(center_x - 12.0, rim_start - before),
				Vector2(24.0, rim_end - rim_start + before + after)))
			start = -1

static func _append_horizontal_rails(
		rails: Array[Rect2], boundary: int, road_side: int) -> void:
	var pit_row := boundary if road_side < 0 else boundary - 1
	var road_row := boundary - 1 if road_side < 0 else boundary
	var start := -1
	for i in N + 1:
		var exposed := i < N and _is_pit(i, pit_row) and is_driveable(i, road_row)
		if exposed and kind_at(i, pit_row) == WEST_PIT and _is_jump_lane_column(i):
			exposed = false
		if exposed and start < 0:
			start = i
		elif not exposed and start >= 0:
			var rim_start := ORIGIN.x + start * CELL + RAIL_END_CLEARANCE
			var rim_end := ORIGIN.x + i * CELL - RAIL_END_CLEARANCE
			var center_y := ORIGIN.y + boundary * CELL + road_side * RAIL_RIM_INSET
			_append_split_rail_run(rails, rim_start, rim_end, center_y, true)
			start = -1

static func _append_vertical_rails(
		rails: Array[Rect2], boundary: int, road_side: int) -> void:
	var pit_col := boundary if road_side < 0 else boundary - 1
	var road_col := boundary - 1 if road_side < 0 else boundary
	var start := -1
	for j in N + 1:
		var exposed := j < N and _is_pit(pit_col, j) and is_driveable(road_col, j)
		if exposed and start < 0:
			start = j
		elif not exposed and start >= 0:
			var rim_start := ORIGIN.y + start * CELL + RAIL_END_CLEARANCE
			var rim_end := ORIGIN.y + j * CELL - RAIL_END_CLEARANCE
			var center_x := ORIGIN.x + boundary * CELL + road_side * RAIL_RIM_INSET
			_append_split_rail_run(rails, rim_start, rim_end, center_x, false)
			start = -1

static func _is_jump_lane_column(column: int) -> bool:
	for pad_name in PADS:
		var pad: Dictionary = PADS[pad_name]
		var columns: Vector2i = pad["lane_cols"]
		if column >= columns.x and column <= columns.y:
			return true
	return false

static func _append_split_rail_run(
		rails: Array[Rect2], start: float, end: float, cross_axis: float,
		horizontal: bool) -> void:
	var length := end - start
	if length <= 0.0:
		return
	var segment_count := ceili(length / RAIL_MAX_LENGTH)
	var segment_length := length / segment_count
	for segment_index in segment_count:
		var along := start + segment_index * segment_length
		if horizontal:
			rails.append(Rect2(Vector2(along, cross_axis - RAIL_THICKNESS * 0.5),
				Vector2(segment_length, RAIL_THICKNESS)))
		else:
			rails.append(Rect2(Vector2(cross_axis - RAIL_THICKNESS * 0.5, along),
				Vector2(RAIL_THICKNESS, segment_length)))

static func _curb_end_clear(point: Vector2) -> bool:
	var cell := cell_of(point)
	var kind := kind_at(cell.x, cell.y)
	return kind != MOUNTAIN and not _is_pit(cell.x, cell.y)

static func _sort_rects(rects: Array[Rect2]) -> void:
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if a.position.y != b.position.y:
			return a.position.y < b.position.y
		if a.position.x != b.position.x:
			return a.position.x < b.position.x
		if a.size.y != b.size.y:
			return a.size.y < b.size.y
		return a.size.x < b.size.x)

static func clearance(point: Vector2) -> float:
	if not ARENA_RECT.has_point(point):
		return 0.0
	var arena_end := ARENA_RECT.end
	var best := minf(minf(point.x - ORIGIN.x, arena_end.x - point.x),
		minf(point.y - ORIGIN.y, arena_end.y - point.y))
	for j in N:
		for i in N:
			if is_driveable(i, j):
				continue
			var rect := cell_rect(i, j)
			var nearest := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y))
			best = minf(best, point.distance_to(nearest))
	return best

static func knoll_approaches() -> Dictionary:
	var center: Vector2 = KNOLL["center"]
	var summit_half: float = float(KNOLL["summit"]) * 0.5
	var cardinal := summit_half + 220.0
	var diagonal := summit_half + 250.0 / sqrt(2.0)
	return {
		&"N": center + Vector2.UP * cardinal,
		&"S": center + Vector2.DOWN * cardinal,
		&"E": center + Vector2.RIGHT * cardinal,
		&"W": center + Vector2.LEFT * cardinal,
		&"NE": center + Vector2(1, -1) * diagonal,
		&"NW": center + Vector2(-1, -1) * diagonal,
		&"SE": center + Vector2(1, 1) * diagonal,
		&"SW": center + Vector2(-1, 1) * diagonal,
	}

static func render() -> PackedStringArray:
	var features := {}
	var station_cell: Vector2i = STATION["cell"]
	features[station_cell] = "+ "
	for spawn_name in SPAWNS:
		var spawn: Dictionary = SPAWNS[spawn_name]
		var spawn_cell: Vector2i = spawn["cell"]
		features[spawn_cell] = String(spawn_name).rpad(2).left(2)
	for pad_name in PADS:
		var pad: Dictionary = PADS[pad_name]
		var center: Vector2 = pad["center"]
		var pad_cell := cell_of(Vector2(center.x - 1.0, center.y))
		features[pad_cell] = "J^" if pad["launch"] == &"north" else "Jv"
	var knoll_cells: Rect2i = KNOLL["cells"]
	for j in range(knoll_cells.position.y, knoll_cells.end.y):
		for i in range(knoll_cells.position.x, knoll_cells.end.x):
			features[Vector2i(i, j)] = "/\\"
	var knoll_center: Vector2 = KNOLL["center"]
	var knoll_cell := cell_of(knoll_center - Vector2.ONE)
	features[knoll_cell] = "K*"

	var crate: Dictionary = LEDGE_DATA["crate"]
	var crate_cell: Vector2i = crate["cell"]
	var lines := PackedStringArray()
	for j in N:
		var line := ""
		for i in N:
			var cell := Vector2i(i, j)
			var kind := kind_at(i, j)
			if cell == crate_cell:
				line += "p "
			elif kind == SPUR:
				line += "<<"
			elif kind == LEDGE:
				line += "LL"
			elif kind == MOUNTAIN:
				line += "##"
			elif kind == DROP:
				line += ".."
			elif kind == WEST_PIT or kind == EAST_PIT:
				line += "XX"
			elif kind == BRIDGE:
				line += "]["
			elif features.has(cell):
				line += String(features[cell])
			else:
				line += " |" if kind_at(i + 1, j) == DROP else "  "
		lines.append(line)
	return lines
