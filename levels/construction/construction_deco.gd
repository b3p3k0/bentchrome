extends Node2D
## Paint-only site kit. Solid machinery/cover is authored separately so these
## visual details can never invent collision or confuse the route graph.

@export_enum("rebar", "pipes", "spool", "forms", "crane", "embankment", "scaffold_grade") \
	var kind := "rebar"
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
		"embankment": _draw_embankment()
		"scaffold_grade": _draw_scaffold_grade()
		_: _draw_rebar()

## The ramp.gd band idiom for surface_paint=false grades: lit high end (-y),
## shaded low end — the slope read every driveable grade in the game shares.
func _draw_grade_bands(half: Vector2) -> void:
	var step_h := size.y / 6.0
	for i in 6:
		var t := float(i) / 5.0
		var band := Rect2(Vector2(-half.x, -half.y + float(i) * step_h),
			Vector2(size.x, step_h + 1.0))
		draw_rect(band, Color(1, 1, 1, 0.14 * (1.0 - t)))
		draw_rect(band, Color(0, 0, 0, 0.16 * t))

## Skin for the west dirt embankment (its Ramp runs zones/rails/pull with
## surface_paint=false): packed haul dirt, pushed-up berms, twin ruts, an
## apron fanning onto the yard at the low mouth, a cut line at the slab lip.
func _draw_embankment() -> void:
	var half := size * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x, half.y), Vector2(half.x, half.y),
		Vector2(half.x + 36.0, half.y + 44.0), Vector2(-half.x - 36.0, half.y + 44.0),
	]), Color(0.44, 0.32, 0.19, 0.85))
	draw_rect(Rect2(-half, size), Color(0.48, 0.36, 0.22))
	draw_rect(Rect2(-half, Vector2(14.0, size.y)), Color(0.33, 0.24, 0.14))
	draw_rect(Rect2(Vector2(half.x - 14.0, -half.y), Vector2(14.0, size.y)),
		Color(0.33, 0.24, 0.14))
	_draw_grade_bands(half)
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var y := -half.y + 8.0
		while y <= half.y - 8.0:
			pts.append(Vector2(s * size.x * 0.22 + sin(y * 0.03 + s) * 7.0, y))
			y += 24.0
		draw_polyline(pts, Color(0.30, 0.21, 0.12, 0.85), 9.0)
	draw_line(Vector2(-half.x, -half.y + 2.0), Vector2(half.x, -half.y + 2.0),
		Color(0.25, 0.20, 0.13), 4.0)

## Skin for the courtyard scaffold ramps: steel treads, side stringers, the
## deck rack's yellow lips, and up-slope chevrons matching ramp grammar.
func _draw_scaffold_grade() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.40, 0.42, 0.46))
	var y := -half.y + 16.0
	while y < half.y:
		draw_line(Vector2(-half.x + 4.0, y), Vector2(half.x - 4.0, y),
			Color(0.33, 0.35, 0.39), 1.5)
		y += 32.0
	draw_rect(Rect2(-half, Vector2(8.0, size.y)), Color(0.30, 0.32, 0.36))
	draw_rect(Rect2(Vector2(half.x - 8.0, -half.y), Vector2(8.0, size.y)),
		Color(0.30, 0.32, 0.36))
	_draw_grade_bands(half)
	draw_rect(Rect2(-half, Vector2(6.0, size.y)), Color(0.92, 0.72, 0.18))
	draw_rect(Rect2(Vector2(half.x - 6.0, -half.y), Vector2(6.0, size.y)),
		Color(0.92, 0.72, 0.18))
	var chevrons := maxi(int(size.y / 112.0), 2)
	for i in chevrons:
		var cy := -half.y + size.y * (float(i) + 0.5) / float(chevrons)
		draw_polyline(PackedVector2Array([
			Vector2(-11.0, cy + 7.0), Vector2(0.0, cy - 7.0), Vector2(11.0, cy + 7.0),
		]), Color(0.95, 0.9, 0.6, 0.5), 3.0)

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
