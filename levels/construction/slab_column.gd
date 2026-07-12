class_name SlabColumn
extends StaticBody2D
## Poured first-floor column rising off the foundation slab: permanent floor-2
## cover (no Health — structure, not another destructible). One node owns both
## the paint and an unscaled Col so they can never disagree (the stadium
## chamfer pattern). Sits on the 512px anchor grid the slab joints paint.

const Floors := preload("res://game/floors.gd")

@export var size := Vector2(112, 112)
@export var floor_index := 2

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	draw_rect(Rect2(-half + Vector2(10, 14), size), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(-half, size), Color(0.52, 0.53, 0.55))
	draw_colored_polygon(PackedVector2Array([
		-half, Vector2(half.x, -half.y), Vector2(-half.x, half.y),
	]), Color(1, 1, 1, 0.10))
	draw_rect(Rect2(Vector2(-half.x, half.y - 8.0), Vector2(size.x, 8.0)), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(Vector2(half.x - 8.0, -half.y), Vector2(8.0, size.y)), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(-half + Vector2(6, 6), size - Vector2(12, 12)), Color(0.56, 0.57, 0.60))
	draw_rect(Rect2(-half + Vector2(6, 6), size - Vector2(12, 12)),
		Color(0.38, 0.40, 0.43), false, 2.0)
	for p: Vector2 in [Vector2(-22, -22), Vector2(22, -22), Vector2(-22, 22), Vector2(22, 22)]:
		draw_circle(p, 5.0, Color(0.30, 0.20, 0.13))
		draw_circle(p, 2.5, Color(0.42, 0.28, 0.16))
	for i in 3:
		var x := rng.randf_range(-half.x + 10.0, half.x - 10.0)
		draw_line(Vector2(x, half.y - 6.0),
			Vector2(x + rng.randf_range(-3.0, 3.0), half.y + rng.randf_range(6.0, 14.0)),
			Color(0.30, 0.31, 0.33, 0.5), 3.0)
	draw_rect(Rect2(-half, size), Color(0.30, 0.32, 0.35), false, 2.5)
