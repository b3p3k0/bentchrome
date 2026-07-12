extends RefCounted
## Cyclone: the escaped F1 car — exposed wheels, dart body, sidepods, big
## rear wing, and a cockpit barely wide enough for Mandy and her opinions.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 26.0, "half_wid": 8.0, "radius": 13.5,
	"skid_points": [Vector2(-17, -7), Vector2(-17, 7)],
	"steer_wheels": [Vector2(14, -6.5), Vector2(14, 6.5)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	c.draw_rect(Rect2(-24, -9, 4, 18), accent)                     # rear wing plane
	c.draw_rect(Rect2(-25, -9, 6, 2), Parts.OUTLINE)               # wing endplates
	c.draw_rect(Rect2(-25, 7, 6, 2), Parts.OUTLINE)
	Parts.wheel(c, Vector2(-17, -7), Vector2(9, 5))                # fat slicks
	Parts.wheel(c, Vector2(-17, 7), Vector2(9, 5))
	Parts.wheel(c, Vector2(14, -6.5), Vector2(8, 4), steer)
	Parts.wheel(c, Vector2(14, 6.5), Vector2(8, 4), steer)
	var dart := PackedVector2Array([                               # needle monocoque
		Vector2(-20, -4), Vector2(-12, -5), Vector2(2, -5), Vector2(16, -3),
		Vector2(26, -1.2), Vector2(26, 1.2), Vector2(16, 3), Vector2(2, 5),
		Vector2(-12, 5), Vector2(-20, 4),
	])
	c.draw_colored_polygon(dart, primary)
	c.draw_rect(Rect2(-8, -8, 12, 3), primary.darkened(0.25))      # sidepods
	c.draw_rect(Rect2(-8, 5, 12, 3), primary.darkened(0.25))
	c.draw_line(Vector2(10, 0), Vector2(25, 0), accent, 1.6)       # nose stripe
	c.draw_rect(Rect2(23, -7, 3, 14), accent)                      # front wing
	c.draw_circle(Vector2(-2, 0), 3.2, Parts.GLASS)                # cockpit bubble
	c.draw_arc(Vector2(-2, 0), 4.2, PI + 0.6, TAU - 0.6, 8, Parts.OUTLINE, 1.4)  # halo
	c.draw_circle(Vector2(-13, 0), 2.4, Parts.TIRE)                # engine intake
	c.draw_circle(Vector2(-13, 0), 1.0, Parts.CHROME)
	Parts.outline(c, dart)
