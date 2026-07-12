extends RefCounted
## Buzzard technical: a sagging pickup, cab pushed forward, long open bed —
## the sandbag ring mid-bed anchors the LIVE turret (Vehicle grows one at
## (2.5, 0) when stats.turret is set; it draws over this mount).

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 29.0, "half_wid": 15.0, "radius": 21.0,
	"skid_points": [Vector2(-20, -11), Vector2(-20, 11)],
	"steer_wheels": [Vector2(19, -11), Vector2(19, 11)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-20, -13), Vector2(11, 6))
	Parts.wheel(c, Vector2(-20, 13), Vector2(11, 6))
	Parts.wheel(c, Vector2(19, -13), Vector2(10, 6), steer)
	Parts.wheel(c, Vector2(19, 13), Vector2(10, 6), steer)
	var hull := Parts.hull(29, 15, 4, 3)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-26, -12, 34, 24), Color(0.16, 0.16, 0.18))  # long open bed
	c.draw_line(Vector2(-21, -12), Vector2(-21, 12), accent.darkened(0.3), 1.5)  # bed ribs
	c.draw_line(Vector2(-9, -12), Vector2(-9, 12), accent.darkened(0.3), 1.5)
	c.draw_rect(Rect2(-28, -13, 3, 26), Color(0.42, 0.42, 0.44))   # dropped tailgate, primer
	c.draw_rect(Rect2(-18, 7, 6, 4), Color(0.55, 0.32, 0.16))      # rusted fuel cans
	c.draw_rect(Rect2(-18, -11, 6, 4), Color(0.35, 0.4, 0.3))
	c.draw_rect(Rect2(8, -13, 4, 26), primary.darkened(0.35))      # cab back wall
	c.draw_rect(Rect2(12, -11, 6, 22), Parts.GLASS.darkened(0.1))  # windshield
	c.draw_rect(Rect2(18, -10, 8, 20), primary.darkened(0.15))     # stubby hood
	c.draw_rect(Rect2(27, 7, 3, 4), Parts.CLOTH)                   # one headlight — gang spec
	c.draw_circle(Vector2(2, 0), 7.5, Color(0.5, 0.44, 0.3))       # sandbag mount ring
	c.draw_circle(Vector2(2, 0), 5.0, primary.darkened(0.45))
	Parts.outline(c, hull)
