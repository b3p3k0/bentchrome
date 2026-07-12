class_name FoundationDeck
extends Node2D
## Poured floor-2 slab. Collision walls/approach openings remain explicit level
## content; this node owns the unified paint, floor tag, and road surface.

@export var size := Vector2(2048, 1792)
@export var floor_index := 2

func _ready() -> void:
	var floor := FloorZone.new()
	floor.name = "Floor"
	floor.floor_index = floor_index
	floor.size = size
	add_child(floor)
	var terrain := TerrainZone.new()
	terrain.name = "Terrain"
	terrain.terrain_type = &"road"
	terrain.terrain_priority = 50
	terrain.collision_layer = 128
	terrain.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	terrain.add_child(col)
	add_child(terrain)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(16, 22), size), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(-half, size), Color(0.47, 0.49, 0.52))
	for x in range(int(-half.x + 128), int(half.x), 256):
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(0.37, 0.39, 0.42), 2.0)
	for y in range(int(-half.y + 128), int(half.y), 256):
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(0.37, 0.39, 0.42), 2.0)
	draw_rect(Rect2(-half, size), Color(0.25, 0.27, 0.30), false, 5.0)
