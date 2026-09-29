extends RefCounted
## Shared geometry for one paint skin built around unions of authored rects.
## Callers own the meaning of the bands and pass every transform/tuning input.
static func extend_closed_sides(rect: Rect2, bounds: Rect2, bleed: float) -> Rect2:
	if not bounds.has_area():
		return rect
	var begin := rect.position
	var end := rect.end
	if is_equal_approx(begin.x, bounds.position.x):
		begin.x -= bleed
	if is_equal_approx(end.x, bounds.end.x):
		end.x += bleed
	if is_equal_approx(begin.y, bounds.position.y):
		begin.y -= bleed
	if is_equal_approx(end.y, bounds.end.y):
		end.y += bleed
	return Rect2(begin, end - begin)
static func segment_on_closed_side(a: Vector2, b: Vector2, bounds: Rect2,
		local_to_world: Transform2D, epsilon: float) -> bool:
	if not bounds.has_area():
		return false
	var wa := local_to_world * a
	var wb := local_to_world * b
	return (wa.x < bounds.position.x - epsilon and wb.x < bounds.position.x - epsilon) \
		or (wa.x > bounds.end.x + epsilon and wb.x > bounds.end.x + epsilon) \
		or (wa.y < bounds.position.y - epsilon and wb.y < bounds.position.y - epsilon) \
		or (wa.y > bounds.end.y + epsilon and wb.y > bounds.end.y + epsilon)
