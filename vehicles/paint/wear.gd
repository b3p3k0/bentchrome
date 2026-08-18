extends RefCounted
## Generic progressive wear marks — the three visual damage tiers every
## combatant shows as its HP falls. Derived from STYLE footprint metrics ONLY
## (half_len / half_wid, optional tail_len), so every current and future car
## inherits wear with zero per-style authoring; tests bounds-check the whole
## registry. Deterministic: the RNG is rebuilt per call from wear_seed (style
## id + palette), identical on host and LAN puppet with zero wire state, and
## tier 2 CONTINUES tier 1's stream — going BANGED -> BUSTED accumulates
## damage on top of the same dents instead of reshuffling them.
## Preloaded by car_paint.gd like parts.gd — NEVER references Vehicle/CarPaint.

const FRESH := 0
const BANGED := 1
const BUSTED := 2

## Ghost's 26x11 footprint = count scale 1.0; bikes bottom out, APC/trailer cap.
const REF_AREA := 1144.0
const COUNT_SCALE_MIN := 0.4
const COUNT_SCALE_MAX := 1.6
const SCRATCH_BASE := 4
const DENT_BASE := 2
const SOOT_BASE := 3
const CHIP_BASE := 2

const SCRATCH_COLOR := Color(0.08, 0.08, 0.1, 0.8)    # Parts.OUTLINE, worn in
const DENT_COLOR := Color(0.08, 0.08, 0.1, 0.35)      # soft panel shadow
const SOOT_COLOR := Color(0.09, 0.09, 0.11, 0.5)      # Parts.TIRE smudge
const CHIP_COLOR := Color(0.78, 0.8, 0.84, 0.9)       # Parts.CHROME exposed metal
const CRUMPLE_COLOR := Color(0.08, 0.08, 0.1, 0.9)    # hard nose creases

## Stable across host/puppet/runs: same model + palette = same dents everywhere.
static func wear_seed(id: StringName, primary: Color, accent: Color) -> int:
	return hash("%s|%s|%s" % [id, primary.to_html(), accent.to_html()])

## PURE: raw (unscaled) STYLE dict in, render-primitive descriptors out.
## Exactly three render kinds, so draw_marks stays a tiny match:
##   {"kind": &"stroke", "points": PackedVector2Array, "width": float, "color": Color}
##   {"kind": &"poly",   "points": PackedVector2Array, "color": Color}
##   {"kind": &"blob",   "pos": Vector2, "radius": float, "color": Color}
static func wear_marks(metrics: Dictionary, tier: int, seed_value: int) -> Array:
	if tier <= FRESH:
		return []
	var half_len := float(metrics.get("half_len", 16.0))
	# tail_len (coldfront's plow) doubles as "true body half-length": clamping
	# to it keeps marks off nose gear and out of any hull gap at either end.
	var l := minf(half_len, float(metrics.get("tail_len", half_len)))
	var w := float(metrics.get("half_wid", 10.0))
	var k := clampf(4.0 * l * w / REF_AREA, COUNT_SCALE_MIN, COUNT_SCALE_MAX)
	var rng := RandomNumberGenerator.new()  # the ImpactFX idiom: rebuilt per call
	rng.seed = seed_value
	var out: Array = []
	for i in maxi(1, roundi(SCRATCH_BASE * k)):
		out.append(_scratch(rng, l, w))
	for i in maxi(1, roundi(DENT_BASE * k)):
		out.append(_dent(rng, l, w))
	if tier >= BUSTED:  # strict superset: the stream continues past the BANGED layer
		for i in maxi(1, roundi(SOOT_BASE * k)):
			out.append(_soot(rng, l, w))
		for i in maxi(1, roundi(CHIP_BASE * k)):
			out.append(_chip(rng, l, w))
		out.append_array(_crumple(rng, l, w))
	return out

static func draw_marks(c: CanvasItem, marks: Array) -> void:
	for m in marks:
		match m.kind:
			&"stroke":
				c.draw_polyline(m.points, m.color, m.width)
			&"poly":
				c.draw_colored_polygon(m.points, m.color)
			&"blob":
				c.draw_circle(m.pos, m.radius, m.color)

static func _clamp_pt(p: Vector2, l: float, w: float) -> Vector2:
	return Vector2(clampf(p.x, -0.92 * l, 0.92 * l), clampf(p.y, -0.85 * w, 0.85 * w))

