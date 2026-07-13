extends Node2D
## Paint-only perimeter dressing: a concrete jersey-barrier ring at the arena
## boundary plus a dark apron beyond it, so the camera never sees raw void at
## the map edge. The Boundary StaticBody stays the physics; this never
## collides and AI feelers never see it.

const APRON := 700.0
const BAND := 44.0
const SEG := 128.0
const APRON_COLOR := Color(0.07, 0.07, 0.08)
const FACE := Color(0.52, 0.53, 0.55)
const FACE_TOP := Color(0.63, 0.64, 0.66)
const FACE_BASE := Color(0.38, 0.39, 0.42)
const SEAM := Color(0.30, 0.31, 0.34)

@export var extent := Vector2(2304, 1920)  # arena half-size; band sits on the wall line

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var outer := extent + Vector2.ONE * APRON
	# Dark apron under everything out to the horizon. Author this node BEFORE
	# the arena's ground surface: the surface repaints the playfield interior,
	# leaving only the outside ring visible.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-outer.x, -outer.y), Vector2(outer.x, -outer.y),
		Vector2(outer.x, outer.y), Vector2(-outer.x, outer.y),
	]), APRON_COLOR)
	# Barricade bands, one per side, sitting on the wall line.
	_band(Rect2(Vector2(-extent.x - BAND, -extent.y - BAND),
		Vector2(extent.x * 2.0 + BAND * 2.0, BAND)), true)   # north
	_band(Rect2(Vector2(-extent.x - BAND, extent.y),
		Vector2(extent.x * 2.0 + BAND * 2.0, BAND)), true)   # south
	_band(Rect2(Vector2(-extent.x - BAND, -extent.y),
		Vector2(BAND, extent.y * 2.0)), false)               # west
	_band(Rect2(Vector2(extent.x, -extent.y),
		Vector2(BAND, extent.y * 2.0)), false)               # east

## One jersey run: sloped-face read from a light crown stripe over the body
## with a dark base, segment seams every SEG, end blocks.
func _band(rect: Rect2, horizontal: bool) -> void:
	draw_rect(rect, FACE)
	if horizontal:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10.0)), FACE_TOP)
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 8.0),
			Vector2(rect.size.x, 8.0)), FACE_BASE)
		var x := rect.position.x + SEG
		while x < rect.end.x - 4.0:
			draw_line(Vector2(x, rect.position.y + 2.0), Vector2(x, rect.end.y - 2.0), SEAM, 2.0)
			x += SEG
	else:
		draw_rect(Rect2(rect.position, Vector2(10.0, rect.size.y)), FACE_TOP)
		draw_rect(Rect2(Vector2(rect.end.x - 8.0, rect.position.y),
			Vector2(8.0, rect.size.y)), FACE_BASE)
		var y := rect.position.y + SEG
		while y < rect.end.y - 4.0:
			draw_line(Vector2(rect.position.x + 2.0, y), Vector2(rect.end.x - 2.0, y), SEAM, 2.0)
			y += SEG
	draw_rect(rect, SEAM, false, 2.0)
