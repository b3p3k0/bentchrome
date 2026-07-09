class_name Ramp
extends Area2D
## Launches a vehicle that drives over it into the air (fake depth).
## Paint: reads size from the Col rect (building_deco pattern), hides the flat
## orange Vis, and draws a truncated 4-sided pyramid — trapezoid faces rising
## to a caution-striped plateau, hazard-striped border around the FULL
## perimeter. Ramps launch in whatever direction you're moving, so the paint
## is deliberately omnidirectional (authored square); the striped top reads
## "launcher marker", not a parkable platform.

const FACE_LIT := Color(1.0, 0.72, 0.25)   # north face — sun from the top
const FACE_MID := Color(0.85, 0.55, 0.16)  # east/west faces
const FACE_DARK := Color(0.6, 0.37, 0.1)   # south face
const SEAM := Color(0.34, 0.2, 0.06)
const STRIPE_DARK := Color(0.12, 0.12, 0.14)
const STRIPE_YELLOW := Color(0.95, 0.8, 0.2)
const RAIL_W := 8.0        # hazard border thickness
const STRIPE_LEN := 16.0   # border stripe cadence
const TOP_FRAC := 0.4      # plateau size as a fraction of the footprint
const TOP_STRIPE_W := 7.0  # caution band width on the plateau
const TOP_STRIPE_GAP := 14.0

var _size := Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var col := get_node_or_null(^"Col") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		_size = col.shape.size
		var vis := get_node_or_null(^"Vis") as CanvasItem
		if vis:
			vis.visible = false
		queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Vehicle:
		body.launch_from_ramp()

func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	var half := _size * 0.5
	var inner := half - Vector2(RAIL_W, RAIL_W)
	var top := half * TOP_FRAC
	# Four trapezoid faces from the border to the plateau (N E S W).
	var o := [Vector2(-inner.x, -inner.y), Vector2(inner.x, -inner.y),
		Vector2(inner.x, inner.y), Vector2(-inner.x, inner.y)]
	var t := [Vector2(-top.x, -top.y), Vector2(top.x, -top.y),
		Vector2(top.x, top.y), Vector2(-top.x, top.y)]
	var face := [FACE_LIT, FACE_MID, FACE_DARK, FACE_MID]
	for i in 4:
		var j := (i + 1) % 4
		draw_colored_polygon(PackedVector2Array([o[i], o[j], t[j], t[i]]), face[i])
	for i in 4:  # pyramid corner seams
		draw_line(o[i], t[i], SEAM, 2.0)
	_draw_caution_top(top)
	_draw_border(half)

## Plateau: yellow base + 45° black bands, clipped to the rect by walking the
## family of lines x + y = c and clamping each to the plateau bounds.
func _draw_caution_top(top: Vector2) -> void:
	draw_rect(Rect2(-top, top * 2.0), STRIPE_YELLOW)
	var reach := top.x + top.y
	var c := -reach + TOP_STRIPE_GAP * 0.5
	while c < reach:
		var x0 := maxf(-top.x, c - top.y)
		var x1 := minf(top.x, c + top.y)
		if x1 > x0:
			draw_line(Vector2(x0, c - x0), Vector2(x1, c - x1), STRIPE_DARK, TOP_STRIPE_W)
		c += TOP_STRIPE_GAP
	draw_rect(Rect2(-top, top * 2.0), STRIPE_DARK, false, 2.0)

## Hazard border: alternating stripes around all four edges, dark corners.
func _draw_border(half: Vector2) -> void:
	for horiz in [true, false]:
		var run := (half.x if horiz else half.y) * 2.0
		var stripes := int(run / STRIPE_LEN)
		for i in stripes:
			var c := STRIPE_YELLOW if i % 2 == 0 else STRIPE_DARK
			var s := -(run * 0.5) + i * STRIPE_LEN
			var e := minf(s + STRIPE_LEN, run * 0.5)
			if horiz:
				draw_rect(Rect2(s, -half.y, e - s, RAIL_W), c)
				draw_rect(Rect2(s, half.y - RAIL_W, e - s, RAIL_W), c)
			else:
				draw_rect(Rect2(-half.x, s, RAIL_W, e - s), c)
				draw_rect(Rect2(half.x - RAIL_W, s, RAIL_W, e - s), c)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at: Vector2 = corner * half
		var pos := Vector2(at.x - (RAIL_W if corner.x > 0.0 else 0.0),
			at.y - (RAIL_W if corner.y > 0.0 else 0.0))
		draw_rect(Rect2(pos, Vector2(RAIL_W, RAIL_W)), STRIPE_DARK)
