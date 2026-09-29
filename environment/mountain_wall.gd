@tool
class_name MountainWall
extends Node2D
## One authored staircase of raw rectangle statics, one generated mountain skin.
## Collision blocks remain the source of truth; only notch-filling chamfers are
## generated, and all relief is paint on a separate canvas.

const RectUnion := preload("res://environment/rect_union.gd")
const PitPaint := preload("res://environment/pit_zone.gd")
const PinePaint := preload("res://environment/pine_paint.gd")

const GENERATED_NAME := &"_Generated"
const EPSILON := 0.01

static var CREST_WIDTH := 3.0
static var STRIATION_WIDTH := 1.25
static var PINE_RADIUS := 36.0
static var PINE_INSET := 14.0
static var MAX_PINES := 220

@export var bounds := Rect2()
@export var bleed := 96.0
@export var overhang := 12.0
@export var jitter := 6.0
@export var face_width := 52.0
@export var chamfer_leg := 128.0
@export var shadow_offset := Vector2(30, 36)
@export var shadow_alpha := 0.26
@export var pine_spacing := 150.0
@export var rim_step := 56.0
@export var paint_seed := 0

var _block_local_rects: Array[Rect2] = []
var _raw_loops: Array[PackedVector2Array] = []
var _solid_loops: Array[PackedVector2Array] = []
var _base_rim_loops: Array[PackedVector2Array] = []
var _paint_loops: Array[PackedVector2Array] = []
var _snow_loops: Array[PackedVector2Array] = []
var _chamfers: Array[PackedVector2Array] = []
var _pine_points := PackedVector2Array()
var _pine_seeds: Array[int] = []

class PaintLayer:
	extends Node2D
	func _draw() -> void:
		var wall := get_parent().get_parent() as MountainWall
		if wall != null:
			wall._paint(self)

func _ready() -> void:
	if bleed <= face_width:
		push_warning("MountainWall bleed should exceed face_width so closed sides stay snow-covered")
	_build()

## Authored collision rectangles in world space. Generated chamfers are never
## included, so tools can audit the original scene contract after `_ready`.
func block_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for child: Node in get_children():
		if not child is StaticBody2D:
			continue
		var col := child.get_node_or_null(^"Col") as CollisionShape2D
		if col == null or not col.shape is RectangleShape2D:
			continue
		var shape := col.shape as RectangleShape2D
		result.append(Rect2(col.global_position - shape.size * 0.5, shape.size))
	return result

## Local-space silhouette used by the generated paint.
func outline_loops() -> Array[PackedVector2Array]:
	return _copy_loops(_paint_loops)

## Local-space snow-cap polygons retained after triangulation validation.
func snow_loops() -> Array[PackedVector2Array]:
	return _copy_loops(_snow_loops)

## Local-space union of boundary-extended blocks and collision chamfers.
func solid_loops() -> Array[PackedVector2Array]:
	return _copy_loops(_solid_loops)

## Local-space clipper offset before organic points are inserted.
func base_rim_loops() -> Array[PackedVector2Array]:
	return _copy_loops(_base_rim_loops)

## Local-space right triangles added to the generated collision body.
func chamfer_triangles() -> Array[PackedVector2Array]:
	return _copy_loops(_chamfers)

## Deterministic local-space positions used by the generated pine paint.
func pine_points() -> PackedVector2Array:
	return _pine_points.duplicate()

func _copy_loops(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for loop: PackedVector2Array in source:
		result.append(loop.duplicate())
	return result

func _build() -> void:
	var world_rects: Array[Rect2] = block_rects()
	_block_local_rects.clear()
	var extended_blocks: Array[Rect2] = []
	for rect: Rect2 in world_rects:
		var a := to_local(rect.position)
		var b := to_local(rect.end)
		_block_local_rects.append(Rect2(a.min(b), (b - a).abs()))
		var extended := _extend_closed_sides(rect)
		a = to_local(extended.position)
		b = to_local(extended.end)
		extended_blocks.append(Rect2(a.min(b), (b - a).abs()))
	_raw_loops = RectUnion.outline(_block_local_rects)
	_build_chamfers()
	_build_skin(extended_blocks)
	_build_pines()
	_build_generated()

func _extend_closed_sides(rect: Rect2) -> Rect2:
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

func _build_skin(extended_blocks: Array[Rect2]) -> void:
	_solid_loops = RectUnion.outline(extended_blocks)
	for triangle: PackedVector2Array in _chamfers:
		for i in range(_solid_loops.size() - 1, -1, -1):
			var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(
				_solid_loops[i], triangle)
			if merged.size() == 1:
				_solid_loops[i] = merged[0]
				break
	_base_rim_loops.clear()
	_paint_loops.clear()
	_snow_loops.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed
	for loop: PackedVector2Array in _solid_loops:
		var rims: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			loop, overhang, Geometry2D.JOIN_MITER)
		for base_rim: PackedVector2Array in rims:
			_base_rim_loops.append(base_rim)
			var organic := _organic_rim(base_rim, rng)
			_paint_loops.append(organic if _triangulates(organic) else base_rim)
		var caps: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			loop, -face_width, Geometry2D.JOIN_MITER)
		for cap: PackedVector2Array in caps:
			if _triangulates(cap):
				_snow_loops.append(cap)

