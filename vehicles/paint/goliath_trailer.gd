extends RefCounted
## Goliath's trailer: a corrugated armored box on a rear bogie. The front
## quarter wears the hazard diamond — that's the kingpin end, the weak spot —
## and two sandbag rings anchor the LIVE trailer turrets (paint-local
## (10, 0) and (-26, 0); the Turret nodes draw their own barrels on top).
## NOT a Vehicle: radius here is cosmetic-only (shadow and metrics sanity) —
## collision is the authored rects on its sub-bodies.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 55.0, "half_wid": 18.0, "radius": 30.0,
	"skid_points": [Vector2(-42, -15), Vector2(-42, 15)],
	"steer_wheels": [],
}

static func paint(c: CanvasItem, primary: Color, _accent: Color, _steer: float, _phase: bool) -> void:
	for x in [-38.0, -46.0]:
		Parts.wheel(c, Vector2(x, -15), Vector2(12, 6))
		Parts.wheel(c, Vector2(x, 15), Vector2(12, 6))
	c.draw_rect(Rect2(-55, -18, 110, 36), primary)
	var seams := 10
	for i in range(1, seams):
		var x := -55.0 + 110.0 * float(i) / float(seams)
		c.draw_line(Vector2(x, -16), Vector2(x, 16), primary.darkened(0.2), 1.0)
	c.draw_rect(Rect2(-55, -18, 110, 3), primary.darkened(0.3))    # side rails
	c.draw_rect(Rect2(-55, 15, 110, 3), primary.darkened(0.3))
	c.draw_rect(Rect2(-55, -17, 4, 34), primary.darkened(0.35))    # rear door frame
	c.draw_line(Vector2(-53, -15), Vector2(-53, 15), Parts.OUTLINE, 1.0)
	c.draw_rect(Rect2(27, -18, 28, 36), primary.lightened(0.12))   # kingpin quarter
	c.draw_colored_polygon(PackedVector2Array([                    # the hazard tell
		Vector2(35, 0), Vector2(41, -6), Vector2(47, 0), Vector2(41, 6),
	]), Parts.NOSE_ACCENT)
	c.draw_circle(Vector2(48, 0), 4.0, Parts.TIRE)                 # kingpin plate
	c.draw_rect(Rect2(30, -16, 4, 5), Parts.CHROME.darkened(0.25))  # landing gear
	c.draw_rect(Rect2(30, 11, 4, 5), Parts.CHROME.darkened(0.25))
	for at in [Vector2(10, 0), Vector2(-26, 0)]:                   # turret mounts
		c.draw_circle(at, 7.5, Color(0.5, 0.44, 0.3))
		c.draw_circle(at, 5.0, primary.darkened(0.45))
	c.draw_rect(Rect2(-55, -18, 110, 36), Parts.OUTLINE, false, 1.5)
