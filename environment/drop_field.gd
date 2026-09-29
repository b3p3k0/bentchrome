class_name DropField
extends Node2D
## One continuous cliff skin around authored PitZone rectangles. PitZone and
## HazardCurb children remain the complete gameplay source of truth.

const RectUnion := preload("res://environment/rect_union.gd")
const UnionSkin := preload("res://environment/union_skin.gd")
const PitPaint := preload("res://environment/pit_zone.gd")
const PinePaint := preload("res://environment/pine_paint.gd")

const RIM := PitPaint.RIM
const SNOW_CAP := PitPaint.SNOW_CAP
const SNOW_GLINT := PitPaint.SNOW_GLINT
const CLIFF_FACE := PitPaint.CLIFF_FACE
const CLIFF_STRIPE := PitPaint.CLIFF_STRIPE
const OCCLUSION := PitPaint.OCCLUSION
const CRACK := PitPaint.CRACK
const GENERATED_NAME := &"_Generated"
const EPSILON := 0.01
const GAP_EROSION := 32.0
const MAX_RIM_INSET := 12.0
const MAX_PINES := 280

@export var bounds := Rect2()
@export var bleed := 96.0
@export var rim_step := 56.0
@export var rim_jitter := 6.0
@export var paint_seed := 0

var _pits: Array[Node2D] = []
var _pit_world_rects: Array[Rect2] = []
var _pit_local_rects: Array[Rect2] = []
var _solid_loops: Array[PackedVector2Array] = []
var _rim_loops: Array[PackedVector2Array] = []
var _face_loops: Array[PackedVector2Array] = []
var _void_base_loops: Array[PackedVector2Array] = []
var _void_loops: Array[PackedVector2Array] = []
var _occlusion_loops: Array[PackedVector2Array] = []
var _gap_loops: Array[PackedVector2Array] = []
var _rim_segments: Array[PackedVector2Array] = []
var _striations: Array[PackedVector2Array] = []
var _cracks: Array[PackedVector2Array] = []
var _pine_points := PackedVector2Array()
var _pine_seeds: Array[int] = []
var _pine_radii: Array[float] = []

class PaintLayer:
	extends Node2D
	func _draw() -> void:
		var field := get_parent().get_parent() as DropField
		if field != null:
			field._paint(self)

func _ready() -> void:
	_build()

## Authored PitZone paint rectangles in world space.
func pit_rects() -> Array[Rect2]:
	return _pit_world_rects.duplicate()

## Local-space organic rim actually painted by the generated layer.
func outline_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_rim_loops)

func solid_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_solid_loops)

func face_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_face_loops)

func void_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_void_loops)

func rim_line_segments() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_rim_segments)

func face_striations() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_striations)

func crack_segments() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_cracks)

func pine_points() -> PackedVector2Array:
	return _pine_points.duplicate()

## Local-space samples where continuous paint has no effective authored kill.
func kill_gaps(step := 16.0) -> PackedVector2Array:
	var gaps := PackedVector2Array()
	if _pit_world_rects.is_empty() or _gap_loops.is_empty():
		return gaps
	step = maxf(step, EPSILON)
	var region := _pit_world_rects[0]
	for rect: Rect2 in _pit_world_rects.slice(1):
		region = region.merge(rect)
	var kill_rects: Array[Rect2] = []
	var inset := Vector2.ONE * (PitPaint.KILL_INSET * 0.5)
	for rect: Rect2 in _pit_world_rects:
		# A closed arena edge is inaccessible; extending it before the inset keeps
		# validation focused on driveable seams between authored pits.
		var effective := UnionSkin.extend_closed_sides(rect, bounds, bleed)
		kill_rects.append(Rect2(effective.position + inset,
			(effective.size - inset * 2.0).max(Vector2.ZERO)))
	var y := ceilf(region.position.y / step) * step
	while y <= region.end.y + EPSILON:
		var x := ceilf(region.position.x / step) * step
		while x <= region.end.x + EPSILON:
			var world := Vector2(x, y)
			var local := to_local(world)
			if RectUnion.contains(_pit_local_rects, local) \
					and _point_in_loops(local, _gap_loops) \
					and _inside_bounds(world) \
					and not _point_in_rects(world, kill_rects):
				gaps.append(local)
			x += step
		y += step
	return gaps

func validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pit: Node2D in _pits:
		if bool(pit.get("paint")):
			warnings.append("PitZone '%s' has paint = true under DropField." % pit.name)
	var gaps := kill_gaps()
	if not gaps.is_empty():
		warnings.append("DropField has %d uncovered kill-gap samples." % gaps.size())
	return warnings

