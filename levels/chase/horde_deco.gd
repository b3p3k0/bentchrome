extends Node2D
## The horde as a SIGHT (the wall owns the physics; this owns the picture):
## a billowing wall of dust rolling up the road behind a mob of modified
## vehicles — real Buzzard paint bodies in raider rust, bobbing and lurching
## in the murk, headlights burning through it, muzzle flashes and tracers
## stabbing north as the pack pours fire up the road. This is where the
## harassers come from, and where they go back to. Mad Max, 16-bit.
##
## Layers, bottom to top: the BANK (ground bands and the deep billows — the
## dust the mob kicks up), the RIDERS leading it, then the LIP (a thin haze of
## billows over them, the lights, the shooting). The vehicles lead the cloud;
## the cloud never buries them. Two particle systems ride the whole thing.
## Everything is procedural paint in the horde wall's local space (origin =
## the crest, road centre); the wall pushes `half` and `pressure` every tick.

const CarPaintScript := preload("res://vehicles/car_paint.gd")

const RIDERS := 11
const BAND_DEPTH := 520.0
const LOW_DUST := 150
const HIGH_DUST := 80
const FLINCH_RECOIL := 40.0     # px the riders are shoved south by a bang
const FLINCH_RECOIL_T := 0.6    # seconds the shove takes to ease off
const RUST := [
	Color(0.42, 0.28, 0.18), Color(0.36, 0.34, 0.3), Color(0.5, 0.34, 0.14),
	Color(0.3, 0.3, 0.32), Color(0.45, 0.3, 0.2), Color(0.38, 0.33, 0.28),
]
const DUST_LIP := Color(0.72, 0.58, 0.4)     # sunlit leading billows
const DUST_MID := Color(0.55, 0.43, 0.3)
const DUST_DEEP := Color(0.36, 0.28, 0.2)
const LAMP := Color(1.0, 0.9, 0.58)
const FLASH := Color(1.0, 0.95, 0.75)
const TRACER := Color(1.0, 0.8, 0.45)

var half := 640.0      # road half-width + margin at the crest (the wall pushes it)
var pressure := 0.0    # 0 far .. 1 contact: fire and fury scale with it
var halted := false    # stopped at the brink: the riders lock up, the dust settles
var lost_sight := false   # the car is off the road: the headlights sweep, looking for it
var _flinch_t := 0.0   # a bang in the dust: the riders recoil south for a beat
var skid_marks: Array = []   # [from, to] world-local streaks laid on the halt
var _halt_t := 0.0

var _riders: Array = []     # {node, base, kind, half_len, bob, lurch, sway, phase, flash}
var _bank: Node2D = null    # drawn FIRST: the ground and the deep dust
var _lip: Node2D = null     # drawn LAST: thin haze, lights, tracers
var _low: CPUParticles2D = null
var _high: CPUParticles2D = null
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 977
	_bank = Crest.new()
	_bank.name = "Bank"
	_bank.deco = self
	_bank.layer = Crest.BANK
	add_child(_bank)
	_build_riders()
	_low = _dust(LOW_DUST, 2.8, Vector2(half * 0.9, 120.0), Vector2(0.0, 180.0),
		40.0, 120.0, 5.0, 11.0, Color(0.6, 0.47, 0.33, 0.32))
	_high = _dust(HIGH_DUST, 3.8, Vector2(half * 0.95, 200.0), Vector2(0.0, 260.0),
		15.0, 55.0, 9.0, 17.0, Color(0.7, 0.58, 0.42, 0.18))
	_lip = Crest.new()
	_lip.name = "Lip"
	_lip.deco = self
	_lip.layer = Crest.LIP
	add_child(_lip)

