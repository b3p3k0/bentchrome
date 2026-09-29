@tool
class_name Boulder
extends StaticBody2D
## Permanent mountain cover. Collision stays authored; this script only paints
## an organic skin around the rectangle and stamps its floor collision layer.

const Floors := preload("res://game/floors.gd")
const MountainPaint := preload("res://environment/mountain_wall.gd")
const PitPaint := preload("res://environment/pit_zone.gd")

const OBSTACLE_LAYER := 4
const EDGE_STEP := 40.0
const SMALL_CORNER_CUT_RANGE := Vector2(16.0, 30.0)
const LARGE_CORNER_CUT_RANGE := Vector2(40.0, 52.0)
const EDGE_JITTER := 7.0
const PAINT_BLEED := 6.0
const CAP_INSET := 8.0
# Mirrors MountainWall's top_snow_opacity default; an export default cannot be
# read statically.
const TOP_SNOW_OPACITY := 0.82

@export var size := Vector2(128, 128)
@export var floor_index := 2
@export var paint_seed := 0
@export var snow := true
@export var shadow_offset := Vector2(12, 14)
@export var shadow_alpha := 0.26

func _ready() -> void:
	collision_layer = OBSTACLE_LAYER
	if floor_index >= Floors.MIN_FLOOR:
		collision_layer |= Floors.floor_bit(floor_index)
	collision_mask = 0
	var col := get_node_or_null(^"Col") as CollisionShape2D
	if col == null or not col.shape is RectangleShape2D \
			or not (col.shape as RectangleShape2D).size.is_equal_approx(size):
		push_warning("Boulder needs an authored Col RectangleShape2D matching size")
	queue_redraw()

func outline() -> PackedVector2Array:
	return _make_outline().duplicate()

func snow_outline() -> PackedVector2Array:
	return _make_snow().duplicate()

func snow_inner_edge() -> PackedVector2Array:
	var edge := PackedVector2Array()
	_make_snow(edge)
	return edge.duplicate()

func _draw() -> void:
	var rim := _make_outline()
	draw_set_transform(shadow_offset)
	draw_colored_polygon(rim, Color(0.0, 0.0, 0.0, shadow_alpha))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(rim, PitPaint.CLIFF_FACE)
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 7919
	var ridge := Vector2(rng.randf_range(-size.x / 6.0, size.x / 6.0),
		rng.randf_range(-size.y / 6.0, size.y / 6.0))
	for i in rim.size():
		var edge := rim[(i + 1) % rim.size()] - rim[i]
		var shade := edge.orthogonal().normalized().dot(Vector2(-1, -1).normalized()) * 0.08
		shade += 0.012 if i % 2 == 0 else -0.012
		var color := PitPaint.CLIFF_FACE.lightened(maxf(shade, 0.0)).darkened(maxf(-shade, 0.0))
		draw_colored_polygon(PackedVector2Array([ridge, rim[i], rim[(i + 1) % rim.size()]]), color)
	var snow_edge := PackedVector2Array()
	var cap := _make_snow(snow_edge)
	_draw_grit(rim, cap, rng)
	_draw_cracks(cap, ridge, rng)
	var closed := rim.duplicate()
	closed.append(rim[0])
	draw_polyline(closed, PitPaint.CRACK, MountainPaint.CREST_WIDTH)
	if not cap.is_empty():
		var snow_color := PitPaint.SNOW_CAP
		snow_color.a = TOP_SNOW_OPACITY
		draw_colored_polygon(cap, snow_color)
		draw_polyline(snow_edge, snow_color.darkened(0.22), MountainPaint.STRIATION_WIDTH)
		_draw_snow_flecks(rim, cap, snow_edge, snow_color, rng)

func _make_outline() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed
	var large_corner := rng.randi_range(0, 3)
	var cut := PackedFloat32Array()
	for i in 4:
		var limits := LARGE_CORNER_CUT_RANGE if i == large_corner else SMALL_CORNER_CUT_RANGE
		cut.append(rng.randf_range(limits.x, limits.y))
	var half := size * 0.5
	var corners := PackedVector2Array([-half, Vector2(half.x, -half.y), half,
		Vector2(-half.x, half.y)])
	var directions := PackedVector2Array([Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
		Vector2.UP])
	var points := PackedVector2Array()
	for i in 4:
		var next := (i + 1) % 4
		var start := corners[i] + directions[i] * cut[i]
		var finish := corners[next] - directions[i] * cut[next]
		_add_edge(points, start, finish, -directions[i].orthogonal(), rng)
		_add_corner(points, corners[next],
			corners[next] + directions[next] * cut[next], rng)
	points.remove_at(points.size() - 1)
	return points

func _add_edge(points: PackedVector2Array, start: Vector2, finish: Vector2,
		normal: Vector2, rng: RandomNumberGenerator) -> void:
	if points.is_empty():
		points.append(start)
	var segments := maxi(1, int(ceil(start.distance_to(finish) / EDGE_STEP)))
	for i in range(1, segments):
		var point := start.lerp(finish, float(i) / segments)
		point += normal * rng.randf_range(-EDGE_JITTER, EDGE_JITTER)
		points.append(point.clamp(-size * 0.5 - Vector2.ONE * PAINT_BLEED,
			size * 0.5 + Vector2.ONE * PAINT_BLEED))
	points.append(finish)

