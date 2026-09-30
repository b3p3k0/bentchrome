extends Node2D
## Route 666's roadside dressing: pure paint and FX — NOTHING here collides
## (the road is busy enough; AI feelers never have to know). Kinds:
##   sign       — a post and a green highway sign with a line or two of copy
##   billboard  — two posts and a big board with a parody ad on it
##   vultures   — two to four buzzards circling overhead (z 3), animated
##   wreck_fire — flame flicker and smoke wisps over a burning wreck
##   tumbleweed — a dry ball rolling slowly across the road and back
## Copy is dealt from the tables below by the seed, so a mile of Route 666
## never reads the same twice and a course seed always reads the same.

const SIGN_COPY := [
	["ROUTE 666", "NORTH"],
	["MERCY", "40"],
	["NO STOPPING", "ANY TIME"],
	["BUZZARD", "COUNTRY"],
	["LAST GAS", "50 MI"],
	["SPEED LIMIT", "WHATEVER"],
	["EXIT 0", "NO SERVICES"],
	["BRIDGE OUT", "EVENTUALLY"],
	["WRONG WAY", "PROBABLY"],
	["SLOW", "CHILDREN? NO."],
	["DEER", "XING"],
	["REST AREA", "CLOSED"],
]
const BILLBOARD_COPY := [
	["SLO MO'S", "PARTS FOR THE ROAD", "next stop, or the one after"],
	["KANDY KANE", "ICE CREAM", "we deliver. we do not stop."],
	["WANTED", "HUBCAP", "reward: a hubcap"],
	["VISIT MERCY", "POP. 0", "and falling"],
	["BENT CHROME", "MOTORS", "as seen on the shoulder"],
	["ARE YOU", "SAVED?", "have you tried nitro"],
	["PHANTOM", "PHIRE", "smoke 'em if you got 'em"],
	["THE BUZZARDZ", "PLAY TONIGHT", "wherever you are"],
	["FREE", "TOWING", "you won't need to call"],
	["DRIVE SAFE", "", "ha ha"],
]
const BOARD_TINTS := [Color(0.82, 0.74, 0.5), Color(0.6, 0.72, 0.8), Color(0.85, 0.62, 0.5), Color(0.72, 0.8, 0.62)]
const SIGN_GREEN := Color(0.1, 0.36, 0.2)
const SIGN_TEXT := Color(0.94, 0.95, 0.9)
const POST := Color(0.28, 0.28, 0.3)
const SMOKE := Color(0.25, 0.23, 0.22)
const FLAME := [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.3), Color(0.9, 0.3, 0.1)]

@export var kind: StringName = &"sign"
@export var side := 1.0            # which verge: the post faces the road
@export var copy_seed := 0         # picks the copy; 0 = from position

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _copy: Array = []
var _tint := Color.WHITE
var _birds: Array = []             # vultures: {r, speed, phase, wing}
var _weed_x := 0.0                 # tumbleweed: offset along its crossing
var _weed_dir := 1.0
var _smoke: CPUParticles2D = null