## Real Buzzard bodies, raider rust, scattered through the band — bikes up
## front where the dust is thin, the heavy metal deeper in the murk.
func _build_riders() -> void:
	var lane_x: Array = []
	for i in RIDERS:
		var kind: StringName = &"buzz_bike"
		var roll := _rng.randf()
		if roll > 0.82:
			kind = &"buzz_technical"
		elif roll > 0.5:
			kind = &"buzz_sedan"
		var body := CarPaintScript.new()
		var rust: Color = RUST[_rng.randi() % RUST.size()].darkened(_rng.randf_range(0.0, 0.2))
		body.apply(kind, rust, rust.lightened(0.25))
		body.rotation = -PI / 2.0
		var depth_min := 60.0 if kind == &"buzz_bike" else 140.0
		var base := Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(depth_min, BAND_DEPTH * 0.86))
		body.position = Vector2(base.x * half, base.y)
		add_child(body)
		var style: Dictionary = CarPaintScript.STYLES.get(kind, {})
		_riders.append({
			"node": body, "base": base, "kind": kind,
			"half_len": float(style.get("half_len", 20.0)) * CarPaintScript.FLEET_SCALE,
			"bob": _rng.randf_range(1.5, 3.2), "lurch": _rng.randf_range(0.5, 1.1),
			"sway": _rng.randf_range(0.2, 0.5), "phase": _rng.randf_range(0.0, TAU),
			"flash": _rng.randf_range(0.0, 1.5),
		})
		lane_x.append(base.x)

