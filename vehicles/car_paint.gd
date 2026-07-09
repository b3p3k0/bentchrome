extends Node2D
## Procedural per-car body paint. One style per roster id (fallback &"box" —
## the classic placeholder square) drawn in true-footprint local px; the style
## table also carries the physics-facing metrics (collision radius, skid
## contact points, steering wheels) so visuals and gameplay agree per car.
## The whole fleet renders at FLEET_SCALE while collision radii stay 1:1 —
## hitbox-smaller-than-visual is deliberate (near-misses read as skill, and
## the corner-escape budgets are radius-coupled). Don't "fix" the split.
## NEVER references Vehicle (projectile-side circular-load rule): the parent
## is duck-typed where needed.

const FLEET_SCALE := 1.25  # visual size of every car; collision radii stay 1:1

const OUTLINE := Color(0.08, 0.08, 0.1)
const NOSE_ACCENT := Color(1.0, 0.85, 0.2)  # dummy/fallback bumper strip
const GLASS := Color(0.3, 0.42, 0.52)
const TIRE := Color(0.09, 0.09, 0.11)
const CHROME := Color(0.78, 0.8, 0.84)
const CLOTH := Color(0.93, 0.91, 0.86)   # bumper's convertible roof
const LIVERY := Color(0.88, 0.9, 0.92)   # smoky's white door panels
const LIGHT_RED := Color(1.0, 0.18, 0.12)
const LIGHT_BLUE := Color(0.25, 0.45, 1.0)
const BAR_PERIOD := 0.35  # smoky light-bar flip (seconds)

# half_len/half_wid = true footprint halves (px); radius = collision circle;
# skid_points = rear tire contact offsets (bike = 1); steer_wheels = front
# wheel centers that pivot with steering (empty = none).
const STYLES := {
	&"box": {
		"half_len": 26.0, "half_wid": 22.0, "radius": 22.0,
		"skid_points": [Vector2(-20, -14), Vector2(-20, 14)],
		"steer_wheels": [],
	},
	&"ghost": {
		"half_len": 26.0, "half_wid": 11.0, "radius": 17.0,
		"skid_points": [Vector2(-20, -8), Vector2(-20, 8)],
		"steer_wheels": [],
	},
	&"splatcat": {
		"half_len": 27.0, "half_wid": 13.0, "radius": 19.0,
		"skid_points": [Vector2(-19, -11), Vector2(-19, 11)],
		"steer_wheels": [],
	},
	&"bumper": {
		"half_len": 31.0, "half_wid": 13.0, "radius": 20.0,
		"skid_points": [Vector2(-24, -9), Vector2(-24, 9)],
		"steer_wheels": [],
	},
	&"smoky": {
		"half_len": 27.0, "half_wid": 15.0, "radius": 21.0,
		"skid_points": [Vector2(-19, -11), Vector2(-19, 11)],
		"steer_wheels": [],
	},
	&"mrghastly": {
		"half_len": 18.0, "half_wid": 7.0, "radius": 12.0,
		"skid_points": [Vector2(-13, 0)],
		"steer_wheels": [Vector2(13, 0)],
	},
	&"cricket": {
		"half_len": 20.0, "half_wid": 16.0, "radius": 15.0,
		"skid_points": [Vector2(-13, -13), Vector2(-13, 13)],
		"steer_wheels": [Vector2(13, -12), Vector2(13, 12)],
	},
	&"razorback": {
		# radius 21.5/22: kandykane held at the legacy 22 — the corner-escape
		# budget (mass-7 truck, 80px pocket) blows at 23; razorback slots under.
		"half_len": 28.0, "half_wid": 17.0, "radius": 21.5,
		"skid_points": [Vector2(-17, -14), Vector2(-17, 14)],
		"steer_wheels": [],
	},
	&"kandykane": {
		"half_len": 29.0, "half_wid": 17.0, "radius": 22.0,
		"skid_points": [Vector2(-22, -12), Vector2(-22, 12)],
		"steer_wheels": [],
	},
	&"hammertoe": {
		"half_len": 30.0, "half_wid": 23.0, "radius": 26.0,
		"skid_points": [Vector2(-17, -17), Vector2(-17, 17)],
		"steer_wheels": [Vector2(17, -17), Vector2(17, 17)],
	},
	&"lackey": {
		"half_len": 32.0, "half_wid": 20.0, "radius": 24.0,  # ×1.5 body_scale in the depot
		"skid_points": [Vector2(-24, -18), Vector2(-24, 18)],
		"steer_wheels": [Vector2(24, -18), Vector2(24, 18)],
	},
}

