extends RefCounted
## Pure helpers for unions of axis-aligned rectangles. Boundary loops are
## implicitly closed: outer loops wind clockwise in screen space (y down),
## while holes wind counter-clockwise. Coordinates are snapped to 0.001.

const SNAP := 1000.0

static func _snap(value: float) -> float:
	return roundf(value * SNAP) / SNAP

static func _snap_point(point: Vector2) -> Vector2:
	return Vector2(_snap(point.x), _snap(point.y))

static func _valid_rects(rects: Array[Rect2]) -> Array[Rect2]:
	var valid: Array[Rect2] = []
	for rect in rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var begin := _snap_point(rect.position)
		var end := _snap_point(rect.end)
		if end.x > begin.x and end.y > begin.y:
			valid.append(Rect2(begin, end - begin))
	return valid

static func _inside(rects: Array[Rect2], point: Vector2) -> bool:
	for rect in rects:
		if point.x >= rect.position.x and point.x < rect.end.x \
				and point.y >= rect.position.y and point.y < rect.end.y:
			return true
	return false

static func contains(rects: Array[Rect2], point: Vector2) -> bool:
	return _inside(_valid_rects(rects), _snap_point(point))

static func _add_edge(starts: Array[Vector2], ends: Array[Vector2],
		outgoing: Dictionary, begin: Vector2, end: Vector2) -> void:
	starts.append(begin)
	ends.append(end)
	var indices: Array = outgoing.get(begin, [])
	indices.append(starts.size() - 1)
	outgoing[begin] = indices

static func _direction(begin: Vector2, end: Vector2) -> int:
	if end.x > begin.x:
		return 0  # east
	if end.y > begin.y:
		return 1  # south
	if end.x < begin.x:
		return 2  # west
	return 3  # north

static func _next_edge(current: int, starts: Array[Vector2], ends: Array[Vector2],
		outgoing: Dictionary, used: PackedByteArray) -> int:
	var candidates: Array = outgoing.get(ends[current], [])
	var incoming := _direction(starts[current], ends[current])
	var best := -1
	var best_rank := 5
	for value: Variant in candidates:
		var candidate: int = value
		if used[candidate] != 0:
			continue
		var turn := (_direction(starts[candidate], ends[candidate]) - incoming + 4) % 4
		var rank := 3
		if turn == 1:
			rank = 0  # prefer a right turn, separating corner-only contacts
		elif turn == 0:
			rank = 1
		elif turn == 3:
			rank = 2
		if rank < best_rank:
			best = candidate
			best_rank = rank
	return best

static func _simplify(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.size() < 3:
		return result
	for i in points.size():
		var before := points[(i - 1 + points.size()) % points.size()]
		var point := points[i]
		var after := points[(i + 1) % points.size()]
		var incoming := point - before
		var outgoing := after - point
		if incoming.cross(outgoing) != 0.0 or incoming.dot(outgoing) < 0.0:
			result.append(point)
	return result

static func _trace(first: int, starts: Array[Vector2], ends: Array[Vector2],
		outgoing: Dictionary, used: PackedByteArray) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start := starts[first]
	var current := first
	for _guard in starts.size() + 1:
		used[current] = 1
		points.append(starts[current])
		if ends[current] == start:
			break
		current = _next_edge(current, starts, ends, outgoing, used)
		if current < 0:
			return PackedVector2Array()
	return _simplify(points)

static func outline(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var valid := _valid_rects(rects)
	var loops: Array[PackedVector2Array] = []
	if valid.is_empty():
		return loops
	var xs: Array[float] = []
	var ys: Array[float] = []
	var seen_x := {}
	var seen_y := {}
	for rect in valid:
		for x: float in [rect.position.x, rect.end.x]:
			if not seen_x.has(x):
				seen_x[x] = true
				xs.append(x)
		for y: float in [rect.position.y, rect.end.y]:
			if not seen_y.has(y):
				seen_y[y] = true
				ys.append(y)
	xs.sort()
	ys.sort()
	var cells: Array[PackedByteArray] = []
	for y in ys.size() - 1:
		var row := PackedByteArray()
		row.resize(xs.size() - 1)
		for x in xs.size() - 1:
			var center := Vector2((xs[x] + xs[x + 1]) * 0.5,
				(ys[y] + ys[y + 1]) * 0.5)
			row[x] = 1 if _inside(valid, center) else 0
		cells.append(row)
	var starts: Array[Vector2] = []
	var ends: Array[Vector2] = []
	var outgoing := {}
	for y in cells.size():
		var row: PackedByteArray = cells[y]
		for x in row.size():
			if row[x] == 0:
				continue
			var top_left := Vector2(xs[x], ys[y])
			var bottom_right := Vector2(xs[x + 1], ys[y + 1])
			if y == 0 or cells[y - 1][x] == 0:
				_add_edge(starts, ends, outgoing, top_left, Vector2(bottom_right.x, top_left.y))
			if x == row.size() - 1 or row[x + 1] == 0:
				_add_edge(starts, ends, outgoing, Vector2(bottom_right.x, top_left.y), bottom_right)
			if y == cells.size() - 1 or cells[y + 1][x] == 0:
				_add_edge(starts, ends, outgoing, bottom_right, Vector2(top_left.x, bottom_right.y))
			if x == 0 or row[x - 1] == 0:
				_add_edge(starts, ends, outgoing, Vector2(top_left.x, bottom_right.y), top_left)
	var used := PackedByteArray()
	used.resize(starts.size())
	for i in starts.size():
		if used[i] == 0:
			var loop := _trace(i, starts, ends, outgoing, used)
			if loop.size() >= 3:
				loops.append(loop)
	return loops

static func chamfer(loop: PackedVector2Array, cut: float) -> PackedVector2Array:
	if loop.size() < 3 or cut <= 0.0:
		return loop.duplicate()
	var result := PackedVector2Array()
	for i in loop.size():
		var point := loop[i]
		var to_before := loop[(i - 1 + loop.size()) % loop.size()] - point
		var to_after := loop[(i + 1) % loop.size()] - point
		if to_before.is_zero_approx() or to_after.is_zero_approx():
			continue
		var distance := minf(cut, minf(to_before.length(), to_after.length()) * 0.4)
		result.append(point + to_before.normalized() * distance)
		result.append(point + to_after.normalized() * distance)
	return result
