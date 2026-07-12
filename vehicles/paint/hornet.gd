extends RefCounted
## Hornet: the classic NYC checker cab — yellow slab, black-and-white checker
## band down both sides, rooftop TAXI light, meter always running.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 27.0, "half_wid": 13.0, "radius": 18.0,
	"skid_points": [Vector2(-19, -10), Vector2(-19, 10)],
	"steer_wheels": [],
}

const CHECKER_DARK := Color(0.06, 0.06, 0.08)
const CHECKER_LIGHT := Color(0.92, 0.92, 0.9)

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-17, -11), Vector2(10, 5))
	Parts.wheel(c, Vector2(-17, 11), Vector2(10, 5))
	Parts.wheel(c, Vector2(17, -11), Vector2(10, 5))
	Parts.wheel(c, Vector2(17, 11), Vector2(10, 5))
	var hull := Parts.hull(27, 11, 6, 4)
	c.draw_colored_polygon(hull, primary)
	for i in range(14):                                            # checker band, both flanks
		var x := -23.0 + 3.2 * float(i)
		var even := i % 2 == 0
		c.draw_rect(Rect2(x, -11, 3.2, 3), CHECKER_DARK if even else CHECKER_LIGHT)
		c.draw_rect(Rect2(x, 8, 3.2, 3), CHECKER_LIGHT if even else CHECKER_DARK)
	c.draw_rect(Rect2(6, -9, 5, 18), Parts.GLASS)                  # windshield band
	c.draw_rect(Rect2(-14, -8, 18, 16), primary.darkened(0.15))    # long cab roof
	c.draw_rect(Rect2(-16, -8, 3, 16), Parts.GLASS.darkened(0.2))  # rear glass
	c.draw_rect(Rect2(-6, -4, 8, 8), accent)                       # rooftop TAXI light base
	c.draw_rect(Rect2(-4, -2.5, 4, 5), Parts.NOSE_ACCENT)          # the lit dome
	c.draw_line(Vector2(11, -10), Vector2(11, 10), Parts.OUTLINE, 1.2)  # hood seam
	c.draw_rect(Rect2(26, -7, 2, 14), Parts.CHROME)                # steel bumper
	Parts.headlights(c, 27, 11)
	Parts.outline(c, hull)