# Kandy Kane's polka dots — fixed pattern, same truck every boot.
const KANDY_DOTS := [
	Vector2(-24, -8), Vector2(-19, 6), Vector2(-12, -3), Vector2(-6, 9),
	Vector2(-4, -10), Vector2(3, 2), Vector2(9, -7), Vector2(11, 9),
]

const STEER_MAX := 0.45     # visual front-wheel deflection (rad)
const STEER_GAIN := 0.25    # heading rate -> wheel angle
const STEER_SMOOTH := 10.0

var style_id: StringName = &"box"
var primary := Color(0.85, 0.2, 0.3)
var accent := Color(1, 1, 1)
var _bar_t := 0.0        # smoky light-bar timer
var _bar_phase := false
var _steer := 0.0        # smoothed front-wheel pivot
var _prev_heading := 0.0

func _ready() -> void:
	scale = Vector2.ONE * FLEET_SCALE  # visual child only — never the physics body

func apply(id: StringName, primary_color: Color, accent_color: Color) -> void:
	style_id = id if STYLES.has(id) else &"box"
	primary = primary_color
	accent = accent_color
	scale = Vector2.ONE * FLEET_SCALE  # standalone uses (turntable) may apply pre-ready
	set_process(_animated())
	queue_redraw()

## Style metrics at fleet scale for every cosmetic consumer (shadow, muzzle,
## skids, flame anchors). `radius` is the exception: collision stays at the
## authored 1:1 value — the hitbox is intentionally smaller than the visual.
## Cached per style: drive_fx polls skid offsets every frame while skidding.
var _metrics_cache: Dictionary = {}

func metrics() -> Dictionary:
	if _metrics_cache.has(style_id):
		return _metrics_cache[style_id]
	var raw: Dictionary = STYLES[style_id]
	var skids: Array = []
	for p in raw.skid_points:
		skids.append((p as Vector2) * FLEET_SCALE)
	var m := {
		"half_len": float(raw.half_len) * FLEET_SCALE,
		"half_wid": float(raw.half_wid) * FLEET_SCALE,
		"radius": float(raw.radius),  # collision — deliberately unscaled
		"skid_points": skids,
		"steer_wheels": raw.steer_wheels,  # paint-local; the node's own scale covers them
	}
	_metrics_cache[style_id] = m
	return m

## Footprint rectangle for the drop shadow (applied by the vehicle).
func shadow_polygon() -> PackedVector2Array:
	var m: Dictionary = metrics()
	var l: float = m.half_len
	var w: float = m.half_wid
	return PackedVector2Array([
		Vector2(-l, -w), Vector2(l, -w), Vector2(l, w), Vector2(-l, w),
	])

func _animated() -> bool:
	if style_id == &"smoky":
		return true
	return not (metrics().steer_wheels as Array).is_empty()

func _process(delta: float) -> void:
	if style_id == &"smoky":
		_bar_t += delta
		if _bar_t >= BAR_PERIOD:
			_bar_t = 0.0
			_bar_phase = not _bar_phase
			queue_redraw()
		return
	_update_steer(delta)

## Visual front-wheel pivot: derived from the grandparent's heading rate
## (duck-typed — on a Vehicle that's the car turning; on a UI turntable there
## is no heading and the wheels stay straight).
func _update_steer(delta: float) -> void:
	var visual := get_parent()
	var owner_node: Node = visual.get_parent() if visual else null
	var h: Variant = owner_node.get("heading") if owner_node else null
	if not (h is float):
		return
	var rate := angle_difference(_prev_heading, h) / maxf(delta, 0.0001)
	_prev_heading = h
	var target := clampf(rate * STEER_GAIN, -STEER_MAX, STEER_MAX)
	var next := lerpf(_steer, target, minf(delta * STEER_SMOOTH, 1.0))
	if absf(next - _steer) > 0.004:
		_steer = next
		queue_redraw()
	else:
		_steer = next

func _draw() -> void:
	match style_id:
		&"ghost":
			_draw_ghost()
		&"splatcat":
			_draw_splatcat()
		&"bumper":
			_draw_bumper()
		&"smoky":
			_draw_smoky()
		&"mrghastly":
			_draw_mrghastly()
		&"cricket":
			_draw_cricket()
		&"razorback":
			_draw_razorback()
		&"kandykane":
			_draw_kandykane()
		&"hammertoe":
			_draw_hammertoe()
		&"lackey":
			_draw_lackey()
		_:
			_draw_box()

## The placeholder square — dummies and unknown ids keep the classic look.
func _draw_box() -> void:
	draw_rect(Rect2(-26, -22, 52, 44), primary)
	draw_rect(Rect2(20, -22, 6, 44), NOSE_ACCENT)

