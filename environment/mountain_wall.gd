@tool
class_name MountainWall
extends Node2D
## One authored staircase of raw rectangle statics, one generated mountain skin.
## Collision blocks remain the source of truth; only notch-filling chamfers are
## generated, and all relief is paint on a separate canvas.

const RectUnion := preload("res://environment/rect_union.gd")
const UnionSkin := preload("res://environment/union_skin.gd")
const PitPaint := preload("res://environment/pit_zone.gd")
const PinePaint := preload("res://environment/pine_paint.gd")

const GENERATED_NAME := &"_Generated"
const EPSILON := 0.01

static var CREST_WIDTH := 3.0
static var STRIATION_WIDTH := 1.25
static var PINE_GROVE_THRESHOLD := 0.40
static var PINE_RADIUS_MIN := 26.0
static var PINE_RADIUS_MAX := 40.0
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
@export var substrate_material: Material
@export var terrain_material: Material
@export_range(0.0, 1.0, 0.01) var top_snow_opacity := 0.82
@export var chamfer_exclusions: Array[Rect2] = []

var _block_local_rects: Array[Rect2] = []
var _raw_loops: Array[PackedVector2Array] = []
var _solid_loops: Array[PackedVector2Array] = []
var _base_rim_loops: Array[PackedVector2Array] = []
var _paint_loops: Array[PackedVector2Array] = []
var _snow_loops: Array[PackedVector2Array] = []
var _chamfers: Array[PackedVector2Array] = []
var _striations: Array[PackedVector2Array] = []
var _pine_points := PackedVector2Array()
var _pine_seeds: Array[int] = []
var _pine_radii := PackedFloat32Array()

class RockPaint:
	extends Node2D
	func _draw() -> void:
		var wall := get_parent().get_parent() as MountainWall
		if wall != null:
			wall._paint_rock(self)

class DetailPaint:
	extends Node2D
	func _draw() -> void:
		var wall := get_parent().get_parent() as MountainWall
		if wall != null:
			wall._paint_details(self)

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
	return UnionSkin.copy_loops(_paint_loops)

## Local-space snow-cap polygons retained after triangulation validation.
func snow_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_snow_loops)

## Local-space union of boundary-extended blocks and collision chamfers.
func solid_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_solid_loops)

## Local-space clipper offset before organic points are inserted.
func base_rim_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_base_rim_loops)

## Local-space right triangles added to the generated collision body.
func chamfer_triangles() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_chamfers)

## Deterministic local-space positions used by the generated pine paint.
func pine_points() -> PackedVector2Array:
	return _pine_points.duplicate()

func pine_radii() -> PackedFloat32Array:
	return _pine_radii.duplicate()

func face_striations() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_striations)

func _build() -> void:
	var world_rects: Array[Rect2] = block_rects()
	_block_local_rects.clear()
	var extended_blocks: Array[Rect2] = []
	for rect: Rect2 in world_rects:
		var a := to_local(rect.position)
		var b := to_local(rect.end)
		_block_local_rects.append(Rect2(a.min(b), (b - a).abs()))
		var extended := UnionSkin.extend_closed_sides(rect, bounds, bleed)
		a = to_local(extended.position)
		b = to_local(extended.end)
		extended_blocks.append(Rect2(a.min(b), (b - a).abs()))
	_raw_loops = RectUnion.outline(_block_local_rects)
	_build_chamfers()
	_build_skin(extended_blocks)
	_build_striations()
	_build_pines()
	_build_generated()

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
			var organic := UnionSkin.subdivide_displaced(base_rim, rim_step,
				-jitter, jitter, rng, bounds, global_transform, EPSILON)
			_paint_loops.append(organic if UnionSkin.triangulates(organic) else base_rim)
		var caps: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			loop, -face_width, Geometry2D.JOIN_MITER)
		for cap: PackedVector2Array in caps:
			if UnionSkin.triangulates(cap):
				_snow_loops.append(cap)

func _build_chamfers() -> void:
	_chamfers.clear()
	if chamfer_leg <= 0.0:
		return
	for loop: PackedVector2Array in _raw_loops:
		if UnionSkin.signed_area(loop) <= 0.0:
			continue
		for i in loop.size():
			var before: Vector2 = loop[(i - 1 + loop.size()) % loop.size()]
			var point: Vector2 = loop[i]
			var after: Vector2 = loop[(i + 1) % loop.size()]
			if _corner_excluded(point):
				continue
			var incoming: Vector2 = point - before
			var outgoing: Vector2 = after - point
			if incoming.cross(outgoing) >= 0.0:
				continue
			var leg := minf(chamfer_leg, minf(incoming.length(), outgoing.length()))
			var triangle := PackedVector2Array([
				point, point + (before - point).normalized() * leg,
				point + (after - point).normalized() * leg])
			_add_chamfer(triangle)

