extends RefCounted
## Mr. Ghastly: a hog and its rider — two wheels, tank, bars, helmet on top.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 18.0, "half_wid": 7.0, "radius": 12.0,
	"skid_points": [Vector2(-13, 0)],
	"steer_wheels": [Vector2(13, 0)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-13, 0), Vector2(9, 5))
	Parts.wheel(c, Vector2(13, 0), Vector2(8, 4), steer)
	c.draw_line(Vector2(-16, -4), Vector2(-2, -3), Parts.CHROME, 1.5)  # exhaust pipes
	c.draw_line(Vector2(-16, 4), Vector2(-2, 3), Parts.CHROME, 1.5)
	c.draw_colored_polygon(PackedVector2Array([                         # frame + tank
		Vector2(-10, -2.5), Vector2(2, -3.5), Vector2(9, -2.5),
		Vector2(9, 2.5), Vector2(2, 3.5), Vector2(-10, 2.5),
	]), primary)
	c.draw_line(Vector2(8, -6), Vector2(8, 6), Parts.OUTLINE, 2.0)      # handlebars
	c.draw_rect(Rect2(-8, -4.5, 8, 9), accent.darkened(0.45))           # rider shoulders
	c.draw_circle(Vector2(-1, 0), 3.2, accent)                          # helmet
	c.draw_circle(Vector2(-1, 0), 1.2, Parts.GLASS)                     # visor glint
	c.draw_rect(Rect2(16, -1.5, 3, 3), Parts.NOSE_ACCENT)               # headlamp
