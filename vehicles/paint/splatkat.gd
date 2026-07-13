extends RefCounted
## Splat Cat: muscle — fat rear tires poking out, hood scoop, hunched roof.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 27.0, "half_wid": 13.0, "radius": 19.0,
	"skid_points": [Vector2(-19, -11), Vector2(-19, 11)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-15, -11), Vector2(13, 6))
	Parts.wheel(c, Vector2(-15, 11), Vector2(13, 6))
	Parts.wheel(c, Vector2(16, -10), Vector2(9, 4))
	Parts.wheel(c, Vector2(16, 10), Vector2(9, 4))
	var hull := Parts.hull(27, 11, 6, 5)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-18, -9, 6, 18), primary.darkened(0.3))    # rear haunch shade
	c.draw_rect(Rect2(-2, -9, 8, 18), Parts.GLASS)               # windshield band
	c.draw_rect(Rect2(-14, -8, 12, 16), primary.darkened(0.18))  # roof
	c.draw_rect(Rect2(8, -4, 12, 8), primary.darkened(0.35))     # hood scoop
	c.draw_rect(Rect2(10, -2, 8, 4), accent)                     # scoop mouth
	c.draw_rect(Rect2(-27, -6, 2, 4), Parts.CHROME)              # twin exhausts
	c.draw_rect(Rect2(-27, 2, 2, 4), Parts.CHROME)
	Parts.headlights(c, 27, 11)
	Parts.outline(c, hull)
