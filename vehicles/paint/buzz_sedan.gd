extends RefCounted
## Buzzard beater: a rust-bucket sedan wearing mismatched panels — primer
## patches, cracked glass, one headlight, and a rope-tied trunk.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 26.0, "half_wid": 14.0, "radius": 19.0,
	"skid_points": [Vector2(-18, -10), Vector2(-18, 10)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-18, -12), Vector2(9, 5))
	Parts.wheel(c, Vector2(-18, 12), Vector2(9, 5))
	Parts.wheel(c, Vector2(17, -12), Vector2(9, 5))
	Parts.wheel(c, Vector2(17, 12), Vector2(9, 5))
	var hull := Parts.hull(26, 14, 5, 4)
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-6, -14, 12, 6), accent.darkened(0.25))      # mismatched door
	c.draw_rect(Rect2(-10, 8, 14, 6), Color(0.42, 0.42, 0.44))     # primer-gray panel
	c.draw_rect(Rect2(8, -11, 5, 22), Parts.GLASS.darkened(0.15))  # windshield band
	c.draw_line(Vector2(9, -8), Vector2(12, 2), Parts.OUTLINE, 1.0)  # the crack
	c.draw_line(Vector2(12, 2), Vector2(10, 7), Parts.OUTLINE, 1.0)
	c.draw_rect(Rect2(-14, -9, 18, 18), primary.darkened(0.25))    # sagging roof
	c.draw_rect(Rect2(19, -6, 6, 12), Parts.TIRE)                  # hood gone — engine
	c.draw_circle(Vector2(22, -2), 1.5, Parts.CHROME)
	c.draw_circle(Vector2(22, 2.5), 1.5, Parts.CHROME)
	c.draw_rect(Rect2(24, 8, 3, 4), Parts.CLOTH)                   # the one headlight
	c.draw_rect(Rect2(-26, -8, 2.5, 5), Parts.LIGHT_RED.darkened(0.35))  # taped taillight
	c.draw_line(Vector2(-24, -4), Vector2(-24, 6), accent.darkened(0.4), 1.2)  # trunk rope
	Parts.outline(c, hull)
