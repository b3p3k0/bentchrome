extends Node2D
## Paint-only stadium set pieces — non-colliding by design, same philosophy as
## street_deco/dock_deco: AI feelers never see paint. `kind` picks the piece:
##   seating: a terraced grandstand band — concrete base, tiered bench rows
##            with seat ticks (weathered, mostly empty; a few missing), stair
##            aisles between sections, a guard rail on the field side, and a
##            ramp-style light/shade grade (the grandstand IS a driveable
##            slope — this deco paints the surface_paint=false Ramp beneath).
##            Rows run along local x; local +y FACES THE FIELD (the low end) —
##            rotate the node so the crowd looks at the action. size.x = run
##            length, size.y = band depth.
##   tunnel:  a locker-room / maintenance maw cut into the boundary wall —
##            darkening throat, concrete frame, striped apron. Local +y is
##            the OPENING direction; author the node on the wall's inner
##            face, after the Boundary in the tree so the maw paints over it.
## Bands are driveable paint like any rooftop: cars roll straight over the
## seats — the deco is the depth read, the Ramp/FloorZones own the floors.

const CONCRETE := Color(0.3, 0.3, 0.34)
const CONCRETE_DARK := Color(0.24, 0.24, 0.28)
const ROW_FACE := Color(0.36, 0.36, 0.4)     # riser between tiers
const SEAT_A := Color(0.5, 0.2, 0.16)        # weathered derby red
const SEAT_B := Color(0.55, 0.42, 0.14)      # faded caution gold
const SEAT_GONE := Color(0.16, 0.16, 0.19)   # ripped-out seat socket
const AISLE := Color(0.42, 0.42, 0.46)
const AISLE_TREAD := Color(0.3, 0.3, 0.34)
const RAIL := Color(0.55, 0.55, 0.62)

const ROW_DEPTH := 44.0     # one tier of seats, front lip to front lip
const SEAT_W := 18.0        # seat tick width
const SEAT_GAP := 6.0       # gap between seat ticks
const AISLE_EVERY := 420.0  # stair aisle cadence along the run
const AISLE_W := 40.0
const RAIL_D := 8.0         # field-side guard rail depth

@export var kind: StringName = &"seating"
@export var size := Vector2(1746, 448)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	match kind:
		&"tunnel":
			_draw_tunnel()
		_:
			_draw_seating()

func _draw_seating() -> void:
	var half := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))  # stable per placement
	draw_rect(Rect2(-half, size), CONCRETE)
	# Stair aisles split the run into sections; seats fill between them.
	var aisles := maxi(int(size.x / AISLE_EVERY), 1)
	var aisle_xs: Array[float] = []
	for i in range(1, aisles + 1):
		aisle_xs.append(-half.x + size.x * float(i) / float(aisles + 1))
	# Tiers climb AWAY from the field (+y front row, -y nosebleeds).
	var rows := int((size.y - RAIL_D - 8.0) / ROW_DEPTH)
	for r in rows:
		var row_y := half.y - RAIL_D - float(r + 1) * ROW_DEPTH
		# Riser face (the step the row above sits on), then the bench slab.
		draw_rect(Rect2(Vector2(-half.x, row_y), Vector2(size.x, 6.0)), ROW_FACE)
		draw_rect(Rect2(Vector2(-half.x, row_y + 6.0), Vector2(size.x, ROW_DEPTH - 6.0)),
			CONCRETE_DARK if r % 2 == 0 else CONCRETE)
		# Seat ticks across the row, skipping the aisles; seeded wear.
		var x := -half.x + SEAT_GAP
		while x + SEAT_W < half.x:
			var in_aisle := false
			for ax in aisle_xs:
				if absf(x + SEAT_W * 0.5 - ax) < AISLE_W * 0.5 + SEAT_GAP:
					in_aisle = true
					break
			if not in_aisle:
				var roll := rng.randf()
				var seat := SEAT_A if (int(x / SEAT_W) + r) % 2 == 0 else SEAT_B
				if roll < 0.08:
					seat = SEAT_GONE  # ripped out for the scrap yards
				elif roll < 0.2:
					seat = seat.darkened(0.35)  # grime
				draw_rect(Rect2(Vector2(x, row_y + 12.0), Vector2(SEAT_W, ROW_DEPTH - 20.0)), seat)
			x += SEAT_W + SEAT_GAP
	# Stair aisles poured over the tiers, treads every few steps.
	for ax in aisle_xs:
		draw_rect(Rect2(Vector2(ax - AISLE_W * 0.5, -half.y), Vector2(AISLE_W, size.y - RAIL_D)), AISLE)
		var ty := -half.y + 10.0
		while ty < half.y - RAIL_D:
			draw_rect(Rect2(Vector2(ax - AISLE_W * 0.5 + 3.0, ty), Vector2(AISLE_W - 6.0, 3.0)), AISLE_TREAD)
			ty += 16.0
	# The grade read: light at the top row, shade at the field — the same
	# high-end-lit convention as ramp.gd, because this band IS that ramp.
	var bands := 6
	var band_h := size.y / bands
	for i in bands:
		var bt := float(i) / float(bands - 1)  # 0 = high end (-y), 1 = field
		var band := Rect2(Vector2(-half.x, -half.y + i * band_h), Vector2(size.x, band_h + 1.0))
		draw_rect(band, Color(1.0, 1.0, 1.0, 0.1 * (1.0 - bt)))
		draw_rect(band, Color(0.0, 0.0, 0.0, 0.12 * bt))
	# Field-side guard rail: the front row's last defense against the derby.
	draw_rect(Rect2(Vector2(-half.x, half.y - RAIL_D), Vector2(size.x, RAIL_D)), RAIL)
	draw_rect(Rect2(-half, size), CONCRETE_DARK, false, 2.0)

## The corner maw: throat darkens away from the opening (+y), concrete frame
## and lintel, hazard-striped apron spilling onto the pocket floor.
func _draw_tunnel() -> void:
	var hw := size.x * 0.5
	var depth := size.y
	var steps := 5
	for i in steps:
		var a := lerpf(1.0, 0.55, float(i) / float(steps - 1))  # deepest = darkest
		draw_rect(Rect2(Vector2(-hw, -depth + depth * float(i) / steps),
			Vector2(size.x, depth / steps + 1.0)), Color(0.04, 0.04, 0.06, a))
	draw_rect(Rect2(Vector2(-hw - 10.0, -depth), Vector2(10.0, depth + 6.0)), CONCRETE)
	draw_rect(Rect2(Vector2(hw, -depth), Vector2(10.0, depth + 6.0)), CONCRETE)
	draw_rect(Rect2(Vector2(-hw - 10.0, -depth - 10.0), Vector2(size.x + 20.0, 10.0)), RAIL)
	draw_rect(Rect2(Vector2(-hw, 0.0), Vector2(size.x, 44.0)), AISLE)
	var ticks := int(size.x / 24.0)
	for i in ticks:
		if i % 2 == 0:
			draw_rect(Rect2(Vector2(-hw + 4.0 + float(i) * 24.0, 6.0), Vector2(16.0, 10.0)), SEAT_B)
