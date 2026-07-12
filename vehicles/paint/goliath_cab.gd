extends RefCounted
## Goliath, the tractor: long hood, chrome grille and tanks, sleeper cab,
## twin exhaust stacks (the engine-rev smoke anchors: local (-8, ±14)), and
## the fifth-wheel plate at the rear where the trailer's kingpin rides.
## Stadium boss, roster-external — ×1.6 body_scale makes it the biggest
## thing rolling.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 34.0, "half_wid": 16.0, "radius": 26.0,
	"skid_points": [Vector2(-21, -14), Vector2(-21, 14)],
	"steer_wheels": [Vector2(24, -13), Vector2(24, 13)],
}

static func paint(c: CanvasItem, primary: Color, _accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(24, -13), Vector2(11, 5), steer)
	Parts.wheel(c, Vector2(24, 13), Vector2(11, 5), steer)
	for x in [-16.0, -26.0]:
		Parts.wheel(c, Vector2(x, -14), Vector2(12, 6))
		Parts.wheel(c, Vector2(x, 14), Vector2(12, 6))
	var hull := Parts.hull(34, 15, 7, 4)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-33, -7, 18, 14), Color(0.15, 0.15, 0.18))   # exposed frame rails
	c.draw_circle(Vector2(-26, 0), 7.0, Parts.TIRE)                # fifth-wheel plate
	c.draw_circle(Vector2(-26, 0), 4.5, Color(0.3, 0.3, 0.34))
	c.draw_rect(Rect2(-31, -1.5, 6, 3), Parts.OUTLINE)             # kingpin slot
	c.draw_rect(Rect2(8, -11, 22, 22), primary.darkened(0.12))     # the long hood
	c.draw_line(Vector2(8, 0), Vector2(31, 0), Parts.CHROME, 2.0)  # hood chrome spine
	c.draw_rect(Rect2(30, -9, 3, 18), Color(0.15, 0.15, 0.18))     # grille
	c.draw_rect(Rect2(33, -11, 3, 22), Parts.CHROME)               # road-train bumper
	c.draw_rect(Rect2(1, -13, 6, 26), Parts.GLASS)                 # windshield band
	c.draw_rect(Rect2(-7, -14, 8, 28), primary.darkened(0.15))     # cab roof
	c.draw_rect(Rect2(-15, -14, 8, 28), primary.darkened(0.28))    # sleeper box
	c.draw_rect(Rect2(0, -17, 10, 3), Parts.CHROME.darkened(0.2))  # side fuel tanks
	c.draw_rect(Rect2(0, 14, 10, 3), Parts.CHROME.darkened(0.2))
	c.draw_circle(Vector2(-8, -14), 2.4, Parts.CHROME)             # exhaust stacks
	c.draw_circle(Vector2(-8, 14), 2.4, Parts.CHROME)
	c.draw_circle(Vector2(-8, -14), 1.0, Color(0.15, 0.15, 0.18))
	c.draw_circle(Vector2(-8, 14), 1.0, Color(0.15, 0.15, 0.18))
	Parts.headlights(c, 33, 12)
	Parts.outline(c, hull)