# --- shared parts ------------------------------------------------------------

## Octagonal hull: a rect with chamfered nose/tail corners. Nose at +X.
func _hull(l: float, w: float, nose_cut: float, tail_cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-l, -w + tail_cut), Vector2(-l + tail_cut, -w),
		Vector2(l - nose_cut, -w), Vector2(l, -w + nose_cut),
		Vector2(l, w - nose_cut), Vector2(l - nose_cut, w),
		Vector2(-l + tail_cut, w), Vector2(-l, w - tail_cut),
	])

func _outline(pts: PackedVector2Array) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, 1.5)

func _wheel(center: Vector2, size: Vector2, angle := 0.0) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(Rect2(-size * 0.5, size), TIRE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _headlights(nose_x: float, w: float) -> void:
	draw_rect(Rect2(nose_x - 3, -w + 1, 3, 3), NOSE_ACCENT)
	draw_rect(Rect2(nose_x - 3, w - 4, 3, 3), NOSE_ACCENT)

# --- the sedans --------------------------------------------------------------

## Ghost: low, long, tapered — a sheet of white with a sliver of canopy.
func _draw_ghost() -> void:
	var hull := _hull(26, 11, 9, 4)
	draw_colored_polygon(hull, primary)
	draw_rect(Rect2(-26, -9, 4, 18), TIRE)                    # tail vent
	draw_line(Vector2(10, 0), Vector2(25, 0), accent, 2.0)    # hood pinstripe
	draw_colored_polygon(PackedVector2Array([                  # swept canopy
		Vector2(-14, -7), Vector2(4, -6), Vector2(9, 0), Vector2(4, 6), Vector2(-14, 7),
	]), GLASS)
	draw_rect(Rect2(-13, -6, 3, 12), primary.darkened(0.25))   # roll hoop
	_headlights(26, 11)
	_outline(hull)

## Splat Cat: muscle — fat rear tires poking out, hood scoop, hunched roof.
func _draw_splatcat() -> void:
	_wheel(Vector2(-15, -11), Vector2(13, 6))
	_wheel(Vector2(-15, 11), Vector2(13, 6))
	_wheel(Vector2(16, -10), Vector2(9, 4))
	_wheel(Vector2(16, 10), Vector2(9, 4))
	var hull := _hull(27, 11, 6, 5)
	draw_colored_polygon(hull, primary)
	draw_rect(Rect2(-18, -9, 6, 18), primary.darkened(0.3))    # rear haunch shade
	draw_rect(Rect2(-2, -9, 8, 18), GLASS)                     # windshield band
	draw_rect(Rect2(-14, -8, 12, 16), primary.darkened(0.18))  # roof
	draw_rect(Rect2(8, -4, 12, 8), primary.darkened(0.35))     # hood scoop
	draw_rect(Rect2(10, -2, 8, 4), accent)                     # scoop mouth
	draw_rect(Rect2(-27, -6, 2, 4), CHROME)                    # twin exhausts
	draw_rect(Rect2(-27, 2, 2, 4), CHROME)
	_headlights(27, 11)
	_outline(hull)

## Bumper: the pink land-yacht — white cloth roof, chrome strip, tail fins.
func _draw_bumper() -> void:
	var hull := _hull(31, 11, 6, 3)
	draw_colored_polygon(hull, primary)
	draw_rect(Rect2(-31, -13, 5, 5), accent)                   # tail fins (poke wide)
	draw_rect(Rect2(-31, 8, 5, 5), accent)
	draw_line(Vector2(9, 0), Vector2(30, 0), CHROME, 2.0)      # hood chrome
	draw_rect(Rect2(3, -9, 6, 18), GLASS)                      # windshield band
	var roof := _hull(11, 9, 3, 3)                              # cloth top (centered)
	draw_set_transform(Vector2(-9, 0), 0.0, Vector2.ONE)
	draw_colored_polygon(roof, CLOTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-22, -2, 3, 4), CLOTH.darkened(0.2))       # roof seam button
	_headlights(31, 11)
	_outline(hull)

# --- the specialists ---------------------------------------------------------

