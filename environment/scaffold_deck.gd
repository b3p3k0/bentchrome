class_name ScaffoldDeck
extends Node2D
## One rectangular floor-3 scaffold segment: visible steel deck, floor tag,
## road handling override, optional rails, and the dock-style underpass fade.

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
	var layer := 4 | Floors.floor_bit(floor_index)
	for cfg in [
		[EDGE_TOP, Vector2(0, -size.y * 0.5), Vector2(size.x, RAIL_W)],
		[EDGE_RIGHT, Vector2(size.x * 0.5, 0), Vector2(RAIL_W, size.y)],
		[EDGE_BOTTOM, Vector2(0, size.y * 0.5), Vector2(size.x, RAIL_W)],
		[EDGE_LEFT, Vector2(-size.x * 0.5, 0), Vector2(RAIL_W, size.y)],
	]:
		if (rail_edges & int(cfg[0])) == 0:
			continue
		var rail := StaticBody2D.new()
		rail.name = "Rail%d" % int(cfg[0])
		rail.collision_layer = layer
		rail.collision_mask = 0
		rail.position = cfg[1]
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = cfg[2]
		col.shape = shape
		rail.add_child(col)
		add_child(rail)

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
	for cfg in [
		[EDGE_TOP, Vector2(-half.x, -half.y), Vector2(half.x, -half.y)],
		[EDGE_RIGHT, Vector2(half.x, -half.y), Vector2(half.x, half.y)],
		[EDGE_BOTTOM, Vector2(-half.x, half.y), Vector2(half.x, half.y)],
		[EDGE_LEFT, Vector2(-half.x, -half.y), Vector2(-half.x, half.y)],
	]:
		if (rail_edges & int(cfg[0])) != 0:
			draw_line(cfg[1], cfg[2], edge_color, RAIL_W)
