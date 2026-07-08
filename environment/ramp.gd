class_name Ramp
extends Area2D
## Launches a vehicle that drives over it into the air (fake depth).
## Paint: reads size from the Col rect (building_deco pattern), hides the flat
## orange Vis, and draws a crowned launcher — gradient bands rising to a bright
## center ridge with hazard-striped rails. Ramps launch in whatever direction
## you're moving, so the paint is symmetric along the long axis.

const BAND_DARK := Color(0.5, 0.3, 0.08)
const BAND_BRIGHT := Color(1.0, 0.68, 0.22)
const RIDGE := Color(1.0, 0.92, 0.55)
const STRIPE_DARK := Color(0.12, 0.12, 0.14)
const STRIPE_YELLOW := Color(0.95, 0.8, 0.2)
const BANDS := 4          # gradient steps from each end to the ridge
const RAIL_W := 6.0       # hazard rail thickness
const STRIPE_LEN := 16.0

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
	var tall := _size.y >= _size.x  # long axis = travel axis
	var long_half := half.y if tall else half.x
	# Gradient bands from both ends up to the bright center ridge.
	for i in BANDS:
		var t0 := float(i) / BANDS
		var t1 := float(i + 1) / BANDS
		var shade := BAND_DARK.lerp(BAND_BRIGHT, t1)
		var a := long_half * (1.0 - t0)
		var b := long_half * (1.0 - t1)
		if tall:
			draw_rect(Rect2(-half.x, b, _size.x, a - b), shade)
			draw_rect(Rect2(-half.x, -a, _size.x, a - b), shade)
		else:
			draw_rect(Rect2(b, -half.y, a - b, _size.y), shade)
			draw_rect(Rect2(-a, -half.y, a - b, _size.y), shade)
	# Center ridge — the lip you leave the ground from.
	if tall:
		draw_rect(Rect2(-half.x, -3, _size.x, 6), RIDGE)
	else:
		draw_rect(Rect2(-3, -half.y, 6, _size.y), RIDGE)
	# Hazard rails along the travel edges.
	var stripes := int((long_half * 2.0) / STRIPE_LEN)
	for i in stripes:
		var c := STRIPE_YELLOW if i % 2 == 0 else STRIPE_DARK
		var s := -long_half + i * STRIPE_LEN
		var e := minf(s + STRIPE_LEN, long_half)
		if tall:
			draw_rect(Rect2(-half.x, s, RAIL_W, e - s), c)
			draw_rect(Rect2(half.x - RAIL_W, s, RAIL_W, e - s), c)
		else:
			draw_rect(Rect2(s, -half.y, e - s, RAIL_W), c)
			draw_rect(Rect2(s, half.y - RAIL_W, e - s, RAIL_W), c)
