extends RefCounted
## Lackey: the eight-wheel Stryker — angled hull, deck hatches, breach cannon.

const Parts := preload("res://vehicles/paint/parts.gd")

const STYLE := {
	"half_len": 32.0, "half_wid": 20.0, "radius": 24.0,  # ×1.5 body_scale in the depot
	"skid_points": [Vector2(-24, -18), Vector2(-24, 18)],
	"steer_wheels": [Vector2(24, -18), Vector2(24, 18)],
}

static func paint(c: CanvasItem, primary: Color, accent: Color, steer: float, _phase: bool) -> void:
	for x in [-24.0, -8.0, 8.0, 24.0]:
		var pivot := steer if x == 24.0 else 0.0
		Parts.wheel(c, Vector2(x, -18), Vector2(12, 6), pivot)
		Parts.wheel(c, Vector2(x, 18), Vector2(12, 6), pivot)
	var hull := Parts.hull(32, 15, 10, 6)
	c.draw_colored_polygon(hull, primary)
	c.draw_colored_polygon(PackedVector2Array([                    # sloped glacis nose
		Vector2(22, -13), Vector2(32, -5), Vector2(32, 5), Vector2(22, 13),
	]), primary.darkened(0.3))
	c.draw_rect(Rect2(-26, -11, 44, 22), primary.darkened(0.12))   # top deck
	c.draw_line(Vector2(-26, -15), Vector2(20, -15), accent.darkened(0.2), 1.5)  # side skirts
	c.draw_line(Vector2(-26, 15), Vector2(20, 15), accent.darkened(0.2), 1.5)
	c.draw_circle(Vector2(-16, -5), 3.5, primary.darkened(0.4))    # crew hatches
	c.draw_circle(Vector2(-16, 6), 3.5, primary.darkened(0.4))
	# Cannon ring only — the barrel is the LIVE turret (weapons/turret.gd,
	# spawned by Vehicle when stats.turret is set); this is its mount base.
	c.draw_circle(Vector2(2, 0), 5.0, primary.darkened(0.45))
	Parts.outline(c, hull)