func _corner_excluded(point: Vector2) -> bool:
	var world := to_global(point)
	for rect: Rect2 in chamfer_exclusions:
		if world.x >= rect.position.x - EPSILON \
				and world.x <= rect.end.x + EPSILON \
				and world.y >= rect.position.y - EPSILON \
				and world.y <= rect.end.y + EPSILON:
			return true
	return false

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
	_pine_radii.clear()
	if pine_spacing <= 0.0 or _snow_loops.is_empty():
		return
	var candidates := UnionSkin.scatter(_snow_loops, pine_spacing, 0.42,
		paint_seed + 104729)
	var kept := PackedVector2Array()
	for point: Vector2 in candidates:
		if UnionSkin.value_noise(point, 420.0, paint_seed + 65537) \
				<= PINE_GROVE_THRESHOLD:
			continue
		var radius := _pine_radius(point)
		if _distance_to_snow_edge(point) + EPSILON >= radius + 8.0:
			kept.append(point)
	kept = UnionSkin.thin_uniform(kept, MAX_PINES, paint_seed + 130363)
	var ordered: Array[Vector2] = []
	for point: Vector2 in kept:
		ordered.append(point)
	ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.y < b.y if not is_equal_approx(a.y, b.y) else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed + 104729
	for point: Vector2 in ordered:
		_pine_points.append(point)
		_pine_radii.append(_pine_radius(point))
		_pine_seeds.append(int(rng.randi()))

func _pine_radius(point: Vector2) -> float:
	return lerpf(PINE_RADIUS_MIN, PINE_RADIUS_MAX,
		UnionSkin.value_noise(point + Vector2(37, 91), 97.0, paint_seed + 31337))

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
	var rock := RockPaint.new()
	rock.name = "RockPaint"
	generated.add_child(rock)
	_build_top_polygons(generated)
	var details := DetailPaint.new()
	details.name = "DetailPaint"
	generated.add_child(details)
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

func _build_top_polygons(parent: Node2D) -> void:
	if terrain_material == null:
		return
	for i in _snow_loops.size():
		var substrate := Polygon2D.new()
		substrate.name = "TopSubstrate" if i == 0 else "TopSubstrate%d" % (i + 1)
		substrate.polygon = _snow_loops[i]
		substrate.material = _material_copy(substrate_material, false)
		parent.add_child(substrate)
		var surface := Polygon2D.new()
		surface.name = "TopSurface" if i == 0 else "TopSurface%d" % (i + 1)
		surface.polygon = _snow_loops[i]
		surface.material = _material_copy(terrain_material, true)
		parent.add_child(surface)

func _material_copy(source: Material, snow_surface: bool) -> Material:
	if source == null:
		return null
	var copy := source.duplicate() as Material
	if copy is ShaderMaterial:
		var shader_mat := copy as ShaderMaterial
		shader_mat.set_shader_parameter("relief_enabled", false)
		if snow_surface:
			var base: Variant = shader_mat.get_shader_parameter("base_color")
			if base is Color:
				var color := base as Color
				color.a = top_snow_opacity
				shader_mat.set_shader_parameter("base_color", color)
	return copy

func _paint_rock(canvas: Node2D) -> void:
	for loop: PackedVector2Array in _paint_loops:
		canvas.draw_colored_polygon(UnionSkin.offset_loop(loop, shadow_offset),
			Color(0.0, 0.0, 0.0, shadow_alpha))
	for loop: PackedVector2Array in _paint_loops:
		canvas.draw_colored_polygon(loop, PitPaint.CLIFF_FACE)
	for i in _striations.size():
		var stripe := _striations[i]
		canvas.draw_line(stripe[0], stripe[1],
			PitPaint.CRACK if i % 4 == 0 else PitPaint.CLIFF_STRIPE,
			STRIATION_WIDTH)
	if terrain_material == null:
		for loop: PackedVector2Array in _snow_loops:
			canvas.draw_colored_polygon(loop, PitPaint.SNOW_CAP)

func _build_striations() -> void:
	_striations.clear()
	var closed := func(a: Vector2, b: Vector2) -> bool:
		return UnionSkin.segment_on_closed_side(a, b, bounds,
			global_transform, EPSILON)
	for loop: PackedVector2Array in _paint_loops:
		_striations.append_array(UnionSkin.fan_striations(loop, _snow_loops,
			maxf(PitPaint.STRIATION_GAP, 3.0), face_width + overhang, closed))

func _paint_details(canvas: Node2D) -> void:
	for loop: PackedVector2Array in _snow_loops:
		_draw_crest(canvas, loop)
	for i in _pine_points.size():
		PinePaint.paint(canvas, _pine_points[i], _pine_radii[i], _pine_seeds[i])

func _draw_crest(canvas: Node2D, loop: PackedVector2Array) -> void:
	var light := Vector2(-1, -1).normalized()
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		if UnionSkin.exterior_normal(b - a).dot(light) > 0.25:
			canvas.draw_line(a, b, PitPaint.SNOW_GLINT, CREST_WIDTH)
