extends RefCounted
## Cricket: dirt-track midget — wheels way outside the tub, huge rear wing.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 20.0, "half_wid": 16.0, "radius": 15.0,
	"skid_points": [Vector2(-13, -13), Vector2(-13, 13)],
	"steer_wheels": [Vector2(13, -12), Vector2(13, 12)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-13, -13), Vector2(10, 7))
	Parts.wheel(c, Vector2(-13, 13), Vector2(10, 7))
	Parts.wheel(c, Vector2(13, -12), Vector2(8, 6), steer)
	Parts.wheel(c, Vector2(13, 12), Vector2(8, 6), steer)
	c.draw_rect(Rect2(-20, -15, 4, 30), accent)                    # rear wing
	c.draw_rect(Rect2(-21, -15, 6, 3), Parts.OUTLINE)              # wing endplates
	c.draw_rect(Rect2(-21, 12, 6, 3), Parts.OUTLINE)
	var tub := PackedVector2Array([                                # narrow tub
		Vector2(-15, -7), Vector2(8, -6), Vector2(18, -3), Vector2(20, 0),
		Vector2(18, 3), Vector2(8, 6), Vector2(-15, 7),
	])
	c.draw_colored_polygon(tub, primary)
	c.draw_rect(Rect2(-14, -5, 6, 10), primary.darkened(0.35))     # engine block
	c.draw_circle(Vector2(-2, 0), 3.5, accent)                     # driver helmet
	c.draw_circle(Vector2(9, 0), 3.0, Parts.CLOTH)                 # nose roundel
	Parts.outline(c, tub)
