extends RefCounted
## Lovebug: the flower-power Beetle — rounded capsule shell, curved fenders,
## split windshield, peace sign on the roof, daisies on the hood and trunk.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 22.0, "half_wid": 13.0, "radius": 16.0,
	"skid_points": [Vector2(-15, -9), Vector2(-15, 9)],
	"steer_wheels": [],
}

const DAISY := Color(0.97, 0.96, 0.9)

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-14, -11), Vector2(9, 5))
	Parts.wheel(c, Vector2(-14, 11), Vector2(9, 5))
	Parts.wheel(c, Vector2(14, -11), Vector2(8, 5))
	Parts.wheel(c, Vector2(14, 11), Vector2(8, 5))
	var shell := PackedVector2Array([                              # rounded capsule
		Vector2(-22, -6), Vector2(-18, -10), Vector2(-10, -13), Vector2(10, -13),
		Vector2(18, -10), Vector2(22, -6), Vector2(22, 6), Vector2(18, 10),
		Vector2(10, 13), Vector2(-10, 13), Vector2(-18, 10), Vector2(-22, 6),
	])
	c.draw_colored_polygon(shell, primary)
	c.draw_arc(Vector2(14, -11), 6.5, PI, TAU, 10, primary.darkened(0.3), 2.0)   # fender bulges
	c.draw_arc(Vector2(14, 11), 6.5, 0.0, PI, 10, primary.darkened(0.3), 2.0)
	c.draw_arc(Vector2(-14, -11), 7.0, PI, TAU, 10, primary.darkened(0.3), 2.0)
	c.draw_arc(Vector2(-14, 11), 7.0, 0.0, PI, 10, primary.darkened(0.3), 2.0)
	c.draw_rect(Rect2(6, -10, 4, 20), Parts.GLASS)                 # split windshield
	c.draw_line(Vector2(8, -10), Vector2(8, 10), Parts.OUTLINE, 1.0)
	c.draw_circle(Vector2(-2, 0), 8.5, primary.darkened(0.12))     # domed roof
	c.draw_arc(Vector2(-2, 0), 5.0, 0.0, TAU, 14, accent, 1.6)     # roof peace sign
	c.draw_line(Vector2(-2, -5), Vector2(-2, 5), accent, 1.6)
	c.draw_line(Vector2(-2, 0), Vector2(-5.5, 3.5), accent, 1.6)
	c.draw_line(Vector2(-2, 0), Vector2(1.5, 3.5), accent, 1.6)
	for at in [Vector2(16, -5), Vector2(15, 6), Vector2(-17, -4), Vector2(-16, 5)]:
		for k in 5:                                                # daisy petals
			var petal: Vector2 = at + Vector2.RIGHT.rotated(TAU * float(k) / 5.0) * 2.2
			c.draw_circle(petal, 1.3, DAISY)
		c.draw_circle(at, 1.2, accent)                             # daisy heart
	c.draw_rect(Rect2(-24, -3, 2, 6), Parts.CHROME)                # rear bumperette
	Parts.headlights(c, 22, 9)
	Parts.outline(c, shell)
