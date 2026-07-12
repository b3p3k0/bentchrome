class_name ConstructionMachine
extends StaticBody2D
## Permanent floor-stamped site cover. The silhouette is procedural and the
## collision owner never scales; parked machinery is topology, not loot.

const Floors := preload("res://game/floors.gd")

@export_enum("bulldozer", "dump_truck", "cement_truck") var kind := "bulldozer"
@export var size := Vector2(256, 128)
@export var floor_index := 1
@export var beacon_enabled := true

var _phase := 0.0

func _ready() -> void:
	collision_layer = 4 | Floors.floor_bit(floor_index)
	collision_mask = 0
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	_phase = fposmod(absf(position.x * 0.01 + position.y * 0.017), TAU)
	queue_redraw()

func _process(delta: float) -> void:
	if not beacon_enabled:
		return
	_phase = fposmod(_phase + delta * 2.2, TAU)
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half + Vector2(11, 14), size), Color(0, 0, 0, 0.32))
	match kind:
		"dump_truck":
			_draw_dump(half)
		"cement_truck":
			_draw_cement(half)
		_:
			_draw_dozer(half)
	if beacon_enabled:
		var glow := 0.35 + 0.35 * (0.5 + 0.5 * sin(_phase))
		draw_circle(Vector2(half.x * 0.32, -half.y * 0.28), 9.0, Color(1.0, 0.55, 0.05, glow * 0.24))
		draw_circle(Vector2(half.x * 0.32, -half.y * 0.28), 3.5, Color(1.0, 0.7, 0.12, glow))

func _wheels(half: Vector2, count: int) -> void:
	for i in count:
		var x := lerpf(-half.x * 0.62, half.x * 0.62, float(i) / maxf(float(count - 1), 1.0))
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(x - 13, side * half.y - 9), Vector2(26, 18)), Color(0.07, 0.07, 0.08))

func _draw_dozer(half: Vector2) -> void:
	draw_rect(Rect2(-half * Vector2(0.72, 0.72), size * Vector2(0.72, 0.72)), Color(0.86, 0.58, 0.08))
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(-half.x * 0.65, side * half.y * 0.58 - 14),
			Vector2(size.x * 0.68, 28)), Color(0.12, 0.12, 0.13))
	draw_rect(Rect2(Vector2(half.x * 0.18, -half.y * 0.42), Vector2(half.x * 0.45, half.y * 0.84)), Color(0.28, 0.35, 0.36))
	draw_rect(Rect2(Vector2(-half.x, -half.y * 0.64), Vector2(18, half.y * 1.28)), Color(0.72, 0.75, 0.72))
	draw_line(Vector2(-half.x + 18, -half.y * 0.5), Vector2(-half.x * 0.55, -half.y * 0.28), Color(0.55, 0.4, 0.08), 5.0)
	draw_line(Vector2(-half.x + 18, half.y * 0.5), Vector2(-half.x * 0.55, half.y * 0.28), Color(0.55, 0.4, 0.08), 5.0)

func _draw_dump(half: Vector2) -> void:
	_wheels(half, 3)
	draw_rect(Rect2(Vector2(-half.x * 0.78, -half.y * 0.55), Vector2(size.x * 0.42, size.y * 0.55)), Color(0.9, 0.55, 0.08))
	draw_rect(Rect2(Vector2(half.x * 0.15, -half.y * 0.42), Vector2(size.x * 0.27, size.y * 0.42)), Color(0.3, 0.38, 0.4))
	var bed := PackedVector2Array([Vector2(-half.x * 0.2, -half.y * 0.68), Vector2(half.x * 0.82, -half.y * 0.58),
		Vector2(half.x * 0.82, half.y * 0.58), Vector2(-half.x * 0.2, half.y * 0.68)])
	draw_colored_polygon(bed, Color(0.72, 0.42, 0.06))
	draw_polyline(PackedVector2Array([bed[0], bed[1], bed[2], bed[3], bed[0]]), Color(0.4, 0.24, 0.05), 3.0)

func _draw_cement(half: Vector2) -> void:
	_wheels(half, 3)
	draw_rect(Rect2(Vector2(-half.x * 0.82, -half.y * 0.48), Vector2(size.x * 0.38, size.y * 0.48)), Color(0.82, 0.48, 0.08))
	draw_rect(Rect2(Vector2(half.x * 0.2, -half.y * 0.44), Vector2(size.x * 0.24, size.y * 0.44)), Color(0.3, 0.38, 0.4))
	draw_circle(Vector2(half.x * 0.18, 0), half.y * 0.62, Color(0.72, 0.74, 0.72))
	draw_circle(Vector2(half.x * 0.18, 0), half.y * 0.62, Color(0.32, 0.34, 0.34), false, 3.0)
	for a in [-0.55, 0.0, 0.55]:
		draw_line(Vector2(half.x * 0.18, 0) + Vector2.UP.rotated(a) * half.y * 0.5,
			Vector2(half.x * 0.18, 0) + Vector2.DOWN.rotated(a) * half.y * 0.5,
			Color(0.92, 0.5, 0.08), 4.0)
