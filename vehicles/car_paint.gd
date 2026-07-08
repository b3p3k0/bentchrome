extends Node2D
## Procedural per-car body paint. One style per roster id (fallback &"box" —
## the classic placeholder square) drawn in true-footprint local px; the style
## table also carries the physics-facing metrics (collision radius, skid
## contact points, steering wheels) so visuals and gameplay agree per car.
## NEVER references Vehicle (projectile-side circular-load rule): the parent
## is duck-typed where needed.

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
}

var style_id: StringName = &"box"
var primary := Color(0.85, 0.2, 0.3)
var accent := Color(1, 1, 1)
var _bar_t := 0.0        # smoky light-bar timer
var _bar_phase := false

func apply(id: StringName, primary_color: Color, accent_color: Color) -> void:
	style_id = id if STYLES.has(id) else &"box"
	primary = primary_color
	accent = accent_color
	set_process(_animated())
	queue_redraw()

func metrics() -> Dictionary:
	return STYLES[style_id]

## Footprint rectangle for the drop shadow (applied by the vehicle).
func shadow_polygon() -> PackedVector2Array:
	var m: Dictionary = metrics()
	var l: float = m.half_len
	var w: float = m.half_wid
	return PackedVector2Array([
		Vector2(-l, -w), Vector2(l, -w), Vector2(l, w), Vector2(-l, w),
	])

func _animated() -> bool:
	return style_id == &"smoky"

func _process(delta: float) -> void:
	_bar_t += delta
	if _bar_t >= BAR_PERIOD:
		_bar_t = 0.0
		_bar_phase = not _bar_phase
		queue_redraw()

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
