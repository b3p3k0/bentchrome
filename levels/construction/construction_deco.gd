extends Node2D
## Paint-only site kit. Solid machinery/cover is authored separately so these
## visual details can never invent collision or confuse the route graph.

@export_enum("rebar", "pipes", "spool", "forms", "crane") var kind := "rebar"
@export var size := Vector2(192, 128)
var _t := 0.0
var _under_area: Area2D = null

func _ready() -> void:
	if kind == "crane":
		z_index = 1
		_under_area = Area2D.new()
		_under_area.collision_layer = 0
		_under_area.collision_mask = 1
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(size.x, 72.0)
		col.shape = shape
		_under_area.add_child(col)
		add_child(_under_area)
	queue_redraw()

func _process(delta: float) -> void:
	if kind == "crane":
		_t += delta
		var target := 1.0
		for body in _under_area.get_overlapping_bodies():
			if body is CanvasItem and (body as CanvasItem).z_index < z_index:
				target = 0.42
				break
		modulate.a = move_toward(modulate.a, target, delta * 6.0)
		queue_redraw()

func _draw() -> void:
	match kind:
		"pipes": _draw_pipes()
		"spool": _draw_spool()
		"forms": _draw_forms()
		"crane": _draw_crane()
		_: _draw_rebar()

func _draw_rebar() -> void:
	var half := size * 0.5
	for x in range(int(-half.x), int(half.x) + 1, 18):
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(0.42, 0.25, 0.16), 2.0)
	for y in range(int(-half.y), int(half.y) + 1, 18):
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(0.35, 0.21, 0.14), 1.5)

func _draw_pipes() -> void:
	for y in [-28.0, 0.0, 28.0]:
		for x in [-56.0, 0.0, 56.0]:
			draw_circle(Vector2(x, y), 17.0, Color(0.42, 0.45, 0.46))
			draw_circle(Vector2(x, y), 10.0, Color(0.14, 0.16, 0.17))

func _draw_spool() -> void:
	draw_circle(Vector2.ZERO, minf(size.x, size.y) * 0.42, Color(0.48, 0.34, 0.19))
	draw_circle(Vector2.ZERO, minf(size.x, size.y) * 0.20, Color(0.14, 0.14, 0.15))
	for a in range(0, 360, 45):
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(a)) * minf(size.x, size.y) * 0.38,
			Color(0.28, 0.20, 0.12), 4.0)

func _draw_forms() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.50, 0.38, 0.23), false, 8.0)
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, half.y), Color(0.30, 0.22, 0.13), 4.0)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, -half.y), Color(0.30, 0.22, 0.13), 4.0)

func _draw_crane() -> void:
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-half.x, -9), Vector2(size.x, 18)), Color(0.9, 0.62, 0.08))
	for x in range(int(-half.x + 24), int(half.x), 40):
		draw_line(Vector2(x, -9), Vector2(x - 16, 9), Color(0.46, 0.31, 0.05), 2.0)
	var hook_x := sin(_t * 0.55) * size.x * 0.18
	draw_line(Vector2(hook_x, 0), Vector2(hook_x, 72), Color(0.12, 0.12, 0.14), 2.0)
	draw_arc(Vector2(hook_x, 80), 8.0, -PI * 0.5, PI * 0.65, 10, Color(0.2, 0.2, 0.22), 3.0)
