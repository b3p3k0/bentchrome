extends RefCounted
## Hammertoe: monster truck — wheels the size of the cab, open bed, blower.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 30.0, "half_wid": 23.0, "radius": 26.0,
	"skid_points": [Vector2(-17, -17), Vector2(-17, 17)],
	"steer_wheels": [Vector2(17, -17), Vector2(17, 17)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-17, -17), Vector2(16, 12))
	Parts.wheel(c, Vector2(-17, 17), Vector2(16, 12))
	Parts.wheel(c, Vector2(17, -17), Vector2(16, 12), steer)
	Parts.wheel(c, Vector2(17, 17), Vector2(16, 12), steer)
	var hull := Parts.hull(24, 12, 5, 3)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-22, -10, 16, 20), Color(0.15, 0.15, 0.18))  # open bed
	c.draw_line(Vector2(-19, -10), Vector2(-19, 10), accent, 1.5)  # bed crossbars
	c.draw_line(Vector2(-14, -10), Vector2(-14, 10), accent, 1.5)
	c.draw_rect(Rect2(-6, -11, 4, 22), primary.darkened(0.3))      # cab back wall
	c.draw_rect(Rect2(2, -10, 6, 20), Parts.GLASS)                 # windshield
	c.draw_rect(Rect2(-2, -9, 4, 18), primary.darkened(0.15))      # cab roof
	c.draw_rect(Rect2(12, -5, 8, 10), Parts.TIRE)                  # hood blower
	c.draw_circle(Vector2(16, -2.5), 1.6, Parts.CHROME)
	c.draw_circle(Vector2(16, 2.5), 1.6, Parts.CHROME)
	c.draw_circle(Vector2(-7, -9), 1.8, Parts.CHROME)              # exhaust stacks
	c.draw_circle(Vector2(-7, 9), 1.8, Parts.CHROME)
	Parts.headlights(c, 24, 12)
	Parts.outline(c, hull)