## Thin kinked polyline at a shallow travel-aligned angle — a keyed door, a
## guardrail kiss.
static func _scratch(rng: RandomNumberGenerator, l: float, w: float) -> Dictionary:
	var center := Vector2(rng.randf_range(-0.7, 0.7) * l, rng.randf_range(-0.8, 0.8) * w)
	var length := rng.randf_range(6.0, 14.0)
	var dir := Vector2.RIGHT.rotated(rng.randf_range(-0.45, 0.45))
	var kink := dir.orthogonal() * rng.randf_range(0.5, 1.2) \
		* (1.0 if rng.randf() < 0.5 else -1.0)
	var pts := PackedVector2Array([
		_clamp_pt(center - dir * length * 0.5, l, w),
		_clamp_pt(center + kink, l, w),
		_clamp_pt(center + dir * length * 0.5, l, w),
	])
	return {"kind": &"stroke", "points": pts,
		"width": rng.randf_range(1.0, 1.4), "color": SCRATCH_COLOR}

## Rim-band center: dents/chips live where panels plausibly are — along the
## flanks or near the ends — never floating mid-roof.
static func _rim_point(rng: RandomNumberGenerator, l: float, w: float) -> Vector2:
	var flip := 1.0 if rng.randf() < 0.5 else -1.0
	if rng.randf() < 0.5:
		return Vector2(rng.randf_range(-0.7, 0.7) * l, rng.randf_range(0.55, 0.8) * w * flip)
	return Vector2(rng.randf_range(0.6, 0.85) * l * flip, rng.randf_range(-0.6, 0.6) * w)

static func _dent(rng: RandomNumberGenerator, l: float, w: float) -> Dictionary:
	var center := _rim_point(rng, l, w)
	var radius := rng.randf_range(2.5, 4.5)
	var pts := PackedVector2Array()
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		pts.append(_clamp_pt(center + Vector2.RIGHT.rotated(a) * radius
			* rng.randf_range(0.6, 1.0), l, w))
	return {"kind": &"poly", "points": pts, "color": DENT_COLOR}

## Soot smudge — radius shrinks to whatever margin the footprint leaves, so a
## bike's smudges never bleed past its 7px flanks.
static func _soot(rng: RandomNumberGenerator, l: float, w: float) -> Dictionary:
	var pos := Vector2(rng.randf_range(-0.7, 0.7) * l, rng.randf_range(-0.6, 0.6) * w)
	var radius := rng.randf_range(3.0, 5.5)
	radius = maxf(1.0, minf(radius, minf(0.95 * w - absf(pos.y), 0.95 * l - absf(pos.x))))
	return {"kind": &"blob", "pos": pos, "radius": radius, "color": SOOT_COLOR}

static func _chip(rng: RandomNumberGenerator, l: float, w: float) -> Dictionary:
	var center := _rim_point(rng, l, w)
	var dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	var length := rng.randf_range(2.5, 4.5)
	var pts := PackedVector2Array([
		_clamp_pt(center - dir * length * 0.5, l, w),
		_clamp_pt(center + dir * length * 0.5, l, w),
	])
	return {"kind": &"stroke", "points": pts, "width": 1.2, "color": CHIP_COLOR}

## The nose took the worst of it: three jagged creases zigzagging toward the
## front edge plus one dark buckled-panel blotch.
static func _crumple(rng: RandomNumberGenerator, l: float, w: float) -> Array:
	var out: Array = []
	for i in 3:
		var p := Vector2(rng.randf_range(0.72, 0.9) * l, rng.randf_range(-0.6, 0.6) * w)
		var pts := PackedVector2Array([_clamp_pt(p, l, w)])
		for s in 2:
			p += Vector2(rng.randf_range(1.5, 4.0), rng.randf_range(-3.0, 3.0))
			pts.append(_clamp_pt(p, l, w))
		out.append({"kind": &"stroke", "points": pts, "width": 1.3, "color": CRUMPLE_COLOR})
	var center := Vector2(rng.randf_range(0.75, 0.88) * l, rng.randf_range(-0.4, 0.4) * w)
	var blotch := PackedVector2Array()
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.35, 0.35)
		blotch.append(_clamp_pt(center + Vector2.RIGHT.rotated(a)
			* rng.randf_range(2.0, 3.5), l, w))
	out.append({"kind": &"poly", "points": blotch, "color": DENT_COLOR})
	return out