func _organic_rim(loop: PackedVector2Array,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var result := PackedVector2Array()
	var step := maxf(rim_step, EPSILON)
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var edge := b - a
		result.append(a)
		if _segment_outside_bounds(a, b):
			continue
		var pieces := maxi(1, ceili(edge.length() / step))
		var outward := _exterior_normal(edge)
		for j in range(1, pieces):
			var point := a.lerp(b, float(j) / float(pieces))
			result.append(point + outward * rng.randf_range(-jitter, jitter))
	return result

func _triangulates(loop: PackedVector2Array) -> bool:
	return loop.size() >= 3 and not Geometry2D.triangulate_polygon(loop).is_empty()

func _build_chamfers() -> void:
	_chamfers.clear()
	if chamfer_leg <= 0.0:
		return
	for loop: PackedVector2Array in _raw_loops:
		if _signed_area(loop) <= 0.0:
			continue
		for i in loop.size():
			var before: Vector2 = loop[(i - 1 + loop.size()) % loop.size()]
			var point: Vector2 = loop[i]
			var after: Vector2 = loop[(i + 1) % loop.size()]
			var incoming: Vector2 = point - before
			var outgoing: Vector2 = after - point
			if incoming.cross(outgoing) >= 0.0:
				continue
			var leg := minf(chamfer_leg, minf(incoming.length(), outgoing.length()))
			var triangle := PackedVector2Array([
				point, point + (before - point).normalized() * leg,
				point + (after - point).normalized() * leg])
			_add_chamfer(triangle)

func _add_chamfer(triangle: PackedVector2Array) -> void:
	if triangle.size() != 3 or _triangle_touches_closed_side(triangle):
		return
	_chamfers.append(triangle)

func _triangle_touches_closed_side(triangle: PackedVector2Array) -> bool:
	if not bounds.has_area():
		return false
	for point: Vector2 in triangle:
		var world: Vector2 = to_global(point)
		if is_equal_approx(world.x, bounds.position.x) \
				or is_equal_approx(world.x, bounds.end.x) \
				or is_equal_approx(world.y, bounds.position.y) \
				or is_equal_approx(world.y, bounds.end.y):
			return true
	return false

func _build_pines() -> void:
	_pine_points.clear()
	_pine_seeds.clear()
	if pine_spacing <= 0.0 or _snow_loops.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 104729
	for loop: PackedVector2Array in _solid_loops:
		if _signed_area(loop) <= 0.0:
			continue
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			if _segment_outside_bounds(a, b):
				continue
			var edge := b - a
			var count := int(floor(edge.length() / pine_spacing))
			var inward := -_exterior_normal(edge)
			for k in count:
				var along := (float(k) + 0.5) / float(count)
				along += rng.randf_range(-0.12, 0.12) / float(count)
				var point := a.lerp(b, along)
				point += inward * (face_width + PINE_INSET + 1.0)
				_try_pine(point, rng)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for loop: PackedVector2Array in _snow_loops:
		for point: Vector2 in loop:
			lo = lo.min(point)
			hi = hi.max(point)
	var columns := maxi(1, int(ceil((hi.x - lo.x) / pine_spacing)))
	var rows := maxi(1, int(ceil((hi.y - lo.y) / pine_spacing)))
	var grid_jitter := pine_spacing * 0.04
	for y in rows:
		for x in columns:
			var point := lo + Vector2(x + 0.5, y + 0.5) * pine_spacing
			point += Vector2(rng.randf_range(-grid_jitter, grid_jitter),
				rng.randf_range(-grid_jitter, grid_jitter))
			_try_pine(point, rng)
			if _pine_points.size() >= MAX_PINES:
				return

func _try_pine(point: Vector2, rng: RandomNumberGenerator) -> void:
	if _pine_points.size() >= MAX_PINES or not _point_in_snow(point):
		return
	if _distance_to_snow_edge(point) + EPSILON < PINE_INSET:
		return
	_pine_points.append(point)
	_pine_seeds.append(int(rng.randi()))

func _point_in_snow(point: Vector2) -> bool:
	for loop: PackedVector2Array in _snow_loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			return true
	return false

func _distance_to_snow_edge(point: Vector2) -> float:
	var closest := INF
	for loop: PackedVector2Array in _snow_loops:
		for i in loop.size():
			var on_edge := Geometry2D.get_closest_point_to_segment(
				point, loop[i], loop[(i + 1) % loop.size()])
			closest = minf(closest, point.distance_to(on_edge))
	return closest

func _build_generated() -> void:
	var old := get_node_or_null(NodePath(String(GENERATED_NAME)))
	if old != null:
		remove_child(old)
		old.free()
	var generated := Node2D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	move_child(generated, 0)
	var paint := PaintLayer.new()
	paint.name = "Paint"
	generated.add_child(paint)
	if _chamfers.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "Chamfers"
	body.collision_layer = _first_block_layer()
	body.collision_mask = 0
	generated.add_child(body)
	for i in _chamfers.size():
		var col := CollisionPolygon2D.new()
		col.name = "Chamfer%d" % (i + 1)
		col.polygon = _chamfers[i]
		body.add_child(col)

func _first_block_layer() -> int:
	for child: Node in get_children():
		if child is StaticBody2D:
			return child.collision_layer
	return 0

func _paint(canvas: Node2D) -> void:
	for loop: PackedVector2Array in _paint_loops:
		canvas.draw_colored_polygon(_offset(loop, shadow_offset),
			Color(0.0, 0.0, 0.0, shadow_alpha))
	for loop: PackedVector2Array in _paint_loops:
		canvas.draw_colored_polygon(loop, PitPaint.CLIFF_FACE)
	_draw_striations(canvas)
	for loop: PackedVector2Array in _snow_loops:
		canvas.draw_colored_polygon(loop, PitPaint.SNOW_CAP)
		_draw_crest(canvas, loop)
	for i in _pine_points.size():
		PinePaint.paint(canvas, _pine_points[i], PINE_RADIUS, _pine_seeds[i])

func _draw_striations(canvas: Node2D) -> void:
	var gap: float = maxf(PitPaint.STRIATION_GAP, 3.0)
	for loop: PackedVector2Array in _solid_loops:
		if _signed_area(loop) <= 0.0:
			continue
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			if _segment_outside_bounds(a, b):
				continue
			var edge := b - a
			var outward := _exterior_normal(edge)
			var count := maxi(1, int(floor(edge.length() / gap)))
			for k in count:
				var at := a.lerp(b, (float(k) + 0.5) / float(count))
				var color: Color = PitPaint.CRACK if k % 4 == 0 else PitPaint.CLIFF_STRIPE
				canvas.draw_line(at + outward * maxf(overhang - jitter, 0.0),
					at - outward * face_width, color, STRIATION_WIDTH)

func _draw_crest(canvas: Node2D, loop: PackedVector2Array) -> void:
	var light := Vector2(-1, -1).normalized()
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		if _exterior_normal(b - a).dot(light) > 0.25:
			canvas.draw_line(a, b, PitPaint.SNOW_GLINT, CREST_WIDTH)

func _segment_outside_bounds(a: Vector2, b: Vector2) -> bool:
	if not bounds.has_area():
		return false
	var wa: Vector2 = to_global(a)
	var wb: Vector2 = to_global(b)
	return (wa.x < bounds.position.x - EPSILON and wb.x < bounds.position.x - EPSILON) \
		or (wa.x > bounds.end.x + EPSILON and wb.x > bounds.end.x + EPSILON) \
		or (wa.y < bounds.position.y - EPSILON and wb.y < bounds.position.y - EPSILON) \
		or (wa.y > bounds.end.y + EPSILON and wb.y > bounds.end.y + EPSILON)

func _exterior_normal(edge: Vector2) -> Vector2:
	return Vector2(edge.y, -edge.x).normalized()

func _signed_area(loop: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in loop.size():
		twice_area += loop[i].cross(loop[(i + 1) % loop.size()])
	return twice_area * 0.5

func _offset(loop: PackedVector2Array, amount: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in loop:
		result.append(point + amount)
	return result
