extends RefCounted
## Kandy Kane: the ice-cream truck — cream box, polka dots, roof cone, window.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 29.0, "half_wid": 17.0, "radius": 22.0,
	"skid_points": [Vector2(-22, -12), Vector2(-22, 12)],
	"steer_wheels": [],
}

# Kandy Kane's polka dots — fixed pattern, same truck every boot.
const KANDY_DOTS := [
	Vector2(-24, -8), Vector2(-19, 6), Vector2(-12, -3), Vector2(-6, 9),
	Vector2(-4, -10), Vector2(3, 2), Vector2(9, -7), Vector2(11, 9),
]

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-18, -16), Vector2(10, 5))
	Parts.wheel(c, Vector2(-18, 16), Vector2(10, 5))
	Parts.wheel(c, Vector2(18, -16), Vector2(10, 5))
	Parts.wheel(c, Vector2(18, 16), Vector2(10, 5))
	var hull := Parts.hull(29, 15, 5, 2)
	c.draw_colored_polygon(hull, Parts.CLOTH)                      # cream box body
	for d in KANDY_DOTS:                                           # polka dots
		c.draw_circle(d, 2.4, primary)
	c.draw_rect(Rect2(16, -12, 5, 24), Parts.GLASS)                # cab windshield
	c.draw_rect(Rect2(21, -15, 8, 30), primary)                    # candy nose band
	c.draw_rect(Rect2(-8, 11, 12, 4), Parts.GLASS)                 # serving window
	c.draw_rect(Rect2(-9, 10, 14, 1.5), accent)                    # awning stripe
	c.draw_colored_polygon(PackedVector2Array([                    # roof cone art
		Vector2(-4, -6), Vector2(-4, 6), Vector2(8, 0),
	]), Color(0.85, 0.65, 0.35))
	c.draw_circle(Vector2(-6, 0), 4.0, accent)                     # the scoop
	Parts.headlights(c, 29, 15)
	Parts.outline(c, hull)
