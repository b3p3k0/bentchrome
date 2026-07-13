extends Node2D
## Paint-only site kit. Solid machinery/cover is authored separately so these
## visual details can never invent collision or confuse the route graph.

const UnderFade := preload("res://environment/under_fade.gd")

@export_enum("crane", "embankment", "scaffold_grade", "washout", "ruts") var kind := "washout"
@export var size := Vector2(192, 128)
var _t := 0.0
var _under_area: Area2D = null

func _ready() -> void:
	if kind == "crane":
		z_index = 1
		_under_area = UnderFade.build_area(Vector2(size.x, 72.0))
		add_child(_under_area)
		var ground := CraneGround.new()
		ground.name = "Ground"
		ground.z_index = -1
		add_child(ground)
	queue_redraw()

## Ballast pad, anchor bolts, and the long jib shadow stay on the ground while
## the overhead jib fades for traffic passing beneath (the deck seam pattern).
class CraneGround:
	extends Node2D
	func _draw() -> void:
		get_parent().call(&"_paint_crane_ground", self)

func _process(delta: float) -> void:
	if kind == "crane":
		_t += delta
		var target: float = UnderFade.target_alpha(_under_area, z_index)
		self_modulate.a = move_toward(self_modulate.a, target, UnderFade.SPEED * delta)
		queue_redraw()

func _draw() -> void:
	match kind:
		"crane": _draw_crane()
		"embankment": _draw_embankment()
		"scaffold_grade": _draw_scaffold_grade()
		"washout": _draw_washout()
		"ruts": _draw_ruts()
		_: pass

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

## Proper tower crane: ballasted counter-jib, cross-braced mast at the west
## third, truss jib with tie lines, and a trolley walking the span with twin
## cable falls and a hook block. Ground furniture rides the CraneGround child.
func _draw_crane() -> void:
	var half := size * 0.5
	var mast_x := -size.x / 6.0
	var steel := Color(0.9, 0.62, 0.08)
	var dark := Color(0.46, 0.31, 0.05)
	draw_rect(Rect2(Vector2(mast_x - 240.0, -9.0), Vector2(240.0, 18.0)), steel)
	draw_rect(Rect2(Vector2(mast_x - 238.0, -13.0), Vector2(30.0, 26.0)), Color(0.32, 0.33, 0.36))
	draw_rect(Rect2(Vector2(mast_x - 202.0, -13.0), Vector2(30.0, 26.0)), Color(0.36, 0.37, 0.40))
	draw_line(Vector2(mast_x, -12.0), Vector2(half.x, -12.0), steel, 5.0)
	draw_line(Vector2(mast_x, 12.0), Vector2(half.x, 12.0), steel, 5.0)
	var x := mast_x + 20.0
	var flip := 1.0
	while x < half.x - 20.0:
		draw_line(Vector2(x, -12.0 * flip), Vector2(x + 40.0, 12.0 * flip), dark, 2.5)
		x += 40.0
		flip = -flip
	draw_line(Vector2(half.x - 4.0, -12.0), Vector2(half.x - 4.0, 12.0), steel, 6.0)
	draw_line(Vector2(mast_x, -2.0), Vector2((mast_x + half.x) * 0.5, -16.0),
		Color(0.75, 0.55, 0.12), 2.0)
	draw_line(Vector2((mast_x + half.x) * 0.5, -16.0), Vector2(half.x - 10.0, -12.0),
		Color(0.75, 0.55, 0.12), 2.0)
	var m := 48.0
	draw_rect(Rect2(Vector2(mast_x - m, -m), Vector2(m * 2.0, m * 2.0)), steel)
	draw_rect(Rect2(Vector2(mast_x - m, -m), Vector2(m * 2.0, m * 2.0)), dark, false, 4.0)
	draw_line(Vector2(mast_x - m, -m), Vector2(mast_x + m, m), dark, 3.0)
	draw_line(Vector2(mast_x - m, m), Vector2(mast_x + m, -m), dark, 3.0)
	draw_circle(Vector2(mast_x, 0.0), 9.0, dark)
	draw_rect(Rect2(Vector2(mast_x + m, 14.0), Vector2(30.0, 26.0)), Color(0.30, 0.32, 0.36))
	draw_rect(Rect2(Vector2(mast_x + m + 4.0, 18.0), Vector2(22.0, 10.0)),
		Color(0.55, 0.70, 0.75, 0.9))
	var tx := lerpf(mast_x + m + 60.0, half.x - 50.0, 0.5 + 0.5 * sin(_t * 0.35))
	draw_rect(Rect2(Vector2(tx - 9.0, -14.0), Vector2(18.0, 28.0)), Color(0.22, 0.22, 0.25))
	draw_line(Vector2(tx - 4.0, 10.0), Vector2(tx - 3.0, 78.0), Color(0.12, 0.12, 0.14), 2.0)
	draw_line(Vector2(tx + 4.0, 10.0), Vector2(tx + 3.0, 78.0), Color(0.12, 0.12, 0.14), 2.0)
	draw_rect(Rect2(Vector2(tx - 6.0, 78.0), Vector2(12.0, 12.0)), Color(0.2, 0.2, 0.22))
	draw_arc(Vector2(tx, 96.0), 8.0, -PI * 0.5, PI * 0.65, 10, Color(0.2, 0.2, 0.22), 3.0)
	draw_circle(Vector2(half.x - 6.0, 0.0), 6.0,
		Color(1.0, 0.62, 0.1, 0.25 + 0.2 * sin(_t * 3.0)))
	draw_circle(Vector2(half.x - 6.0, 0.0), 2.5,
		Color(1.0, 0.75, 0.3, 0.55 + 0.35 * sin(_t * 3.0)))

