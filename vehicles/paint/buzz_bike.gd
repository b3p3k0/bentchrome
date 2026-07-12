extends RefCounted
## Buzzard scrambler: a dirtbike and its raider — knobby tires, taped tank,
## bandana instead of a helmet. Cheap, angry, and loud. (Chase mode,
## roster-external like lackey: tatty raider kit.)

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 17.0, "half_wid": 7.0, "radius": 11.0,
	"skid_points": [Vector2(-12, 0)],
	"steer_wheels": [Vector2(12, 0)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	Parts.wheel(c, Vector2(-12, 0), Vector2(9, 6))                 # knobby rear
	Parts.wheel(c, Vector2(12, 0), Vector2(8, 5), steer)
	c.draw_circle(Vector2(-12, -3.5), 1.2, Parts.TIRE)             # tread lugs
	c.draw_circle(Vector2(-12, 3.5), 1.2, Parts.TIRE)
	c.draw_line(Vector2(-15, 3), Vector2(-3, 2.5), Color(0.5, 0.38, 0.25), 2.0)  # rusty pipe
	c.draw_colored_polygon(PackedVector2Array([                    # frame + tank
		Vector2(-9, -2.5), Vector2(3, -3.0), Vector2(8, -2.0),
		Vector2(8, 2.0), Vector2(3, 3.0), Vector2(-9, 2.5),
	]), primary)
	c.draw_rect(Rect2(0, -3.0, 4, 6), accent.darkened(0.3))        # taped tank patch
	c.draw_line(Vector2(8, -6), Vector2(8, 6), Parts.OUTLINE, 2.0)  # tall bars
	c.draw_rect(Rect2(11, -4.5, 2, 9), accent)                     # high front fender
	c.draw_rect(Rect2(-8, -4, 7, 8), primary.darkened(0.4))        # hunched rider
	c.draw_circle(Vector2(-2, 0), 3.0, Color(0.75, 0.62, 0.5))     # bare head
	c.draw_rect(Rect2(-4, -3.2, 2.4, 6.4), accent.darkened(0.15))  # bandana