## Mr. Ghastly: a hog and its rider — two wheels, tank, bars, helmet on top.
func _draw_mrghastly() -> void:
	_wheel(Vector2(-13, 0), Vector2(9, 5))
	_wheel(Vector2(13, 0), Vector2(8, 4), _steer)
	draw_line(Vector2(-16, -4), Vector2(-2, -3), CHROME, 1.5)   # exhaust pipes
	draw_line(Vector2(-16, 4), Vector2(-2, 3), CHROME, 1.5)
	draw_colored_polygon(PackedVector2Array([                    # frame + tank
		Vector2(-10, -2.5), Vector2(2, -3.5), Vector2(9, -2.5),
		Vector2(9, 2.5), Vector2(2, 3.5), Vector2(-10, 2.5),
	]), primary)
	draw_line(Vector2(8, -6), Vector2(8, 6), OUTLINE, 2.0)       # handlebars
	draw_rect(Rect2(-8, -4.5, 8, 9), accent.darkened(0.45))      # rider shoulders
	draw_circle(Vector2(-1, 0), 3.2, accent)                     # helmet
	draw_circle(Vector2(-1, 0), 1.2, GLASS)                      # visor glint
	draw_rect(Rect2(16, -1.5, 3, 3), NOSE_ACCENT)                # headlamp

## Cricket: dirt-track midget — wheels way outside the tub, huge rear wing.
func _draw_cricket() -> void:
	_wheel(Vector2(-13, -13), Vector2(10, 7))
	_wheel(Vector2(-13, 13), Vector2(10, 7))
	_wheel(Vector2(13, -12), Vector2(8, 6), _steer)
	_wheel(Vector2(13, 12), Vector2(8, 6), _steer)
	draw_rect(Rect2(-20, -15, 4, 30), accent)                    # rear wing
	draw_rect(Rect2(-21, -15, 6, 3), OUTLINE)                    # wing endplates
	draw_rect(Rect2(-21, 12, 6, 3), OUTLINE)
	var tub := PackedVector2Array([                              # narrow tub
		Vector2(-15, -7), Vector2(8, -6), Vector2(18, -3), Vector2(20, 0),
		Vector2(18, 3), Vector2(8, 6), Vector2(-15, 7),
	])
	draw_colored_polygon(tub, primary)
	draw_rect(Rect2(-14, -5, 6, 10), primary.darkened(0.35))     # engine block
	draw_circle(Vector2(-2, 0), 3.5, accent)                     # driver helmet
	draw_circle(Vector2(9, 0), 3.0, CLOTH)                       # nose roundel
	_outline(tub)

## Razorback: the Humvee — slab hood, steep glass band, spare on the roof.
func _draw_razorback() -> void:
	_wheel(Vector2(-17, -16), Vector2(11, 5))
	_wheel(Vector2(-17, 16), Vector2(11, 5))
	_wheel(Vector2(17, -16), Vector2(11, 5))
	_wheel(Vector2(17, 16), Vector2(11, 5))
	var hull := _hull(28, 14, 3, 3)
	draw_colored_polygon(hull, primary)
	draw_colored_polygon(PackedVector2Array([                    # sloped back
		Vector2(-28, -13), Vector2(-21, -13), Vector2(-21, 13), Vector2(-28, 13),
	]), primary.darkened(0.35))
	draw_rect(Rect2(-21, -13, 27, 26), primary.darkened(0.15))   # flat roof slab
	draw_rect(Rect2(6, -13, 4, 26), GLASS)                       # steep windscreen
	draw_line(Vector2(10, -14), Vector2(10, 14), OUTLINE, 1.5)   # hood seam
	draw_circle(Vector2(-13, 0), 5.0, TIRE)                      # roof spare
	draw_circle(Vector2(-13, 0), 1.8, primary.darkened(0.15))
	draw_rect(Rect2(26, -8, 3, 16), TIRE)                        # brush bumper
	_headlights(26, 14)
	_outline(hull)

## Kandy Kane: the ice-cream truck — cream box, polka dots, roof cone, window.
func _draw_kandykane() -> void:
	_wheel(Vector2(-18, -16), Vector2(10, 5))
	_wheel(Vector2(-18, 16), Vector2(10, 5))
	_wheel(Vector2(18, -16), Vector2(10, 5))
	_wheel(Vector2(18, 16), Vector2(10, 5))
	var hull := _hull(29, 15, 5, 2)
	draw_colored_polygon(hull, CLOTH)                            # cream box body
	for d in KANDY_DOTS:                                         # polka dots
		draw_circle(d, 2.4, primary)
	draw_rect(Rect2(16, -12, 5, 24), GLASS)                      # cab windshield
	draw_rect(Rect2(21, -15, 8, 30), primary)                    # candy nose band
	draw_rect(Rect2(-8, 11, 12, 4), GLASS)                       # serving window
	draw_rect(Rect2(-9, 10, 14, 1.5), accent)                    # awning stripe
	draw_colored_polygon(PackedVector2Array([                    # roof cone art
		Vector2(-4, -6), Vector2(-4, 6), Vector2(8, 0),
	]), Color(0.85, 0.65, 0.35))
	draw_circle(Vector2(-6, 0), 4.0, accent)                     # the scoop
	_headlights(29, 15)
	_outline(hull)

