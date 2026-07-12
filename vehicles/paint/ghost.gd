extends RefCounted
## Ghost: low, long, tapered — a sheet of white with a sliver of canopy.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 26.0, "half_wid": 11.0, "radius": 17.0,
	"skid_points": [Vector2(-20, -8), Vector2(-20, 8)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	var hull := Parts.hull(26, 11, 9, 4)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-26, -9, 4, 18), Parts.TIRE)                    # tail vent
	c.draw_line(Vector2(10, 0), Vector2(25, 0), accent, 2.0)          # hood pinstripe
	c.draw_colored_polygon(PackedVector2Array([                        # swept canopy
		Vector2(-14, -7), Vector2(4, -6), Vector2(9, 0), Vector2(4, 6), Vector2(-14, 7),
	]), Parts.GLASS)
	c.draw_rect(Rect2(-13, -6, 3, 12), primary.darkened(0.25))         # roll hoop
	Parts.headlights(c, 26, 11)
	Parts.outline(c, hull)