func _build() -> void:
	_gather_pits()
	var extended: Array[Rect2] = []
	for world_rect: Rect2 in _pit_world_rects:
		var rect := UnionSkin.extend_closed_sides(world_rect, bounds, bleed)
		var a := to_local(rect.position)
		var b := to_local(rect.end)
		extended.append(Rect2(a.min(b), (b - a).abs()))
	_solid_loops = RectUnion.outline(extended)
	_build_bands()
	_build_details()
	_build_pines()
	_build_generated()

func _gather_pits() -> void:
	_pits.clear()
	_pit_world_rects.clear()
	_pit_local_rects.clear()
	for child: Node in get_children():
		if not child is Node2D or child.get_script() != PitPaint:
			continue
		var pit := child as Node2D
		var size: Vector2 = pit.get("size")
		var world_rect := Rect2(pit.global_position - size * 0.5, size)
		_pits.append(pit)
		_pit_world_rects.append(world_rect)
		var a := to_local(world_rect.position)
		var b := to_local(world_rect.end)
		_pit_local_rects.append(Rect2(a.min(b), (b - a).abs()))

func _build_bands() -> void:
	_rim_loops.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed
	var inward_jitter := minf(maxf(rim_jitter, 0.0), MAX_RIM_INSET)
	for loop: PackedVector2Array in _solid_loops:
		var organic := UnionSkin.subdivide_displaced(loop, rim_step,
			-inward_jitter, 0.0, rng, bounds, global_transform, EPSILON)
		_rim_loops.append(organic if UnionSkin.triangulates(organic) else loop)
	_face_loops = _offset_valid(_solid_loops, -PitPaint.SNOW_CAP_WIDTH)
	_void_base_loops = _offset_valid(_solid_loops,
		-(PitPaint.SNOW_CAP_WIDTH + PitPaint.CLIFF_FACE_WIDTH))
	_gap_loops = _offset_valid(_solid_loops, -GAP_EROSION)
	var occ_delta := -(PitPaint.SNOW_CAP_WIDTH
		+ maxf(PitPaint.CLIFF_FACE_WIDTH - 7.0, 1.0))
	var occ_base := _offset_valid(_solid_loops, occ_delta)
	_occlusion_loops = _move_loops(occ_base, PitPaint.OCCLUSION_OFFSET * 0.35)
	_void_loops = _move_loops(_void_base_loops, PitPaint.OCCLUSION_OFFSET)

func _offset_valid(source: Array[PackedVector2Array],
		delta: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for loop: PackedVector2Array in source:
		var polygons: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			loop, delta, Geometry2D.JOIN_MITER)
		for polygon: PackedVector2Array in polygons:
			if UnionSkin.triangulates(polygon):
				result.append(polygon)
	return result

