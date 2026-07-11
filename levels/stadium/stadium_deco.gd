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
##   chamfer: the 45° corner cut capping the bleacher ends — a raised
##            black/yellow caution band with a lit top lip and a drop shadow
##            spilling toward the track. Local +y is the TRACK side; ride it
##            as a child of the corner's StaticBody2D so paint = collision.
##   floodlight: a corner light tower — mast, crossbar, four lamps with glow
##            halos, and a translucent light pool washing toward the ARENA
##            CENTER (computed from position — no authored rotation), swaying
##            slowly on a seeded phase so the four towers never sync.
##   jumbotron: the big screen on the rim — dark bezel, scanlines, pixel
##            noise, and a scrolling marquee that WATCHES THE FIGHT (duck-
##            typed, null-safe, 1 Hz): GOLIATH -> RAMPAGE at the phase flip,
##            NEW KING when the throne empties.
##   confetti: wind-caught confetti/trash flecks drifting across the field in
##            lazy tumbling gusts — the crowd never came, the litter stayed.
##            size = emission extents; pre-filled so the field is never bare.
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

const LAMP_WARM := Color(1.0, 0.95, 0.75)
const POOL_A := 0.07           # light-pool wash alpha
const SCREEN_AMBER := Color(1.0, 0.8, 0.25)
const CONFETTI_COLORS := [Color(0.85, 0.25, 0.2), Color(0.95, 0.8, 0.2),
	Color(0.25, 0.65, 0.7), Color(0.9, 0.88, 0.84)]

@export var kind: StringName = &"seating"
@export var size := Vector2(1746, 448)

var _t := 0.0
var _phase_seed := 0.0
var _poll_t := 0.0
var _marquee := "GOLIATH"

func _ready() -> void:
	_phase_seed = float(hash(Vector2i(global_position)) % 628) / 100.0
	if kind == &"confetti":
		_build_confetti()
	set_process(kind == &"floodlight" or kind == &"jumbotron")
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if kind == &"jumbotron":
		_poll_t -= delta
		if _poll_t <= 0.0:
			_poll_t = 1.0
			_poll_fight()
	queue_redraw()

## The screen watches the fight — duck-typed and null-safe, so the deco can
## exist on any level (or in a bare test tree) without ever erroring.
func _poll_fight() -> void:
	var boss := get_tree().get_first_node_in_group(&"enemies")
	if boss == null or not is_instance_valid(boss):
		_marquee = "NEW KING"
		return
	var bc := boss.get_node_or_null(^"BossController")
	var ph: Variant = bc.get("phase") if bc != null else null
	_marquee = "RAMPAGE" if (ph is int and int(ph) >= 2) else "GOLIATH"

func _draw() -> void:
	match kind:
		&"tunnel":
			_draw_tunnel()
		&"chamfer":
			_draw_chamfer()
		&"floodlight":
			_draw_floodlight()
		&"jumbotron":
			_draw_jumbotron()
		&"confetti":
			pass  # particles own it
		_:
			_draw_seating()