# --- the big boys ------------------------------------------------------------

## Hammertoe: monster truck — wheels the size of the cab, open bed, blower.
func _draw_hammertoe() -> void:
	_wheel(Vector2(-17, -17), Vector2(16, 12))
	_wheel(Vector2(-17, 17), Vector2(16, 12))
	_wheel(Vector2(17, -17), Vector2(16, 12), _steer)
	_wheel(Vector2(17, 17), Vector2(16, 12), _steer)
	var hull := _hull(24, 12, 5, 3)
	draw_colored_polygon(hull, primary)
	draw_rect(Rect2(-22, -10, 16, 20), Color(0.15, 0.15, 0.18))  # open bed
	draw_line(Vector2(-19, -10), Vector2(-19, 10), accent, 1.5)  # bed crossbars
	draw_line(Vector2(-14, -10), Vector2(-14, 10), accent, 1.5)
	draw_rect(Rect2(-6, -11, 4, 22), primary.darkened(0.3))      # cab back wall
	draw_rect(Rect2(2, -10, 6, 20), GLASS)                       # windshield
	draw_rect(Rect2(-2, -9, 4, 18), primary.darkened(0.15))      # cab roof
	draw_rect(Rect2(12, -5, 8, 10), TIRE)                        # hood blower
	draw_circle(Vector2(16, -2.5), 1.6, CHROME)
	draw_circle(Vector2(16, 2.5), 1.6, CHROME)
	draw_circle(Vector2(-7, -9), 1.8, CHROME)                    # exhaust stacks
	draw_circle(Vector2(-7, 9), 1.8, CHROME)
	_headlights(24, 12)
	_outline(hull)

## Lackey: the eight-wheel Stryker — angled hull, deck hatches, breach cannon.
func _draw_lackey() -> void:
	for x in [-24.0, -8.0, 8.0, 24.0]:
		var pivot := _steer if x == 24.0 else 0.0
		_wheel(Vector2(x, -18), Vector2(12, 6), pivot)
		_wheel(Vector2(x, 18), Vector2(12, 6), pivot)
	var hull := _hull(32, 15, 10, 6)
	draw_colored_polygon(hull, primary)
	draw_colored_polygon(PackedVector2Array([                    # sloped glacis nose
		Vector2(22, -13), Vector2(32, -5), Vector2(32, 5), Vector2(22, 13),
	]), primary.darkened(0.3))
	draw_rect(Rect2(-26, -11, 44, 22), primary.darkened(0.12))   # top deck
	draw_line(Vector2(-26, -15), Vector2(20, -15), accent.darkened(0.2), 1.5)  # side skirts
	draw_line(Vector2(-26, 15), Vector2(20, 15), accent.darkened(0.2), 1.5)
	draw_circle(Vector2(-16, -5), 3.5, primary.darkened(0.4))    # crew hatches
	draw_circle(Vector2(-16, 6), 3.5, primary.darkened(0.4))
	# Cannon ring only — the barrel is the LIVE turret now (weapons/turret.gd,
	# spawned by Vehicle when stats.turret is set); this is its mount base.
	draw_circle(Vector2(2, 0), 5.0, primary.darkened(0.45))
	_outline(hull)

## Smoky: pursuit SUV — boxy, white door livery, push bar, flashing light bar.
func _draw_smoky() -> void:
	var hull := _hull(25, 15, 4, 4)
	draw_rect(Rect2(25, -8, 3, 16), TIRE)                      # push bar
	draw_colored_polygon(hull, primary)
	draw_rect(Rect2(-12, -15, 14, 6), LIVERY)                  # door panels
	draw_rect(Rect2(-12, 9, 14, 6), LIVERY)
	draw_rect(Rect2(8, -12, 6, 24), GLASS)                     # windshield band
	draw_rect(Rect2(-16, -11, 22, 22), primary.darkened(0.2))  # long roof
	draw_rect(Rect2(-14, -9, 4, 18), GLASS.darkened(0.2))      # rear glass
	var hot := _bar_phase
	draw_rect(Rect2(0, -7, 5, 6), LIGHT_RED if hot else LIGHT_RED.darkened(0.6))
	draw_rect(Rect2(0, 1, 5, 6), LIGHT_BLUE if not hot else LIGHT_BLUE.darkened(0.6))
	_headlights(25, 15)
	_outline(hull)
