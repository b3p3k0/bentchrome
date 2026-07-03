extends Node2D
## World-space preview of the open level. Draws the wall band exactly where
## LevelLoader will build it, plus the bounds outline. Entity ghosts land in
## the placement card.

const Schema := preload("res://levels/level_schema.gd")
const Catalog := preload("res://levels/entity_catalog.gd")

var document: EditorDocument

func bind(doc: EditorDocument) -> void:
	document = doc
	document.changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if document == null:
		return
	var half := document.bounds_half()
	var t := Schema.WALL_THICKNESS
	draw_rect(Rect2(-half, Vector2(half.x * 2, t)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(-half.x, half.y - t), Vector2(half.x * 2, t)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(t, half.y * 2)), Catalog.WALL_COLOR)
	draw_rect(Rect2(Vector2(half.x - t, -half.y), Vector2(t, half.y * 2)), Catalog.WALL_COLOR)
	draw_rect(Rect2(-half, half * 2), Color(1, 1, 1, 0.25), false, 2.0)