## The night-game wash: a swaying trapezoid of light aimed at the arena
## center, a mast with four lamps behind it.
func _draw_floodlight() -> void:
	var aim := (Vector2.ZERO - global_position).angle() - global_rotation
	var sway := sin(_t * 0.5 + _phase_seed) * 0.1
	var f := Vector2.RIGHT.rotated(aim + sway)
	var n := f.orthogonal()
	var reach := 760.0 + sin(_t * 0.33 + _phase_seed) * 60.0
	draw_colored_polygon(PackedVector2Array([
		f * 42.0 + n * 34.0, f * 42.0 - n * 34.0,
		f * reach - n * 170.0, f * reach + n * 170.0,
	]), Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, POOL_A))
	draw_colored_polygon(PackedVector2Array([
		f * 42.0 + n * 22.0, f * 42.0 - n * 22.0,
		f * (reach * 0.55) - n * 80.0, f * (reach * 0.55) + n * 80.0,
	]), Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, POOL_A * 0.8))
	# the tower itself: pad, mast, crossbar, four lamps + glow
	draw_circle(Vector2(3, 5), 20.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_circle(Vector2.ZERO, 16.0, CONCRETE_DARK)
	draw_circle(Vector2.ZERO, 9.0, RAIL)
	draw_line(f * 20.0 + n * 30.0, f * 20.0 - n * 30.0, CONCRETE_DARK, 7.0)
	for i in 4:
		var at := f * 24.0 + n * (-22.5 + 15.0 * float(i))
		draw_circle(at, 8.0, Color(LAMP_WARM.r, LAMP_WARM.g, LAMP_WARM.b, 0.22))
		draw_circle(at, 4.0, LAMP_WARM)

## The big screen: bezel + legs, scanlines, pixel noise, and the marquee
## scrolling right-to-left. The bezel frame is drawn LAST and wide, so the
## text clips against it instead of spilling into the world.
func _draw_jumbotron() -> void:
	var half := size * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2(-half.x * 0.7, half.y), Vector2(14, 26)), CONCRETE_DARK)
	draw_rect(Rect2(Vector2(half.x * 0.7 - 14.0, half.y), Vector2(14, 26)), CONCRETE_DARK)
	draw_rect(Rect2(Vector2(-half.x + 10, -half.y + 10), size), Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(Rect2(-half, size), Color(0.05, 0.05, 0.07))  # screen base
	# marquee: two copies for a seamless wrap
	var text := "%s   %s   " % [_marquee, _marquee]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var scroll := fmod(_t * 110.0, tw * 0.5)
	var flicker := 0.75 + 0.25 * sin(_t * 21.0 + sin(_t * 3.7) * 4.0)
	var ink := Color(SCREEN_AMBER.r, SCREEN_AMBER.g, SCREEN_AMBER.b, flicker)
	for rep in 2:
		draw_string(font, Vector2(-scroll + tw * 0.5 * float(rep) - half.x + 16.0, 22.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, ink)
	for i in int(size.y / 6.0):  # scanlines
		draw_rect(Rect2(Vector2(-half.x, -half.y + float(i) * 6.0), Vector2(size.x, 2.0)),
			Color(0.0, 0.0, 0.0, 0.28))
	var rng := RandomNumberGenerator.new()  # pixel noise, reseeded per frame
	rng.seed = int(_t * 30.0)
	for i in 7:
		draw_rect(Rect2(Vector2(rng.randf_range(-half.x, half.x - 20.0),
			rng.randf_range(-half.y, half.y - 8.0)), Vector2(20, 8)),
			Color(1.0, 1.0, 1.0, 0.05))
	# the wide bezel frame clips the marquee overflow
	var frame := Color(0.14, 0.14, 0.17)
	draw_rect(Rect2(Vector2(-half.x - 400.0, -half.y - 8.0), Vector2(400.0, size.y + 16.0)), frame)
	draw_rect(Rect2(Vector2(half.x, -half.y - 8.0), Vector2(400.0, size.y + 16.0)), frame)
	draw_rect(Rect2(Vector2(-half.x - 8.0, -half.y - 8.0), Vector2(size.x + 16.0, 8.0)), frame)
	draw_rect(Rect2(Vector2(-half.x - 8.0, half.y), Vector2(size.x + 16.0, 8.0)), frame)
	draw_rect(Rect2(Vector2(-half.x - 8.0, -half.y - 8.0), Vector2(size.x + 16.0, size.y + 16.0)),
		Color(0.3, 0.3, 0.34), false, 3.0)

## Wind-caught litter, always moving: sparse tumbling flecks in team colors
## gone grimy, pre-filled so the field never starts bare.
func _build_confetti() -> void:
	var flecks := CPUParticles2D.new()
	flecks.amount = 44
	flecks.lifetime = 7.0
	flecks.preprocess = 7.0
	flecks.local_coords = false
	flecks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flecks.emission_rect_extents = size * 0.5
	flecks.direction = Vector2(1, 0)
	flecks.spread = 180.0
	flecks.initial_velocity_min = 8.0
	flecks.initial_velocity_max = 34.0
	flecks.gravity = Vector2(12.0, 5.0)  # the prevailing gust
	flecks.angle_min = 0.0
	flecks.angle_max = 360.0
	flecks.angular_velocity_min = -140.0
	flecks.angular_velocity_max = 140.0
	flecks.scale_amount_min = 1.4
	flecks.scale_amount_max = 2.6
	var ramp := Gradient.new()
	for i in CONFETTI_COLORS.size():
		var c: Color = CONFETTI_COLORS[i]
		c.a = 0.8
		if i == 0:
			ramp.set_color(0, c)
		elif i == CONFETTI_COLORS.size() - 1:
			ramp.set_color(1, c)
		else:
			ramp.add_point(float(i) / float(CONFETTI_COLORS.size() - 1), c)
	flecks.color_initial_ramp = ramp
	add_child(flecks)

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

## The corner cut: caution stripes across the 45° band, a lit lip on the rim
## side, a drop shadow toward the track — reads raised, deflects the eye the
## same way the collision deflects the car.
func _draw_chamfer() -> void:
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-half.x, half.y), Vector2(size.x, 26.0)),
		Color(0.0, 0.0, 0.0, 0.3))  # the drop shadow spills toward the track
	var stripe := 36.0
	var i := 0
	var x0 := -half.x
	while x0 < half.x:
		var w := minf(stripe, half.x - x0)
		draw_rect(Rect2(Vector2(x0, -half.y), Vector2(w, size.y)),
			SEAT_B.lightened(0.25) if i % 2 == 0 else Color(0.12, 0.12, 0.14))
		x0 += stripe
		i += 1
	draw_rect(Rect2(Vector2(-half.x, -half.y - 6.0), Vector2(size.x, 6.0)),
		Color(1.0, 1.0, 1.0, 0.22))  # lit top lip (rim side)
	draw_rect(Rect2(Vector2(-half.x, half.y - 3.0), Vector2(size.x, 3.0)),
		Color(0.0, 0.0, 0.0, 0.35))  # dark base line (track side)
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
