class_name GridFloor
extends Node2D
## Procedural grid-line floor, extracted from the arena so custom levels and
## the level editor draw the same ground. Covers ±extent around the origin.

@export var grid := 128
@export var extent := Vector2(2400, 2400)
@export var line_color := Color(1, 1, 1, 0.08)

func _draw() -> void:
	for x in range(-int(extent.x), int(extent.x) + 1, grid):
		draw_line(Vector2(x, -extent.y), Vector2(x, extent.y), line_color, 1.0)
	for y in range(-int(extent.y), int(extent.y) + 1, grid):
		draw_line(Vector2(-extent.x, y), Vector2(extent.x, y), line_color, 1.0)

func set_extent(value: Vector2) -> void:
	extent = value
	queue_redraw()
