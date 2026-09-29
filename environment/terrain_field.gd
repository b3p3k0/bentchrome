class_name TerrainField
extends Node2D
## One continuous paint skin over authored TerrainZone rectangle tiles. The
## tiles remain the complete grip and radar source of truth.

const RectUnion := preload("res://environment/rect_union.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")
const UnionSkin := preload("res://environment/union_skin.gd")

const GENERATED_NAME := &"_Generated"
const EPSILON := 0.01

@export var terrain_material: Material
@export var fill_color := Color(0.82, 0.85, 0.92, 0.55)
@export var corner_radius := TerrainZoneScript.CORNER_RADIUS
@export var edge_step := TerrainZoneScript.EDGE_STEP
@export var edge_jitter := TerrainZoneScript.EDGE_JITTER
@export var bounds := Rect2()
@export var bleed := 96.0
@export var paint_seed := 0

var _tiles: Array[TerrainZone] = []
var _tile_world_rects: Array[Rect2] = []
var _outline_loops: Array[PackedVector2Array] = []
var _warnings := PackedStringArray()

func _ready() -> void:
	_build()

## Authored TerrainZone collision rectangles in world space.
func tile_rects() -> Array[Rect2]:
	return _tile_world_rects.duplicate()

## Local-space union silhouettes actually painted below `_Generated`.
func outline_loops() -> Array[PackedVector2Array]:
	return UnionSkin.copy_loops(_outline_loops)

func validation_warnings() -> PackedStringArray:
	return _warnings.duplicate()

func _build() -> void:
	_gather_tiles()
	var extended: Array[Rect2] = []
	for world_rect: Rect2 in _tile_world_rects:
		var rect := UnionSkin.extend_closed_sides(world_rect, bounds, bleed)
		var a := to_local(rect.position)
		var b := to_local(rect.end)
		extended.append(Rect2(a.min(b), (b - a).abs()))
	var union_loops := RectUnion.outline(extended)
	_build_warnings(union_loops)
	_soften_outer_loops(union_loops)
	_build_generated()

func _gather_tiles() -> void:
	_tiles.clear()
	_tile_world_rects.clear()
	for child: Node in get_children():
		if not child is TerrainZone:
			continue
		var tile := child as TerrainZone
		var col := tile.get_node_or_null(^"Col") as CollisionShape2D
		if col == null or not col.shape is RectangleShape2D:
			continue
		var shape := col.shape as RectangleShape2D
		_tiles.append(tile)
		_tile_world_rects.append(Rect2(col.global_position - shape.size * 0.5,
			shape.size))

func _build_warnings(union_loops: Array[PackedVector2Array]) -> void:
	_warnings.clear()
	var hole_count := 0
	for loop: PackedVector2Array in union_loops:
		if UnionSkin.signed_area(loop) < 0.0:
			hole_count += 1
	if hole_count > 0:
		_warnings.append("TerrainField union contains %d hole loop(s); holes are painted solid."
			% hole_count)
	for tile: TerrainZone in _tiles:
		if tile.get_node_or_null(^"Vis") != null:
			_warnings.append("TerrainZone '%s' has a Vis child under TerrainField."
				% tile.name)
	if not _tiles.is_empty():
		var expected := _tiles[0].terrain_type
		for tile: TerrainZone in _tiles.slice(1):
			if tile.terrain_type != expected:
				_warnings.append("TerrainField tiles use mixed terrain_type values.")
				break
	for i in _tile_world_rects.size():
		for j in range(i + 1, _tile_world_rects.size()):
			if _tile_world_rects[i].intersection(_tile_world_rects[j]).has_area():
				_warnings.append("TerrainZone '%s' overlaps TerrainZone '%s' in its interior."
					% [_tiles[i].name, _tiles[j].name])

func _soften_outer_loops(union_loops: Array[PackedVector2Array]) -> void:
	_outline_loops.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = paint_seed
	for loop: PackedVector2Array in union_loops:
		if UnionSkin.signed_area(loop) <= 0.0:
			continue
		var softened := UnionSkin.soften_rectilinear(loop, corner_radius,
			edge_step, edge_jitter, rng, bounds, global_transform, EPSILON)
		if UnionSkin.triangulates(softened):
			_outline_loops.append(softened)
		else:
			_outline_loops.append(loop.duplicate())

func _build_generated() -> void:
	var old := get_node_or_null(NodePath(String(GENERATED_NAME)))
	if old != null:
		remove_child(old)
		old.free()
	var generated := Node2D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	move_child(generated, 0)
	for i in _outline_loops.size():
		var polygon := Polygon2D.new()
		polygon.name = "Surface" if i == 0 else "Surface%d" % (i + 1)
		polygon.polygon = _outline_loops[i]
		if terrain_material != null:
			polygon.material = terrain_material
		else:
			polygon.color = fill_color
		generated.add_child(polygon)
