extends RefCounted
## Smoky: pursuit SUV — boxy, white door livery, push bar, flashing light bar.
## "blink" drives the light-bar flip via car_paint's shared BAR_PERIOD clock.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 27.0, "half_wid": 15.0, "radius": 21.0,
	"skid_points": [Vector2(-19, -11), Vector2(-19, 11)],
	"steer_wheels": [],
	"blink": true,
}

static func paint(c: CanvasItem, primary: Color, _accent: Color, _steer: float, phase: bool) -> void:
	var hull := Parts.hull(25, 15, 4, 4)
	c.draw_rect(Rect2(25, -8, 3, 16), Parts.TIRE)                # push bar
	c.draw_colored_polygon(hull, primary)
	c.draw_rect(Rect2(-12, -15, 14, 6), Parts.LIVERY)            # door panels
	c.draw_rect(Rect2(-12, 9, 14, 6), Parts.LIVERY)
	c.draw_rect(Rect2(8, -12, 6, 24), Parts.GLASS)               # windshield band
	c.draw_rect(Rect2(-16, -11, 22, 22), primary.darkened(0.2))  # long roof
	c.draw_rect(Rect2(-14, -9, 4, 18), Parts.GLASS.darkened(0.2))  # rear glass
	var hot := phase
	c.draw_rect(Rect2(0, -7, 5, 6), Parts.LIGHT_RED if hot else Parts.LIGHT_RED.darkened(0.6))
	c.draw_rect(Rect2(0, 1, 5, 6), Parts.LIGHT_BLUE if not hot else Parts.LIGHT_BLUE.darkened(0.6))
	Parts.headlights(c, 25, 15)
	Parts.outline(c, hull)
