extends Node2D
## Procedural per-car body paint. One style per roster id (fallback &"box" —
## the classic placeholder square) drawn in true-footprint local px. Each
## style lives in its own vehicles/paint/<id>.gd file: a STYLE dict carrying
## the physics-facing metrics (collision radius, skid contact points,
## steering wheels — so visuals and gameplay agree per car) plus a static
## paint() that draws the silhouette. Register new cars in STYLE_SCRIPTS.
## The whole fleet renders at FLEET_SCALE while collision radii stay 1:1 —
## hitbox-smaller-than-visual is deliberate (near-misses read as skill, and
## the corner-escape budgets are radius-coupled). Don't "fix" the split.
## NEVER references Vehicle (projectile-side circular-load rule): the parent
## is duck-typed where needed.

const Parts := preload("res://vehicles/paint/parts.gd")

const FLEET_SCALE := 1.25  # visual size of every car; collision radii stay 1:1

const BRAKE_OFF := Color(0.32, 0.03, 0.04)
const BRAKE_ON := Color(1.0, 0.08, 0.04)
const BAR_PERIOD := 0.35  # light-bar flip for "blink" styles (seconds)

## One file per style: STYLE metrics + static paint(). The dict key must
## match the roster/stats id or the car falls back to the box.
const STYLE_SCRIPTS := {
	&"ghost": preload("res://vehicles/paint/ghost.gd"),
	&"splatcat": preload("res://vehicles/paint/splatcat.gd"),
	&"bumper": preload("res://vehicles/paint/bumper.gd"),
	&"smoky": preload("res://vehicles/paint/smoky.gd"),
	&"mrghastly": preload("res://vehicles/paint/mrghastly.gd"),
	&"cricket": preload("res://vehicles/paint/cricket.gd"),
	&"razorback": preload("res://vehicles/paint/razorback.gd"),
	&"kandykane": preload("res://vehicles/paint/kandykane.gd"),
	&"hammertoe": preload("res://vehicles/paint/hammertoe.gd"),
	&"lackey": preload("res://vehicles/paint/lackey.gd"),
	&"goliath_cab": preload("res://vehicles/paint/goliath_cab.gd"),
	&"goliath_trailer": preload("res://vehicles/paint/goliath_trailer.gd"),
	&"buzz_bike": preload("res://vehicles/paint/buzz_bike.gd"),
	&"buzz_sedan": preload("res://vehicles/paint/buzz_sedan.gd"),
	&"buzz_technical": preload("res://vehicles/paint/buzz_technical.gd"),
}

## The classic placeholder square — dummies and unknown ids keep it.
const BOX_STYLE := {
	"half_len": 26.0, "half_wid": 22.0, "radius": 22.0,
	"skid_points": [Vector2(-20, -14), Vector2(-20, 14)],
	"steer_wheels": [],
}

# half_len/half_wid = true footprint halves (px); radius = collision circle;
# skid_points = rear tire contact offsets (bike = 1); steer_wheels = front
# wheel centers that pivot with steering (empty = none). Assembled from the
# per-style files so metrics and silhouette travel together.
static var STYLES := _build_styles()

static func _build_styles() -> Dictionary:
	var out := {&"box": BOX_STYLE}
	for id in STYLE_SCRIPTS:
		var style: Dictionary = STYLE_SCRIPTS[id].STYLE
		out[id] = style
	return out

const STEER_MAX := 0.45     # visual front-wheel deflection (rad)
const STEER_GAIN := 0.25    # heading rate -> wheel angle
const STEER_SMOOTH := 10.0

var style_id: StringName = &"box"
var primary := Color(0.85, 0.2, 0.3)
var accent := Color(1, 1, 1)
var _bar_t := 0.0        # blink-style light-bar timer
var _bar_phase := false
var _steer := 0.0        # smoothed front-wheel pivot
var _prev_heading := 0.0
var _service_braking := false

func _ready() -> void:
	scale = Vector2.ONE * FLEET_SCALE  # visual child only — never the physics body

func apply(id: StringName, primary_color: Color, accent_color: Color) -> void:
	style_id = id if STYLES.has(id) else &"box"
	primary = primary_color
	accent = accent_color
	scale = Vector2.ONE * FLEET_SCALE  # standalone uses (turntable) may apply pre-ready
	set_process(_animated())
	queue_redraw()

func set_service_braking(on: bool) -> void:
	if _service_braking == on:
		return
	_service_braking = on
	queue_redraw()

func brake_lights_on() -> bool:
	return _service_braking

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
	if _blinks():
		return true
	return not (metrics().steer_wheels as Array).is_empty()

## Styles with "blink": true flip _bar_phase on BAR_PERIOD (smoky's light bar).
func _blinks() -> bool:
	return bool((STYLES[style_id] as Dictionary).get("blink", false))

func _process(delta: float) -> void:
	if _blinks():
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
	if STYLE_SCRIPTS.has(style_id):
		STYLE_SCRIPTS[style_id].paint(self, primary, accent, _steer, _bar_phase)
	else:
		_draw_box()
	_taillights()

## The placeholder square — dummies and unknown ids keep the classic look.
func _draw_box() -> void:
	draw_rect(Rect2(-26, -22, 52, 44), primary)
	draw_rect(Rect2(20, -22, 6, 44), Parts.NOSE_ACCENT)

## One shared rear-light language across the procedural fleet. Bikes carry a
## single centered lamp; every wider body gets a pair at its authored corners.
func _taillights() -> void:
	var raw: Dictionary = STYLES[style_id]
	var tail_x := -float(raw.half_len)
	var color := BRAKE_ON if _service_braking else BRAKE_OFF
	if (raw.skid_points as Array).size() == 1:  # the bikes
		draw_rect(Rect2(tail_x - 1.0, -2.0, 3.0, 4.0), color)
		return
	var y := maxf(float(raw.half_wid) - 5.0, 2.0)
	draw_rect(Rect2(tail_x - 1.0, -y - 2.0, 3.0, 4.0), color)
	draw_rect(Rect2(tail_x - 1.0, y - 2.0, 3.0, 4.0), color)
