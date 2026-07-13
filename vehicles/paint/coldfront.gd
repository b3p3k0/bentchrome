extends RefCounted
## Coldfront: crimson '80s pickup with a yellow county snowplow — dually rear
## axle, amber beacon, twenty winters of grudge riding up front.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 31.0, "half_wid": 15.0, "radius": 23.0,
	"skid_points": [Vector2(-17, -12), Vector2(-17, 12)],
	"steer_wheels": [Vector2(15, -12), Vector2(15, 12)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-20, -12), Vector2(9, 7))   # dually rear axle
	Parts.wheel(c, Vector2(-14, -12), Vector2(9, 7))
	Parts.wheel(c, Vector2(-20, 12), Vector2(9, 7))
	Parts.wheel(c, Vector2(-14, 12), Vector2(9, 7))
	Parts.wheel(c, Vector2(15, -12), Vector2(9, 7), steer)
	Parts.wheel(c, Vector2(15, 12), Vector2(9, 7), steer)
	# Plow assembly first, so the hull mount overlaps the lift arms.
	c.draw_rect(Rect2(21, -6.5, 5, 2.5), Parts.CHROME)  # lift arms
	c.draw_rect(Rect2(21, 4, 5, 2.5), Parts.CHROME)
	# Scooped blade: wing tips curl gently FORWARD of the center (real plows
	# cup the snow), so the leading edge is concave toward the road ahead.
	var blade := PackedVector2Array([
		Vector2(31.5, -17), Vector2(29.8, -10), Vector2(29, -3),
		Vector2(29, 3), Vector2(29.8, 10), Vector2(31.5, 17),
		Vector2(27.5, 15), Vector2(25.5, 9), Vector2(24.8, 3),
		Vector2(24.8, -3), Vector2(25.5, -9), Vector2(27.5, -15),
	])
	c.draw_colored_polygon(blade, accent)
	c.draw_polyline(PackedVector2Array([  # cutting edge hugs the scoop
		Vector2(30.5, -13), Vector2(29.6, -6), Vector2(29.4, 0),
		Vector2(29.6, 6), Vector2(30.5, 13)]), Parts.TIRE, 1.8)
	c.draw_polyline(PackedVector2Array([  # blade rib
		Vector2(28.8, -11), Vector2(28, -5), Vector2(27.8, 0),
		Vector2(28, 5), Vector2(28.8, 11)]), accent.darkened(0.3), 1.2)
	c.draw_polyline(blade + PackedVector2Array([blade[0]]), Parts.OUTLINE, 1.5)
	var hull := Parts.hull(23, 14, 4, 3)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-23, -11, 17, 22), Color(0.15, 0.15, 0.18))  # open bed
	c.draw_line(Vector2(-19, -11), Vector2(-19, 11), primary.darkened(0.35), 1.5)  # bed ribs
	c.draw_line(Vector2(-13, -11), Vector2(-13, 11), primary.darkened(0.35), 1.5)
	c.draw_rect(Rect2(-6, -12, 4, 24), primary.darkened(0.3))      # cab back wall
	c.draw_rect(Rect2(6, -11, 5, 22), Parts.GLASS)                 # windshield band
	c.draw_rect(Rect2(-2, -10, 8, 20), primary.darkened(0.15))     # cab roof
	c.draw_circle(Vector2(2, 0), 2.2, Color(0.2, 0.14, 0.08))      # beacon base
	c.draw_circle(Vector2(2, 0), 1.6, Parts.NOSE_ACCENT)           # amber beacon
	c.draw_line(Vector2(11, -9), Vector2(20, -9), primary.darkened(0.25), 1.2)  # hood seams
	c.draw_line(Vector2(11, 9), Vector2(20, 9), primary.darkened(0.25), 1.2)
	Parts.headlights(c, 23, 14)
	Parts.outline(c, hull)