static func subdivide_displaced(loop: PackedVector2Array, step: float,
		displacement_min: float, displacement_max: float,
		rng: RandomNumberGenerator, bounds: Rect2,
		local_to_world: Transform2D, epsilon: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	step = maxf(step, epsilon)
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var edge := b - a
		result.append(a)
		if segment_on_closed_side(a, b, bounds, local_to_world, epsilon):
			continue
		var pieces := maxi(1, ceili(edge.length() / step))
		var outward := exterior_normal(edge)
		for j in range(1, pieces):
			var point := a.lerp(b, float(j) / float(pieces))
			result.append(point + outward * rng.randf_range(
				displacement_min, displacement_max))
	return result
static func exterior_normal(edge: Vector2) -> Vector2:
	return Vector2(edge.y, -edge.x).normalized()
static func signed_area(loop: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in loop.size():
		twice_area += loop[i].cross(loop[(i + 1) % loop.size()])
	return twice_area * 0.5
static func offset_loop(loop: PackedVector2Array,
		amount: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in loop:
		result.append(point + amount)
	return result
static func copy_loops(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for loop: PackedVector2Array in source:
		result.append(loop.duplicate())
	return result
static func triangulates(loop: PackedVector2Array) -> bool:
	return loop.size() >= 3 and not Geometry2D.triangulate_polygon(loop).is_empty()
const STRIATION_EDGE_WINDOW := 3

## Joins sampled outer rims to nearby contained inner rims. Consecutive outer
## samples reuse a small edge window; an unexpected jump gets one full search.
static func fan_striations(outer_loop: PackedVector2Array,
		inner_loops: Array[PackedVector2Array], gap: float, band_width: float,
		closed_test: Callable
		) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if outer_loop.size() < 2 or inner_loops.is_empty() or band_width <= 0.0:
		return result
	var contained: Array[PackedVector2Array] = []
	for inner: PackedVector2Array in inner_loops:
		if inner.size() >= 2 \
				and Geometry2D.is_point_in_polygon(inner[0], outer_loop):
			contained.append(inner)
	if contained.is_empty():
		return result
	gap = maxf(gap, 0.001)
	var max_distance_squared := pow(band_width * 1.6, 2.0)
	var previous_edges := PackedInt32Array()
	previous_edges.resize(contained.size())
	previous_edges.fill(-1)
	for i in outer_loop.size():
		var a: Vector2 = outer_loop[i]
		var b: Vector2 = outer_loop[(i + 1) % outer_loop.size()]
		if closed_test.is_valid() and bool(closed_test.call(a, b)):
			continue
		var count := maxi(1, int(floor(a.distance_to(b) / gap)))
		for k in count:
			var start := a.lerp(b, (float(k) + 0.5) / float(count))
			var end := start
			var best := INF
			for loop_index in contained.size():
				var inner := contained[loop_index]
				var nearest := start
				var nearest_edge := -1
				var local_best := INF
				var previous := previous_edges[loop_index]
				if previous >= 0:
					for offset in range(-STRIATION_EDGE_WINDOW,
							STRIATION_EDGE_WINDOW + 1):
						var edge_index: int = posmod(previous + offset, inner.size())
						var candidate := Geometry2D.get_closest_point_to_segment(
							start, inner[edge_index], inner[(edge_index + 1) % inner.size()])
						var distance := start.distance_squared_to(candidate)
						if distance < local_best:
							local_best = distance
							nearest = candidate
							nearest_edge = edge_index
				if previous < 0 or local_best > max_distance_squared:
					local_best = INF
					for edge_index in inner.size():
						var candidate := Geometry2D.get_closest_point_to_segment(
							start, inner[edge_index], inner[(edge_index + 1) % inner.size()])
						var distance := start.distance_squared_to(candidate)
						if distance < local_best:
							local_best = distance
							nearest = candidate
							nearest_edge = edge_index
				previous_edges[loop_index] = nearest_edge
				if local_best < best:
					best = local_best
					end = nearest
			if best <= max_distance_squared and end != start:
				result.append(PackedVector2Array([start, end]))
	return result
## Deterministic bilinear value noise with a smoothstep fade.
static func value_noise(point: Vector2, cell: float, seed: int) -> float:
	cell = maxf(cell, 0.001)
	var scaled := point / cell
	var base := Vector2i(floori(scaled.x), floori(scaled.y))
	var fraction := scaled - Vector2(base)
	var smooth := fraction * fraction * (Vector2(3.0, 3.0) - fraction * 2.0)
	var north := lerpf(_noise_corner(base.x, base.y, seed),
		_noise_corner(base.x + 1, base.y, seed), smooth.x)
	var south := lerpf(_noise_corner(base.x, base.y + 1, seed),
		_noise_corner(base.x + 1, base.y + 1, seed), smooth.x)
	return clampf(lerpf(north, south, smooth.y), 0.0, 1.0)
static func _noise_corner(x: int, y: int, seed: int) -> float:
	var wave := sin(float(x) * 127.1 + float(y) * 311.7
		+ float(seed) * 74.7) * 43758.5453123
	return wave - floor(wave)
## Produces one jittered candidate per spacing cell, retaining only points in
## the even-odd fill represented by loops.
static func scatter(loops: Array[PackedVector2Array], spacing: float,
		jitter_frac: float, seed: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	if loops.is_empty() or spacing <= 0.0:
		return result
	var limits := _loop_bounds(loops)
	if not limits.has_area():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var jitter := maxf(jitter_frac, 0.0) * spacing
	var y := floorf(limits.position.y / spacing) * spacing + spacing * 0.5
	while y < limits.end.y:
		var x := floorf(limits.position.x / spacing) * spacing + spacing * 0.5
		while x < limits.end.x:
			var point := Vector2(x, y) + Vector2(
				rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
			if _inside_loops(point, loops):
				result.append(point)
			x += spacing
		y += spacing
	return result
## Seeded Fisher-Yates sampling gives every candidate the same chance of
## surviving a cap, independent of scan order.
static func thin_uniform(points: PackedVector2Array, cap: int,
		seed: int) -> PackedVector2Array:
	if cap <= 0:
		return PackedVector2Array()
	if points.size() <= cap:
		return points.duplicate()
	var order := PackedInt32Array()
	for i in points.size():
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(order.size() - 1, 0, -1):
		var swap_at := rng.randi_range(0, i)
		var held := order[i]
		order[i] = order[swap_at]
		order[swap_at] = held
	var result := PackedVector2Array()
	for i in cap:
			result.append(points[order[i]])
	return result
static func _inside_loops(point: Vector2,
		loops: Array[PackedVector2Array]) -> bool:
	var inside := false
	for loop: PackedVector2Array in loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			inside = not inside
	return inside
static func _loop_bounds(loops: Array[PackedVector2Array]) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for loop: PackedVector2Array in loops:
		for point: Vector2 in loop:
			lo = lo.min(point)
			hi = hi.max(point)
	return Rect2() if lo.x == INF else Rect2(lo, hi - lo)
