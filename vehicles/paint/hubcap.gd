extends RefCounted
## Hubcap: there is no car — Rex Goodyear suspended between two giant
## parallel treads, arms locked out to the hubs, a machine gun bolted to
## each side of the deck rig. Wider than long, the only one in the fleet.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 15.0, "half_wid": 21.0, "radius": 14.0,
	"skid_points": [Vector2(0, -16), Vector2(0, 16)],
	"steer_wheels": [],
	"mg_points": [Vector2(9, -6), Vector2(9, 6)],
}

const SKIN := Color(0.72, 0.55, 0.42)
const DENIM := Color(0.44, 0.3, 0.78)  # Rex's purple jeans
const RIG := Color(0.4, 0.42, 0.46)

static func paint(c: CanvasItem, primary: Color, accent: Color, _steer: float, _phase: bool) -> void:
	for side in [-1.0, 1.0]:                                       # the two giant treads
		var y: float = side * 17.0
		c.draw_rect(Rect2(-15, y - 4, 30, 8), Parts.TIRE)
		for i in range(6):                                         # tread lugs
			var x := -13.0 + 5.0 * float(i)
			c.draw_rect(Rect2(x, y - 4, 2, 8), Color(0.16, 0.16, 0.19))
		c.draw_rect(Rect2(-15, y - 4, 30, 8), Parts.OUTLINE, false, 1.2)  # tread rim
		c.draw_circle(Vector2(0, y), 3.2, primary)                 # painted hub cap
		c.draw_circle(Vector2(0, y), 1.4, Parts.CHROME)
	c.draw_rect(Rect2(-6, -13, 12, 26), RIG)                       # deck rig spanning the hubs
	c.draw_rect(Rect2(-6, -13, 12, 2), RIG.darkened(0.3))
	c.draw_rect(Rect2(-6, 11, 12, 2), RIG.darkened(0.3))
	c.draw_line(Vector2(0, -13), Vector2(0, -6), Parts.CHROME, 2.0)  # hub struts
	c.draw_line(Vector2(0, 13), Vector2(0, 6), Parts.CHROME, 2.0)
	for gy in [-6.0, 6.0]:                                         # the twin MGs, forward
		c.draw_rect(Rect2(4, gy - 1.5, 6, 3), primary.darkened(0.25))  # receiver
		c.draw_rect(Rect2(10, gy - 0.8, 5, 1.6), Parts.TIRE)       # barrel
		c.draw_circle(Vector2(15, gy), 0.9, Parts.NOSE_ACCENT)     # muzzle bead
	c.draw_rect(Rect2(-6, -5, 4, 10), DENIM)                       # Rex: legs trail behind
	c.draw_rect(Rect2(-2, -6, 6, 12), SKIN.darkened(0.15))         # torso + spread arms
	c.draw_line(Vector2(1, -6), Vector2(1, -13), SKIN, 2.2)        # arm to the left hub
	c.draw_line(Vector2(1, 6), Vector2(1, 13), SKIN, 2.2)          # arm to the right hub
	c.draw_circle(Vector2(2, 0), 3.0, SKIN)                        # the man himself
	c.draw_arc(Vector2(2, 0), 3.0, PI * 0.75, PI * 1.25, 6, Parts.OUTLINE, 1.0)  # scowl shade
	c.draw_rect(Rect2(4.4, -1.2, 1.4, 2.4), accent)                # neon visor — pulse green