func _paint_crane_ground(c: CanvasItem) -> void:
	var mast_x := -size.x / 6.0
	var pad := Vector2(150, 150)
	var center := Vector2(mast_x, 0.0)
	c.draw_rect(Rect2(center - pad * 0.5 + Vector2(12, 16), pad), Color(0, 0, 0, 0.24))
	c.draw_rect(Rect2(center - pad * 0.5, pad), Color(0.42, 0.44, 0.47))
	c.draw_rect(Rect2(center - pad * 0.5, pad), Color(0.30, 0.32, 0.35), false, 3.0)
	for d: Vector2 in [Vector2(-58, -58), Vector2(58, -58), Vector2(-58, 58), Vector2(58, 58)]:
		c.draw_circle(center + d, 5.0, Color(0.24, 0.25, 0.28))
	c.draw_rect(Rect2(Vector2(mast_x, 10.0), Vector2(size.x * 0.5 - mast_x, 26.0)),
		Color(0, 0, 0, 0.16))

## Dried concrete washout splat near the cement truck.
func _draw_washout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	var r := minf(size.x, size.y) * 0.5
	for i in 5:
		var p := Vector2(rng.randf_range(-size.x * 0.3, size.x * 0.3),
			rng.randf_range(-size.y * 0.3, size.y * 0.3))
		draw_circle(p, rng.randf_range(r * 0.4, r * 0.8), Color(0.66, 0.67, 0.65, 0.35))
	draw_circle(Vector2.ZERO, r * 0.5, Color(0.72, 0.73, 0.71, 0.5))
	draw_circle(Vector2(6, 4), r * 0.22, Color(0.58, 0.59, 0.57, 0.6))
	for i in 4:
		var a := rng.randf_range(0.0, TAU)
		var p0 := Vector2.RIGHT.rotated(a) * r * 0.5
		draw_line(p0, p0 + Vector2.RIGHT.rotated(a) * rng.randf_range(14.0, 30.0),
			Color(0.66, 0.67, 0.65, 0.4), 5.0)

## Paired haul-truck ruts churned into a mud basin lip.
func _draw_ruts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	var half := size * 0.5
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var phase := rng.randf_range(0.0, TAU)
		var x := -half.x
		while x <= half.x:
			pts.append(Vector2(x, s * 17.0 + sin(x * 0.02 + phase) * 9.0))
			x += 28.0
		draw_polyline(pts, Color(0.22, 0.15, 0.09, 0.75), 10.0)
		draw_polyline(pts, Color(0.14, 0.09, 0.05, 0.6), 4.0)
	for i in 8:
		draw_circle(Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-40.0, 40.0)),
			rng.randf_range(3.0, 7.0), Color(0.20, 0.13, 0.08, 0.5))