func _ready() -> void:
	_rng.seed = copy_seed if copy_seed != 0 else int(absf(position.x * 7.0 + position.y * 13.0)) + 99
	match kind:
		&"sign":
			_copy = SIGN_COPY[_rng.randi() % SIGN_COPY.size()]
		&"billboard":
			_copy = BILLBOARD_COPY[_rng.randi() % BILLBOARD_COPY.size()]
			_tint = BOARD_TINTS[_rng.randi() % BOARD_TINTS.size()]
		&"vultures":
			z_index = 3
			for i in _rng.randi_range(2, 4):
				_birds.append({"r": _rng.randf_range(50.0, 130.0), "speed": _rng.randf_range(0.35, 0.7) * (1.0 if _rng.randf() < 0.5 else -1.0),
					"phase": _rng.randf_range(0.0, TAU), "wing": _rng.randf_range(4.0, 7.0)})
		&"wreck_fire":
			z_index = 1
			_smoke = CPUParticles2D.new()
			_smoke.amount = 26
			_smoke.lifetime = 2.6
			_smoke.local_coords = false
			_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			_smoke.emission_sphere_radius = 10.0
			_smoke.direction = Vector2(0.3, -1.0)
			_smoke.spread = 25.0
			_smoke.gravity = Vector2(20.0, -30.0)
			_smoke.initial_velocity_min = 18.0
			_smoke.initial_velocity_max = 40.0
			_smoke.scale_amount_min = 6.0
			_smoke.scale_amount_max = 14.0
			_smoke.color = Color(SMOKE, 0.5)
			var ramp := Gradient.new()
			ramp.set_color(0, Color(SMOKE, 0.0))
			ramp.add_point(0.2, Color(SMOKE, 0.55))
			ramp.set_color(ramp.get_point_count() - 1, Color(SMOKE, 0.0))
			_smoke.color_ramp = ramp
			_smoke.preprocess = 2.0
			add_child(_smoke)
		&"tumbleweed":
			_weed_dir = 1.0 if _rng.randf() < 0.5 else -1.0
			_weed_x = _rng.randf_range(-300.0, 300.0)
	set_process(kind in [&"vultures", &"wreck_fire", &"tumbleweed"])
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if kind == &"tumbleweed":
		_weed_x += _weed_dir * TUMBLE_SPEED * delta
		if absf(_weed_x) > TUMBLE_REACH:
			_weed_dir = -_weed_dir
	queue_redraw()

const TUMBLE_SPEED := 42.0   # px/s: a dry ball on a light wind, slow enough to see
const TUMBLE_REACH := 420.0  # px each way from the post: across the road and back

func _draw() -> void:
	match kind:
		&"sign":
			_draw_sign()
		&"billboard":
			_draw_billboard()
		&"vultures":
			_draw_vultures()
		&"wreck_fire":
			_draw_fire()
		&"tumbleweed":
			_draw_tumbleweed()

