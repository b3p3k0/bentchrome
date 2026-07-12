extends RefCounted
## Bumper: the pink land-yacht — white cloth roof, chrome strip, tail fins.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 31.0, "half_wid": 13.0, "radius": 20.0,
	"skid_points": [Vector2(-24, -9), Vector2(-24, 9)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	var hull := Parts.hull(31, 11, 6, 3)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-31, -13, 5, 5), accent)                   # tail fins (poke wide)
	c.draw_rect(Rect2(-31, 8, 5, 5), accent)
	c.draw_line(Vector2(9, 0), Vector2(30, 0), Parts.CHROME, 2.0)  # hood chrome
	c.draw_rect(Rect2(3, -9, 6, 18), Parts.GLASS)                # windshield band
	var roof := Parts.hull(11, 9, 3, 3)                          # cloth top (centered)
	c.draw_set_transform(Vector2(-9, 0), 0.0, Vector2.ONE)
	c.draw_colored_polygon(roof, Parts.CLOTH)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_rect(Rect2(-22, -2, 3, 4), Parts.CLOTH.darkened(0.2))  # roof seam button
	Parts.headlights(c, 31, 11)
	Parts.outline(c, hull)
