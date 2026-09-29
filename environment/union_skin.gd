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
