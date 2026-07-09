extends Node2D
## Paint-only dockyard set pieces — non-colliding by design, same philosophy
## as street_deco: AI feelers never see paint. `kind` picks the piece:
##   ship_hull:    the docked container ship — rusted hull rim, steel deck
##                 plates, tapered bow at +x, waterline foam. The deck's
##                 driveable surface is a FloorZone; rails and cargo are
##                 separate statics.
##   crane:        a quay gantry crane — portal legs, long boom out +x, cab,
##                 spreader hanging off a cable, long harbor shadow.
##   pier_surface: a concrete pier finger — expansion seams, edge fenders,
##                 tie cleats. Attach the -y end to the quay: foam is drawn
##                 on the other three edges only.

const HULL := Color(0.34, 0.21, 0.18)       # rusted plating
const HULL_DARK := Color(0.22, 0.13, 0.11)
const DECK := Color(0.42, 0.44, 0.48)       # painted steel
const DECK_LINE := Color(0.32, 0.34, 0.38)
const HATCH := Color(0.37, 0.39, 0.43)
const FOAM := Color(0.75, 0.85, 0.9, 0.5)
const SHADOW := Color(0.0, 0.0, 0.0, 0.3)
const CONCRETE := Color(0.52, 0.52, 0.55)
const CONCRETE_SEAM := Color(0.4, 0.4, 0.44)
const FENDER := Color(0.12, 0.12, 0.14)
const CLEAT := Color(0.2, 0.21, 0.24)
const CRANE_STEEL := Color(0.72, 0.5, 0.14)  # harbor-gantry yellow
const CRANE_DARK := Color(0.45, 0.31, 0.09)
const CABLE := Color(0.18, 0.18, 0.2)

@export var kind: StringName = &"pier_surface"
@export var size := Vector2(512, 256)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	match kind:
		&"ship_hull":
			_draw_ship()
		&"crane":
			_draw_crane()
		_:
			_draw_pier()

func _draw_ship() -> void:
	var half := size * 0.5
	var bow := size.x * 0.16  # tapered nose eats the +x end of the rect
	var body_r := half.x - bow
	# Waterline foam hugs the hull silhouette.
	var outline := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(body_r, -half.y),
		Vector2(half.x, 0.0), Vector2(body_r, half.y), Vector2(-half.x, half.y),
	])
	var foam := outline.duplicate()
	foam.append(outline[0])
	draw_polyline(foam, FOAM, 10.0)
	draw_colored_polygon(outline, HULL)
	# Deck plate inset, same silhouette pulled inward.
	var inset := 14.0
	var deck := PackedVector2Array([
		Vector2(-half.x + inset, -half.y + inset), Vector2(body_r - inset * 0.4, -half.y + inset),
		Vector2(half.x - inset * 1.8, 0.0), Vector2(body_r - inset * 0.4, half.y - inset),
		Vector2(-half.x + inset, half.y - inset),
	])
	draw_colored_polygon(deck, DECK)
	# Transverse deck seams + hatch coamings down the spine.
	var seams := int(size.x / 130.0) + 2
	for i in range(1, seams):
		var x := -half.x + inset + (size.x - bow - inset * 2.0) * i / seams
		draw_line(Vector2(x, -half.y + inset + 3), Vector2(x, half.y - inset - 3), DECK_LINE, 2.0)
	var hatches := int(size.x / 260.0) + 1
	for i in hatches:
		var hx := -half.x + size.x * 0.16 + (size.x * 0.52) * i / maxf(hatches - 1.0, 1.0)
		draw_rect(Rect2(hx - 34, -size.y * 0.16, 68, size.y * 0.32), HATCH)
		draw_rect(Rect2(hx - 34, -size.y * 0.16, 68, size.y * 0.32), DECK_LINE, false, 2.0)
	# Stern superstructure block: the bridge lives at -x.
	draw_rect(Rect2(-half.x + inset + 4, -half.y * 0.55, 52, size.y * 0.55), HULL_DARK)
	draw_rect(Rect2(-half.x + inset + 10, -half.y * 0.38, 40, size.y * 0.28), DECK_LINE)