func _dust(amount: int, life: float, extents: Vector2, at: Vector2, v0: float, v1: float,
		s0: float, s1: float, tint: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false   # world space: the cloud trails as the front advances
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector2(0, -14)
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	p.color = tint
	var ramp := Gradient.new()   # billow in, thin out
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.add_point(0.2, tint)
	ramp.set_color(ramp.get_point_count() - 1, Color(tint.r, tint.g, tint.b, 0.0))
	p.color_ramp = ramp
	p.preprocess = 2.0
	add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	# The brink: motion damps to a settle over half a second, the skids are
	# laid once under every rider, and the dust stops boiling up.
	var motion := 1.0
	if halted:
		if _halt_t == 0.0:
			_lay_skids()
		_halt_t += delta
		motion = 0.06 + 0.94 * (1.0 - clampf(_halt_t / 0.5, 0.0, 1.0))
		if _low and _halt_t > 0.4:
			_low.emitting = false
	# The recoil: a shove south that eases off over FLINCH_RECOIL_T.
	var recoil := 0.0
	if _flinch_t > 0.0:
		_flinch_t = maxf(_flinch_t - delta, 0.0)
		var k := _flinch_t / FLINCH_RECOIL_T
		recoil = FLINCH_RECOIL * (1.0 - (1.0 - k) * (1.0 - k))
	for r in _riders:
		var node: Node2D = r["node"]
		var base: Vector2 = r["base"]
		var bob: float = sin(_t * r["bob"] + r["phase"]) * 5.0 * motion
		var lurch: float = sin(_t * r["lurch"] + r["phase"] * 2.3) * 22.0 * motion
		node.position = Vector2(base.x * half + lurch, base.y + bob + recoil * (0.6 + 0.4 * float(r["phase"]) / TAU))
		node.rotation = -PI / 2.0 + sin(_t * r["sway"] * 2.0 + r["phase"]) * 0.12 * motion
		# Depth is murk: the deeper in the bank, the fainter the hull.
		node.modulate = Color(1.0, 1.0, 1.0, clampf(1.15 - base.y / BAND_DEPTH, 0.4, 1.0))
		# Potshots up the road: the closer the pack, the more of them. None
		# once they've pulled up — they know it's over.
		if not halted:
			r["flash"] -= delta * (0.6 + 1.6 * pressure)
			if r["flash"] <= 0.0:
				r["flash"] = _rng.randf_range(0.9, 3.5)
				r["flashing"] = 0.09
		if r.get("flashing", 0.0) > 0.0:
			r["flashing"] = float(r["flashing"]) - delta
	if _low:
		_low.emission_rect_extents.x = half * 0.9
	if _high:
		_high.emission_rect_extents.x = half * 0.95
	_bank.queue_redraw()
	_lip.queue_redraw()

## A bang in the dust: the riders recoil, the headlights stutter, and a puff
## of dust jumps off the crest.
func flinch() -> void:
	_flinch_t = FLINCH_RECOIL_T
	if _high != null:
		var puff := _dust(30, 0.7, Vector2(half * 0.6, 30.0), Vector2(0.0, 10.0), 120.0, 260.0, 8.0, 16.0, DUST_LIP)
		puff.one_shot = true
		puff.explosiveness = 0.9
		puff.preprocess = 0.0
		puff.emitting = true
		get_tree().create_timer(1.6).timeout.connect(puff.queue_free, CONNECT_ONE_SHOT)

func flinching() -> bool:
	return _flinch_t > 0.0

## The lock-up: a pair of dark streaks trailing south from every rider that
## was moving, laid once and painted by the bank layer from then on.
func _lay_skids() -> void:
	skid_marks.clear()
	for r in _riders:
		var node: Node2D = r["node"]
		var w: float = float(r["half_len"])
		var track := 6.0 if r["kind"] == &"buzz_bike" else 12.0
		for side in ([0.0] if r["kind"] == &"buzz_bike" else [-1.0, 1.0]):
			var from := node.position + Vector2(side * track, w * 0.6)
			var length := _rng.randf_range(40.0, 90.0)
			skid_marks.append([from, from + Vector2(_rng.randf_range(-8.0, 8.0), length)])

## The picture around the riders, redrawn every frame. BANK: ground bands
## and the deep billows under them. LIP: a thin sunlit haze over them, then
## the lights and the shooting.
class Crest extends Node2D:
	enum { BANK, LIP }
	var deco = null
	var layer: int = BANK

	func _draw() -> void:
		if layer == BANK:
			_draw_bank()
		else:
			_draw_lip()

	func _draw_bank() -> void:
		var half: float = deco.half
		var t: float = deco._t
		# The dust bank itself: dense at the front, thinning south into haze.
		# The top band's leading edge is a ragged wave, never a ruled line.
		for i in 4:
			var f := float(i) / 4.0
			var col := DUST_MID.lerp(DUST_DEEP, f)
			col.a = 0.7 - f * 0.1
			if i == 0:
				var wave := PackedVector2Array()
				var n := 24
				for k in n + 1:
					var x := -half + half * 2.0 * float(k) / float(n)
					var y := 14.0 + 16.0 * sin(x * 0.011 + t * 1.3) + 9.0 * sin(x * 0.031 - t * 0.9)
					wave.append(Vector2(x, y))
				wave.append(Vector2(half, BAND_DEPTH * 0.28))
				wave.append(Vector2(-half, BAND_DEPTH * 0.28))
				draw_colored_polygon(wave, col)
			else:
				draw_rect(Rect2(-half, BAND_DEPTH * f, half * 2.0, BAND_DEPTH * 0.28), col)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		_billows(rng, half, t, 13, 40.0, 160.0, 60.0, 115.0, DUST_MID, 0.85)
		_billows(rng, half, t, 11, 220.0, 380.0, 95.0, 150.0, DUST_DEEP, 0.9)
		# Every rider throws its own wake — the shape that sets a hull off the murk.
		for r in deco._riders:
			var node: Node2D = r["node"]
			var w: float = float(r["half_len"])
			draw_circle(node.position + Vector2(0, w * 0.9), w * 0.95, Color(0.16, 0.12, 0.08, 0.5))
		# Pulled up at the brink: the skids they laid doing it.
		for mark in deco.skid_marks:
			draw_line(mark[0], mark[1], Color(0.1, 0.08, 0.06, 0.75), 3.5)

	func _draw_lip() -> void:
		var half: float = deco.half
		var t: float = deco._t
		var rng := RandomNumberGenerator.new()
		rng.seed = 4243
		# The sunlit leading lip: thin enough that the hulls read through it.
		_billows(rng, half, t, 16, -30.0, 40.0, 42.0, 80.0, DUST_LIP, 0.38)
		for i in 14:
			var x := -half + (half * 2.0) * (float(i) + 0.5) / 14.0
			var r := 30.0 + 12.0 * sin(t * 1.7 + float(i) * 1.3)
			var col := DUST_LIP.lightened(0.25)
			col.a = 0.3
			draw_circle(Vector2(x + sin(t * 0.9 + float(i)) * 14.0, -18.0 + 6.0 * sin(t * 2.1 + float(i) * 0.7)), r, col)
		# Headlights burning through the dust, and the potshots.
		for r in deco._riders:
			var node: Node2D = r["node"]
			var nose: Vector2 = node.position + Vector2(0.0, -float(r["half_len"]))
			var veil: float = clampf(1.0 - node.position.y / (BAND_DEPTH * 1.3), 0.4, 1.0)
			var flick := 0.85 + 0.15 * sin(t * 23.0 + float(r["phase"]) * 5.0)
			if deco._flinch_t > 0.0:
				flick *= 0.3 + 0.7 * absf(sin(t * 31.0 + float(r["phase"]) * 3.0))   # the stutter
			var sweep := 0.0
			if deco.lost_sight:
				sweep = 30.0 * sin(t * 1.3 + float(r["phase"]))   # looking for you
			var spread: float = 7.0 if r["kind"] == &"buzz_bike" else 13.0
			var lamps: Array = [nose + Vector2(sweep, 0)] if r["kind"] == &"buzz_bike" \
				else [nose + Vector2(-spread + sweep, 0), nose + Vector2(spread + sweep, 0)]
			for lamp in lamps:
				draw_circle(lamp, 13.0, Color(LAMP.r, LAMP.g, LAMP.b, 0.14 * veil * flick))
				draw_circle(lamp, 4.5, Color(LAMP.r, LAMP.g, LAMP.b, 0.9 * veil * flick))
			if r.get("flashing", 0.0) > 0.0:
				var k: float = float(r["flashing"]) / 0.09
				draw_circle(nose + Vector2(0, -6), 7.0 * k, Color(FLASH.r, FLASH.g, FLASH.b, 0.9 * veil))
				var reach := 90.0 + 70.0 * k
				draw_line(nose + Vector2(0, -12), nose + Vector2(rng.randf_range(-6, 6), -12 - reach),
					Color(TRACER.r, TRACER.g, TRACER.b, 0.7 * veil * k), 2.0)

	## A row of billows: ragged lumps (jittered polygons, never clean circles),
	## each with a sunlit crown and a sooty underside, breathing and rolling on
	## its own clock so the wall boils instead of sliding.
	func _billows(rng: RandomNumberGenerator, half: float, t: float, count: int,
			y0: float, y1: float, r0: float, r1: float, tint: Color, alpha: float) -> void:
		for i in count:
			var x := -half * 0.95 + half * 1.9 * (float(i) + 0.5) / float(count) + rng.randf_range(-20.0, 20.0)
			var y := rng.randf_range(y0, y1)
			var r := rng.randf_range(r0, r1)
			var rate := rng.randf_range(0.6, 1.4)
			var ph := rng.randf_range(0.0, TAU)
			var breathe := 1.0 + 0.12 * sin(t * rate + ph)
			var roll := Vector2(sin(t * rate * 0.7 + ph) * 12.0, cos(t * rate * 0.5 + ph) * 8.0)
			var at := Vector2(x, y) + roll
			var lump := PackedVector2Array()
			var n := 11
			for k in n:
				var a := TAU * float(k) / float(n)
				var rag := 1.0 + 0.16 * sin(a * 3.0 + ph + t * rate * 0.8) + 0.1 * sin(a * 7.0 + ph * 2.0)
				lump.append(at + Vector2.RIGHT.rotated(a) * r * breathe * rag)
			var col := tint.darkened(rng.randf_range(0.0, 0.18))
			col.a = alpha
			draw_colored_polygon(lump, col)
			# Soot under, sun on top: the volume read.
			var soot := tint.darkened(0.45)
			soot.a = alpha * 0.5
			draw_circle(at + Vector2(r * 0.15, r * 0.35), r * 0.55 * breathe, soot)
			var hi := tint.lightened(0.22)
			hi.a = alpha * 0.55
			draw_circle(at + Vector2(-r * 0.25, -r * 0.32), r * 0.4 * breathe, hi)
			# Grit: a few dark flecks tumbling in the lump.
			for k in 3:
				var fleck := at + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)) * 0.6
				draw_circle(fleck + Vector2(0, sin(t * 3.0 + ph + float(k)) * 4.0), 2.5,
					Color(0.14, 0.1, 0.07, alpha * 0.6))
