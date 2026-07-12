class_name TerraceChamfer
extends StaticBody2D
## Solid top-side corner cap. Same local right-triangle convention as
## CornerRamp, but blocks BOTH terraces instead of grading between them.

const Floors := preload("res://game/floors.gd")
const EDGE := Color(0.12, 0.12, 0.14)
const LIGHT := Color(0.72, 0.68, 0.48)
const BAND := 42.0

@export var low_floor := 1
@export var high_floor := 2
@export_range(64.0, 1024.0, 16.0) var leg_size := 384.0

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(low_floor) | Floors.floor_bit(high_floor)
	collision_mask = 0
	var col := CollisionPolygon2D.new()
	col.name = "Col"
	col.polygon = footprint()
	add_child(col)
	queue_redraw()

func footprint() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO, Vector2(0.0, -leg_size), Vector2(leg_size, 0.0),
	])

func _draw() -> void:
	var c := 0.0
	var i := 0
	while c < leg_size:
		var c1 := minf(c + BAND, leg_size)
		var poly := PackedVector2Array([
			Vector2(0.0, -c), Vector2(c, 0.0),
			Vector2(c1, 0.0), Vector2(0.0, -c1),
		]) if c > 0.0 else PackedVector2Array([
			Vector2.ZERO, Vector2(c1, 0.0), Vector2(0.0, -c1),
		])
		draw_colored_polygon(poly, LIGHT if i % 2 == 0 else EDGE)
		c = c1
		i += 1
	draw_polyline(PackedVector2Array([
		Vector2.ZERO, Vector2(0.0, -leg_size),
		Vector2(leg_size, 0.0), Vector2.ZERO,
	]), EDGE, 2.5)