func _add_corner(points: PackedVector2Array, corner: Vector2, finish: Vector2,
		rng: RandomNumberGenerator) -> void:
	var start := points[-1]
	for step in [1.0 / 3.0, 2.0 / 3.0]:
		var point: Vector2 = start * (1.0 - step) ** 2 + corner * 2.0 * (1.0 - step) * step \
			+ finish * step ** 2
		point += point.normalized() * rng.randf_range(-EDGE_JITTER, EDGE_JITTER)
		points.append(point)
	points.append(finish)

func _make_snow(inner_edge := PackedVector2Array()) -> PackedVector2Array:
	inner_edge.clear()
	if not snow:
		return PackedVector2Array()
	var rim := _make_outline()
	var inner := rim.duplicate()
	for i in inner.size():
		inner[i] = inner[i].move_toward(Vector2.ZERO, CAP_INSET)
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 15485863
	var half := size * 0.5
	var anchors := PackedVector2Array([
		Vector2(rng.randf_range(0.30, 0.42) * half.x, -half.y),
		Vector2(-half.x, rng.randf_range(0.30, 0.42) * half.y)])
	var nearest := PackedInt32Array([0, 0])
	for anchor in 2:
		for i in inner.size():
			if inner[i].distance_squared_to(anchors[anchor]) \
					< inner[nearest[anchor]].distance_squared_to(anchors[anchor]):
				nearest[anchor] = i
	var cap := PackedVector2Array([inner[nearest[0]]])
	var cursor := (nearest[0] - 1 + inner.size()) % inner.size()
	while cursor != nearest[1]:
		cap.append(inner[cursor])
		cursor = (cursor - 1 + inner.size()) % inner.size()
	cap.append(inner[nearest[1]])
	inner_edge.append(inner[nearest[1]])
	var toward_rock := -(inner[nearest[0]] - inner[nearest[1]]).orthogonal().normalized()
	for step in range(1, 6):
		var amount := rng.randf_range(10.0, 18.0) if step % 2 else \
			-rng.randf_range(2.0, 8.0)
		var point := inner[nearest[1]].lerp(inner[nearest[0]], step / 6.0) \
			+ toward_rock * amount
		while not Geometry2D.is_point_in_polygon(point, rim):
			point = point.move_toward(Vector2.ZERO, 1.0)
		inner_edge.append(point)
	inner_edge.append(inner[nearest[0]])
	cap.append_array(inner_edge.slice(1, -1))
	return cap

func _draw_grit(rim: PackedVector2Array, cap: PackedVector2Array,
		rng: RandomNumberGenerator) -> void:
	for i in roundi(size.x * size.y * (0.5 if snow else 0.85) / 900.0):
		var at := Vector2.INF
		for _attempt in 40:
			at = Vector2(rng.randf_range(-size.x * 0.48, size.x * 0.48),
				rng.randf_range(-size.y * 0.48, size.y * 0.48))
			if Geometry2D.is_point_in_polygon(at, rim) \
					and (cap.is_empty() or not Geometry2D.is_point_in_polygon(at, cap)):
				break
		if not Geometry2D.is_point_in_polygon(at, rim) \
				or (not cap.is_empty() and Geometry2D.is_point_in_polygon(at, cap)):
			continue
		var color := PitPaint.CLIFF_FACE.lightened(0.09) if i % 2 == 0 \
			else PitPaint.CLIFF_FACE.darkened(0.09)
		draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), color)

func _draw_cracks(cap: PackedVector2Array, ridge: Vector2, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(2, 3):
		var target := Vector2(size.x * 0.5, rng.randf_range(-size.y * 0.1, size.y * 0.25))
		if i % 2 == 1:
			target = Vector2(rng.randf_range(-size.x * 0.1, size.x * 0.25), size.y * 0.5)
		var start := ridge.lerp(target, 0.16)
		while not cap.is_empty() and Geometry2D.is_point_in_polygon(start, cap):
			start = start.lerp(target, 0.18)
		var finish := start.lerp(target, 0.76)
		var kink := start.lerp(finish, 0.52)
		kink += (finish - start).orthogonal().normalized() * rng.randf_range(-4.0, 4.0)
		draw_polyline(PackedVector2Array([start, kink, finish]), PitPaint.CRACK,
			MountainPaint.STRIATION_WIDTH)

func _draw_snow_flecks(rim: PackedVector2Array, cap: PackedVector2Array,
		edge: PackedVector2Array, color: Color, rng: RandomNumberGenerator) -> void:
	var toward_rock := -(edge[-1] - edge[0]).orthogonal().normalized()
	for i in rng.randi_range(2, 3):
		var at := edge[1 + i * 2] + toward_rock * rng.randf_range(8.0, 15.0)
		if Geometry2D.is_point_in_polygon(at, rim) \
				and not Geometry2D.is_point_in_polygon(at, cap):
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), color)
