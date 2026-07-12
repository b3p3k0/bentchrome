extends RefCounted
## Razorback: the Humvee — slab hood, steep glass band, spare on the roof.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	# radius 21.5/22: kandykane held at the legacy 22 — the corner-escape
	# budget (mass-7 truck, 80px pocket) blows at 23; razorback slots under.
	"half_len": 28.0, "half_wid": 17.0, "radius": 21.5,
	"skid_points": [Vector2(-17, -14), Vector2(-17, 14)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, _accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-17, -16), Vector2(11, 5))
	Parts.wheel(c, Vector2(-17, 16), Vector2(11, 5))
	Parts.wheel(c, Vector2(17, -16), Vector2(11, 5))
	Parts.wheel(c, Vector2(17, 16), Vector2(11, 5))
	var hull := Parts.hull(28, 14, 3, 3)
	c.draw_colored_polygon(hull, primary)
	c.draw_colored_polygon(PackedVector2Array([                    # sloped back
		Vector2(-28, -13), Vector2(-21, -13), Vector2(-21, 13), Vector2(-28, 13),
	]), primary.darkened(0.35))
	c.draw_rect(Rect2(-21, -13, 27, 26), primary.darkened(0.15))   # flat roof slab
	c.draw_rect(Rect2(6, -13, 4, 26), Parts.GLASS)                 # steep windscreen
	c.draw_line(Vector2(10, -14), Vector2(10, 14), Parts.OUTLINE, 1.5)  # hood seam
	c.draw_circle(Vector2(-13, 0), 5.0, Parts.TIRE)                # roof spare
	c.draw_circle(Vector2(-13, 0), 1.8, primary.darkened(0.15))
	c.draw_rect(Rect2(26, -8, 3, 16), Parts.TIRE)                  # brush bumper
	Parts.headlights(c, 26, 14)
	Parts.outline(c, hull)
