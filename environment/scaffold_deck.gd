class_name ScaffoldDeck
extends Node2D
## One rectangular floor-3 scaffold segment: visible steel deck, floor tag,
## road handling override, classified edges, and the dock-style underpass fade.
## Every edge is exactly one of: RAIL (full guard static), GATE (an opening of
## gate_width covered by a neighboring deck or ramp mouth; the two shoulders
## get Gate* statics), DROP (authored bail-out lip - no static, danger paint),
## or seam (unlisted - fully covered by a neighbor, nothing built or drawn).
## gate_offset shifts every gate opening off its edge center; it is shared by
## all gate edges on the deck, so only single-gate decks should use it.

const Floors := preload("res://game/floors.gd")
const FloorZoneScript := preload("res://environment/floor_zone.gd")
const TerrainZoneScript := preload("res://environment/terrain_zone.gd")

const EDGE_TOP := 1
const EDGE_RIGHT := 2
const EDGE_BOTTOM := 4
const EDGE_LEFT := 8
const RAIL_W := 10.0
const UNDER_FADE := 0.42
const FADE_SPEED := 6.0

@export var size := Vector2(448, 448)
@export var floor_index := 3
@export_flags("Top", "Right", "Bottom", "Left") var rail_edges := 0
@export_flags("Top", "Right", "Bottom", "Left") var gate_edges := 0
@export var gate_width := 256.0
@export var gate_offset := 0.0
@export_flags("Top", "Right", "Bottom", "Left") var drop_edges := 0
@export var terrain_type: StringName = &"road"
@export var deck_color := Color(0.40, 0.42, 0.46)
@export var edge_color := Color(0.92, 0.72, 0.18)

var _under_area: Area2D

func _ready() -> void:
	z_index = 1
	_add_floor()
	_add_terrain()
	_add_rails()
	_add_underpass()
	queue_redraw()

func _add_floor() -> void:
	var zone := FloorZoneScript.new() as FloorZone
	zone.name = "Floor"
	zone.floor_index = floor_index
	zone.size = size
	add_child(zone)

func _add_terrain() -> void:
	var zone := TerrainZoneScript.new() as TerrainZone
	zone.name = "Terrain"
	zone.terrain_type = terrain_type
	zone.terrain_priority = Ramp.TERRAIN_PRIORITY
	zone.collision_layer = 128
	zone.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	zone.add_child(col)
	add_child(zone)

func _add_rails() -> void:
	for edge: int in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
		var extent := _edge_extent(edge)
		if (rail_edges & edge) != 0:
			_add_edge_static("Rail%d" % edge, edge, -extent, extent)
		elif (gate_edges & edge) != 0:
			var lo := gate_offset - gate_width * 0.5
			var hi := gate_offset + gate_width * 0.5
			if -extent < lo:
				_add_edge_static("Gate%d_a" % edge, edge, -extent, lo)
			if hi < extent:
				_add_edge_static("Gate%d_b" % edge, edge, hi, extent)

## Half-length of an edge along its own axis (x for Top/Bottom, y for Left/Right).
func _edge_extent(edge: int) -> float:
	return size.x * 0.5 if edge in [EDGE_TOP, EDGE_BOTTOM] else size.y * 0.5

## One guard static covering [from_a, to_a] along the edge axis.
func _add_edge_static(body_name: String, edge: int, from_a: float, to_a: float) -> void:
	var half := size * 0.5
	var mid := (from_a + to_a) * 0.5
	var span := to_a - from_a
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 4 | Floors.floor_bit(floor_index)
	body.collision_mask = 0
	var body_size: Vector2
	match edge:
		EDGE_TOP:
			body.position = Vector2(mid, -half.y)
			body_size = Vector2(span, RAIL_W)
		EDGE_BOTTOM:
			body.position = Vector2(mid, half.y)
			body_size = Vector2(span, RAIL_W)
		EDGE_LEFT:
			body.position = Vector2(-half.x, mid)
			body_size = Vector2(RAIL_W, span)
		_:
			body.position = Vector2(half.x, mid)
			body_size = Vector2(RAIL_W, span)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_underpass() -> void:
	_under_area = Area2D.new()
	_under_area.name = "Underpass"
	_under_area.collision_layer = 0
	_under_area.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	_under_area.add_child(col)
	add_child(_under_area)

func _process(delta: float) -> void:
	if _under_area == null:
		return
	var target := 1.0
	for body in _under_area.get_overlapping_bodies():
		if body is CanvasItem and (body as CanvasItem).z_index < z_index:
			target = UNDER_FADE
			break
	modulate.a = move_toward(modulate.a, target, FADE_SPEED * delta)

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(10, 14), size), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(-half, size), deck_color)
	var seams := maxi(int(size.x / 64.0), 2)
	for i in range(1, seams):
		var x := -half.x + size.x * float(i) / float(seams)
		draw_line(Vector2(x, -half.y + 3), Vector2(x, half.y - 3), deck_color.darkened(0.18), 1.5)
	draw_rect(Rect2(-half, size), deck_color.darkened(0.28), false, 2.0)
	for edge: int in [EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM, EDGE_LEFT]:
		var extent := _edge_extent(edge)
		if (rail_edges & edge) != 0:
			_draw_edge_span(edge, -extent, extent, edge_color, RAIL_W)
		elif (gate_edges & edge) != 0:
			var lo := gate_offset - gate_width * 0.5
			var hi := gate_offset + gate_width * 0.5
			if -extent < lo:
				_draw_edge_span(edge, -extent, lo, edge_color, RAIL_W)
			if hi < extent:
				_draw_edge_span(edge, hi, extent, edge_color, RAIL_W)
		elif (drop_edges & edge) != 0:
			_draw_edge_span(edge, -extent, extent, Color(0.12, 0.11, 0.10), 6.0)

## A stripe over [from_a, to_a] along the given edge, in local space.
func _draw_edge_span(edge: int, from_a: float, to_a: float, color: Color, width: float) -> void:
	var half := size * 0.5
	match edge:
		EDGE_TOP:
			draw_line(Vector2(from_a, -half.y), Vector2(to_a, -half.y), color, width)
		EDGE_BOTTOM:
			draw_line(Vector2(from_a, half.y), Vector2(to_a, half.y), color, width)
		EDGE_LEFT:
			draw_line(Vector2(-half.x, from_a), Vector2(-half.x, to_a), color, width)
		_:
			draw_line(Vector2(half.x, from_a), Vector2(half.x, to_a), color, width)