## A post at the origin, the board hanging over the verge toward the road.
## Big, like a highway sign: the camera sits at 0.55, so anything under 22
## world px of type is a smudge.
func _draw_sign() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-4, -8, 8, 16), POST)
	draw_circle(Vector2(0, 8), 7.0, Color(0.12, 0.1, 0.08, 0.5))   # the post's shadow
	var w := 210.0
	var h := 70.0
	var board := Rect2(-w * 0.5 - side * 6.0, -12.0 - h, w, h)
	draw_rect(board.grow(3.0), Color(0.05, 0.05, 0.06, 0.6))
	draw_rect(board, SIGN_GREEN)
	draw_rect(board.grow(-5.0), SIGN_TEXT.darkened(0.2), false, 2.0)
	if _copy.size() >= 1:
		draw_string(font, Vector2(board.position.x + 14.0, board.position.y + 32.0), String(_copy[0]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 24, SIGN_TEXT)
	if _copy.size() >= 2 and String(_copy[1]) != "":
		draw_string(font, Vector2(board.position.x + 14.0, board.position.y + 58.0), String(_copy[1]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 19, SIGN_TEXT.darkened(0.15))

## Two posts and a big board — the copy is the joke, the board is the read.
func _draw_billboard() -> void:
	var font := ThemeDB.fallback_font
	var w := 340.0
	var h := 130.0
	for px in [-w * 0.4, w * 0.4]:
		draw_rect(Rect2(px - 4.0, -12, 8, 24), POST)
		draw_circle(Vector2(px, 12), 7.0, Color(0.12, 0.1, 0.08, 0.5))
	var board := Rect2(-w * 0.5, -18.0 - h, w, h)
	draw_rect(board.grow(4.0), Color(0.05, 0.05, 0.06, 0.65))
	draw_rect(board, _tint)
	draw_rect(board.grow(-8.0), _tint.darkened(0.55), false, 3.0)
	var ink := _tint.darkened(0.7)
	if _copy.size() >= 1:
		draw_string(font, Vector2(board.position.x + 20.0, board.position.y + 46.0), String(_copy[0]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 34, ink)
	if _copy.size() >= 2 and String(_copy[1]) != "":
		draw_string(font, Vector2(board.position.x + 20.0, board.position.y + 82.0), String(_copy[1]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 28, ink)
	if _copy.size() >= 3:
		draw_string(font, Vector2(board.position.x + 20.0, board.position.y + 112.0), String(_copy[2]),
			HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 15, ink.lightened(0.2))
	# The mounting: a strip of bulbs along the top that some vandal has mostly finished off.
	for i in 11:
		var on: bool = (i * 7 + int(absf(position.x))) % 3 != 0
		draw_circle(Vector2(board.position.x + 20.0 + float(i) * (w - 40.0) / 10.0, board.position.y - 6.0), 3.0,
			Color(1.0, 0.95, 0.75) if on else Color(0.2, 0.2, 0.22))

## Buzzards on a thermal: shallow Vs wheeling on their own circles, wings
## rocking; they never come down.
func _draw_vultures() -> void:
	for b in _birds:
		var a: float = _t * float(b["speed"]) + float(b["phase"])
		var at := Vector2(cos(a), sin(a) * 0.55) * float(b["r"])
		var heading := a + (PI * 0.5 if float(b["speed"]) > 0.0 else -PI * 0.5)
		var wing: float = float(b["wing"])
		var flap: float = 0.5 + 0.5 * sin(_t * 1.7 + float(b["phase"]) * 3.0)
		var tip := Vector2(wing * 2.2, 0.0)
		var dip := Vector2(0.0, wing * 0.9 * flap)
		var l := at + (tip * -1.0 + dip).rotated(heading)
		var r := at + (tip + dip).rotated(heading)
		var shade := Color(0.08, 0.07, 0.06, 0.85)
		draw_line(l, at, shade, 2.2)
		draw_line(at, r, shade, 2.2)
		draw_line(at + Vector2(0, -2).rotated(heading), at + Vector2(0, 3).rotated(heading), shade, 2.5)
		# Its shadow on the road, well off to the side of the sun.
		var sh := at + Vector2(70.0, 90.0)
		draw_line(sh + (tip * -1.0 + dip).rotated(heading) - at + at, sh, Color(0, 0, 0, 0.18), 2.0)
		draw_line(sh, sh + (tip + dip).rotated(heading), Color(0, 0, 0, 0.18), 2.0)

## Flame over a wreck: three licks rocking on different clocks, the smoke
## rides the particles.
func _draw_fire() -> void:
	for i in 3:
		var k := float(i)
		var sway := sin(_t * (5.0 + k * 1.7) + k) * 4.0
		var reach := 18.0 + 8.0 * sin(_t * (7.0 + k * 2.3) + k * 2.0)
		var base := Vector2(-8.0 + k * 8.0, 0.0)
		var lick := PackedVector2Array([
			base + Vector2(-6, 2), base + Vector2(6, 2), base + Vector2(2 + sway, -reach), base + Vector2(-2 + sway * 0.6, -reach * 0.7),
		])
		draw_colored_polygon(lick, FLAME[i % FLAME.size()])
	draw_circle(Vector2(0, 2), 12.0, Color(1.0, 0.6, 0.2, 0.18))

## A dry ball rolling across the road on the wind: a ragged disc, spinning.
func _draw_tumbleweed() -> void:
	var at := Vector2(_weed_x, 0.0)
	var spin := _weed_x * 0.06
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0 + spin
		var r := 11.0 + 4.0 * sin(a * 3.0 + 1.0) + 2.0 * sin(a * 5.0)
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0.55, 0.45, 0.25, 0.85))
	for i in 5:
		var a := TAU * float(i) / 5.0 + spin * 1.3
		draw_line(at, at + Vector2(cos(a), sin(a)) * 13.0, Color(0.35, 0.28, 0.16), 1.5)
	draw_circle(at + Vector2(4, 6), 12.0, Color(0, 0, 0, 0.15))