func _draw_crane() -> void:
	var half := size * 0.5
	var boom_len := size.x * 0.72
	# Long harbor shadow under everything.
	draw_rect(Rect2(Vector2(-half.x + 10, -half.y * 0.3 + 12), Vector2(size.x * 0.9, size.y * 0.5)), SHADOW)
	# Portal legs (top-down: two pads bridged by the portal beam).
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(-half.x, s * half.y * 0.6 - 12), Vector2(36, 24)), CRANE_DARK)
		draw_rect(Rect2(Vector2(-half.x + 4, s * half.y * 0.6 - 8), Vector2(28, 16)), CRANE_STEEL)
	draw_rect(Rect2(Vector2(-half.x + 8, -half.y * 0.6), Vector2(20, size.y * 0.6 * 2.0)), CRANE_STEEL)
	# Boom reaching +x over the water, with lattice ticks.
	draw_rect(Rect2(Vector2(-half.x + 24, -9), Vector2(boom_len, 18)), CRANE_STEEL)
	draw_rect(Rect2(Vector2(-half.x + 24, -9), Vector2(boom_len, 18)), CRANE_DARK, false, 2.0)
	var ticks := int(boom_len / 34.0)
	for i in range(1, ticks):
		var x := -half.x + 24 + boom_len * i / ticks
		draw_line(Vector2(x, -9), Vector2(x - 12, 9), CRANE_DARK, 1.5)
	# Cab near the legs; cable + spreader far out on the boom.
	draw_rect(Rect2(Vector2(-half.x + 34, -22), Vector2(26, 20)), CRANE_DARK)
	draw_rect(Rect2(Vector2(-half.x + 38, -18), Vector2(18, 12)), Color(0.6, 0.75, 0.8))
	var hook_x := -half.x + 24 + boom_len * 0.82
	draw_line(Vector2(hook_x, 0), Vector2(hook_x + 6, 26), CABLE, 2.0)
	draw_rect(Rect2(Vector2(hook_x - 16, 26), Vector2(44, 12)), FENDER)
	draw_rect(Rect2(Vector2(hook_x - 16, 26), Vector2(44, 12)), CRANE_STEEL, false, 1.5)

func _draw_pier() -> void:
	var half := size * 0.5
	var tall := size.y > size.x  # fingers usually run +y into the water
	# Foam on the three water edges (the -y end attaches to the quay).
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), FOAM, 8.0)
	draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), FOAM, 8.0)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, half.y), FOAM, 8.0)
	draw_rect(Rect2(-half, size), CONCRETE)
	# Expansion seams across the run.
	var run := size.y if tall else size.x
	var seams := maxi(int(run / 96.0), 2)
	for i in range(1, seams):
		var tt := -run * 0.5 + run * i / seams
		if tall:
			draw_line(Vector2(-half.x + 2, tt), Vector2(half.x - 2, tt), CONCRETE_SEAM, 2.0)
		else:
			draw_line(Vector2(tt, -half.y + 2), Vector2(tt, half.y - 2), CONCRETE_SEAM, 2.0)
	# Edge fenders: dark tire stubs along the long water edges.
	var stubs := maxi(int(run / 72.0), 2)
	for i in stubs:
		var tt := -run * 0.5 + run * (i + 0.5) / stubs
		if tall:
			draw_rect(Rect2(-half.x - 3, tt - 7, 6, 14), FENDER)
			draw_rect(Rect2(half.x - 3, tt - 7, 6, 14), FENDER)
		else:
			draw_rect(Rect2(tt - 7, -half.y - 3, 14, 6), FENDER)
			draw_rect(Rect2(tt - 7, half.y - 3, 14, 6), FENDER)
	# Tie cleats down the centerline.
	for i in range(1, seams):
		var tt := -run * 0.5 + run * (i - 0.5) / seams
		var at := Vector2(0, tt) if tall else Vector2(tt, 0)
		draw_circle(at, 4.0, CLEAT)
		draw_circle(at, 2.0, CONCRETE_SEAM)
	draw_rect(Rect2(-half, size), CONCRETE_SEAM, false, 2.5)
