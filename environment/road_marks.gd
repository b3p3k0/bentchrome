extends Node2D
## Road markings: dashed center/lane lines, zebra crosswalks, stop lines —
## faded paint that sits INTO the worn asphalt. One node per marking run;
## `points` is a world-space polyline (local to this node), `style` picks the
## treatment. Pure paint, no collision, no gameplay.

const DASH_LEN := 42.0
const DASH_GAP := 34.0
const LINE_W := 6.0
const ZEBRA_W := 56.0     # crosswalk bar length (across the walking direction)
const ZEBRA_BAR := 16.0   # bar thickness
const ZEBRA_GAP := 16.0
const YELLOW := Color(0.85, 0.7, 0.2, 0.55)
const WHITE := Color(0.85, 0.86, 0.88, 0.5)

@export var points := PackedVector2Array()
@export var style: StringName = &"dashed_yellow"

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	match style:
		&"dashed_yellow":
			_draw_dashes(YELLOW)
		&"dashed_white":
			_draw_dashes(WHITE)
		&"crosswalk":
			_draw_zebra()
		&"stop_line":
			_draw_stop()

func _draw_dashes(color: Color) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			var seg_end := minf(t + DASH_LEN, length)
			draw_line(a + dir * t, a + dir * seg_end, color, LINE_W)
			t += DASH_LEN + DASH_GAP

func _draw_zebra() -> void:
	# Bars lie ALONG the segment direction; pedestrians walk across it.
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var dir := (b - a).normalized()
		var perp := dir.orthogonal()
		var length := a.distance_to(b)
		var t := ZEBRA_GAP
		while t + ZEBRA_BAR <= length:
			var center := a + dir * (t + ZEBRA_BAR * 0.5)
			draw_set_transform(center, dir.angle(), Vector2.ONE)
			draw_rect(Rect2(-ZEBRA_BAR * 0.5, -ZEBRA_W * 0.5, ZEBRA_BAR, ZEBRA_W), WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			t += ZEBRA_BAR + ZEBRA_GAP

func _draw_stop() -> void:
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], WHITE, 14.0)