func _move_loops(source: Array[PackedVector2Array],
		amount: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for loop: PackedVector2Array in source:
		result.append(UnionSkin.offset_loop(loop, amount))
	return result

func _build_details() -> void:
	_rim_segments.clear()
	_striations.clear()
	_cracks.clear()
	for loop: PackedVector2Array in _rim_loops:
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			if not _closed(a, b):
				_rim_segments.append(PackedVector2Array([a, b]))
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 8191
	for loop: PackedVector2Array in _solid_loops:
		if UnionSkin.signed_area(loop) <= 0.0:
			continue
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			if _closed(a, b):
				continue
			var edge := b - a
			var inward := -UnionSkin.exterior_normal(edge)
			var stripes := maxi(1, int(floor(edge.length()
				/ maxf(PitPaint.STRIATION_GAP, 3.0))))
			for k in stripes:
				var at := a.lerp(b, (float(k) + 0.5) / float(stripes))
				_striations.append(PackedVector2Array([
					at + inward * PitPaint.SNOW_CAP_WIDTH,
					at + inward * (PitPaint.SNOW_CAP_WIDTH
						+ PitPaint.CLIFF_FACE_WIDTH)]))
			var crack_count := maxi(1, int(floor(edge.length() / 190.0)))
			for k in crack_count:
				var along := (float(k) + 0.5) / float(crack_count)
				along += rng.randf_range(-0.18, 0.18) / float(crack_count)
				var start := a.lerp(b, along) + inward * 2.0
				var tangent := edge.normalized()
				var mid := start + inward * rng.randf_range(5.0, 8.0) \
					+ tangent * rng.randf_range(-3.0, 3.0)
				var tip := mid + inward * rng.randf_range(3.0, 6.0) \
					+ tangent * rng.randf_range(-2.0, 2.0)
				_cracks.append(PackedVector2Array([start, mid, tip]))

func _build_pines() -> void:
	_pine_points.clear()
	_pine_seeds.clear()
	_pine_radii.clear()
	var limits := _loop_bounds(_void_loops)
	if not limits.has_area():
		return
	var spacing := maxf(PitPaint.BOTTOM_PINE_SPACING,
		sqrt(limits.size.x * limits.size.y / float(MAX_PINES)))
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 104729
	var y := limits.position.y + spacing * 0.5
	while y < limits.end.y and _pine_points.size() < MAX_PINES:
		var x := limits.position.x + spacing * 0.5
		while x < limits.end.x and _pine_points.size() < MAX_PINES:
			var point := Vector2(x, y) + Vector2(
				rng.randf_range(-spacing * 0.08, spacing * 0.08),
				rng.randf_range(-spacing * 0.08, spacing * 0.08))
			if _point_in_loops(point, _void_loops):
				_pine_points.append(point)
				_pine_seeds.append(int(rng.randi()))
				_pine_radii.append(rng.randf_range(PitPaint.BOTTOM_PINE_MIN_RADIUS,
					PitPaint.BOTTOM_PINE_MAX_RADIUS))
			x += spacing
		y += spacing

func _build_generated() -> void:
	var generated := Node2D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	move_child(generated, 0)
	var paint := PaintLayer.new()
	paint.name = "Paint"
	generated.add_child(paint)

func _paint(canvas: Node2D) -> void:
	for loop: PackedVector2Array in _solid_loops:
		canvas.draw_colored_polygon(loop, SNOW_CAP)
	for segment: PackedVector2Array in _rim_segments:
		if UnionSkin.exterior_normal(segment[1] - segment[0]).dot(
				Vector2(-1, -1).normalized()) > 0.25:
			canvas.draw_line(segment[0], segment[1], SNOW_GLINT, 1.25)
	for loop: PackedVector2Array in _face_loops:
		canvas.draw_colored_polygon(loop, CLIFF_FACE)
	for i in _striations.size():
		var stripe := _striations[i]
		canvas.draw_line(stripe[0], stripe[1],
			CRACK if i % 4 == 0 else CLIFF_STRIPE, 1.0)
	for loop: PackedVector2Array in _occlusion_loops:
		canvas.draw_colored_polygon(loop, OCCLUSION)
	for loop: PackedVector2Array in _void_loops:
		canvas.draw_colored_polygon(loop, PitPaint.BOTTOM_SNOW_COLOR)
	_draw_bottom_specks(canvas)
	for i in _pine_points.size():
		PinePaint.paint(canvas, _pine_points[i], _pine_radii[i], _pine_seeds[i], true)
	for crack: PackedVector2Array in _cracks:
		canvas.draw_polyline(crack, CRACK, 1.5)
	for segment: PackedVector2Array in _rim_segments:
		canvas.draw_line(segment[0], segment[1], RIM, 3.0)

func _draw_bottom_specks(canvas: Node2D) -> void:
	var limits := _loop_bounds(_void_loops)
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 41
	var want := clampi(int(limits.size.x * limits.size.y / 9000.0), 24, 220)
	var made := 0
	for _attempt in want * 5:
		var point := Vector2(rng.randf_range(limits.position.x, limits.end.x),
			rng.randf_range(limits.position.y, limits.end.y))
		if not _point_in_loops(point, _void_loops):
			continue
		var color := PitPaint.BOTTOM_SNOW_COLOR.lightened(0.1) if made % 3 else \
			PitPaint.BOTTOM_SNOW_COLOR.darkened(0.08)
		canvas.draw_circle(point, rng.randf_range(0.45, 0.9), color)
		made += 1
		if made >= want:
			break

func _closed(a: Vector2, b: Vector2) -> bool:
	return UnionSkin.segment_on_closed_side(a, b, bounds,
		global_transform, EPSILON)

func _point_in_loops(point: Vector2,
		loops: Array[PackedVector2Array]) -> bool:
	for loop: PackedVector2Array in loops:
		if Geometry2D.is_point_in_polygon(point, loop):
			return true
	return false

func _point_in_rects(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect: Rect2 in rects:
		if point.x >= rect.position.x - EPSILON \
				and point.x <= rect.end.x + EPSILON \
				and point.y >= rect.position.y - EPSILON \
				and point.y <= rect.end.y + EPSILON:
			return true
	return false

func _inside_bounds(point: Vector2) -> bool:
	return not bounds.has_area() or (point.x >= bounds.position.x - EPSILON \
		and point.x <= bounds.end.x + EPSILON \
		and point.y >= bounds.position.y - EPSILON \
		and point.y <= bounds.end.y + EPSILON)

func _loop_bounds(loops: Array[PackedVector2Array]) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for loop: PackedVector2Array in loops:
		for point: Vector2 in loop:
			lo = lo.min(point)
			hi = hi.max(point)
	return Rect2() if lo.x == INF else Rect2(lo, hi - lo)
