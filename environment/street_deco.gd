extends Node2D
## Street dressing: the living-city + atmosphere props. Pure paint/FX —
## NOTHING here collides (poles sit at curb corners out of traffic, and AI
## feelers never have to know). Kinds:
##   traffic_light — 3-lamp head cycling green/amber/red (desynced per corner)
##   neon          — storefront board, seeded color, occasional flicker-off
##   street_light  — pole + soft warm glow pool on the asphalt
##   manhole       — cover paint + perpetual steam wisps
##   snowfall      — arena-wide drifting flakes (Snowy Pass)

const GREEN_T := 4.0
const AMBER_T := 1.2
const RED_T := 4.0
const LAMP := {0: Color(0.3, 0.9, 0.35), 1: Color(1.0, 0.75, 0.2), 2: Color(1.0, 0.25, 0.2)}
const NEON_COLORS := [Color(1, 0.3, 0.55), Color(0.3, 0.9, 1), Color(0.55, 1, 0.4), Color(1, 0.65, 0.2)]

@export var kind: StringName = &"street_light"
@export var extents := Vector2(1700, 1700)  # snowfall emission half-size
@export var snow_amount := 240

var _t := 0.0
var _phase := 0        # traffic light: 0 green, 1 amber, 2 red
var _neon_on := true
var _neon_next := 3.0  # seconds until the next flicker
var _neon_color := Color.WHITE
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = int(absf(position.x * 7.0 + position.y * 13.0))
	match kind:
		&"traffic_light":
			_phase = _rng.randi() % 3  # corners out of sync, like real cities
			_t = _rng.randf_range(0.0, 2.0)
		&"neon":
			_neon_color = NEON_COLORS[_rng.randi() % NEON_COLORS.size()]
			_neon_next = _rng.randf_range(1.5, 4.0)
		&"manhole":
			_steam()
		&"snowfall":
			_snow()
	set_process(kind == &"traffic_light" or kind == &"neon")
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if kind == &"traffic_light":
		var dur: float = [GREEN_T, AMBER_T, RED_T][_phase]
		if _t >= dur:
			_t = 0.0
			_phase = (_phase + 1) % 3
			queue_redraw()
	elif kind == &"neon":
		if _neon_on and _t >= _neon_next:
			_neon_on = false
			_t = 0.0
			queue_redraw()
		elif not _neon_on and _t >= _rng.randf_range(0.06, 0.18):
			_neon_on = true
			_t = 0.0
			_neon_next = _rng.randf_range(1.5, 4.0)
			queue_redraw()

func _draw() -> void:
	match kind:
		&"traffic_light":
			_draw_traffic_light()
		&"neon":
			_draw_neon()
		&"street_light":
			_draw_street_light()
		&"manhole":
			_draw_manhole()

func _draw_traffic_light() -> void:
	draw_rect(Rect2(-2, 10, 4, 12), Color(0.2, 0.2, 0.24))       # pole foot
	draw_rect(Rect2(-6, -14, 12, 26), Color(0.12, 0.12, 0.15))   # head box
	for i in 3:
		var at := Vector2(0, -8 + i * 8)
		var lit := i == _phase
		draw_circle(at, 3.0, (LAMP[i] as Color) if lit else (LAMP[i] as Color).darkened(0.72))
		if lit:
			draw_circle(at, 5.5, Color((LAMP[i] as Color), 0.25))  # glow halo

func _draw_neon() -> void:
	var board := Rect2(-22, -8, 44, 16)
	draw_rect(board, Color(0.08, 0.08, 0.1))
	if _neon_on:
		draw_rect(board.grow(-3), _neon_color)
		draw_rect(board, Color(_neon_color, 0.35), false, 3.0)    # glow rim
	else:
		draw_rect(board.grow(-3), _neon_color.darkened(0.8))

func _draw_street_light() -> void:
	draw_circle(Vector2.ZERO, 58.0, Color(1.0, 0.9, 0.6, 0.07))  # outer pool
	draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.92, 0.68, 0.09))
	draw_circle(Vector2(0, 0), 4.0, Color(0.2, 0.2, 0.24))       # pole base
	draw_rect(Rect2(-1.5, -14, 3, 14), Color(0.25, 0.25, 0.3))   # mast
	draw_circle(Vector2(0, -14), 3.0, Color(1.0, 0.92, 0.6))     # lamp head

func _draw_manhole() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(0.15, 0.15, 0.17))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(0.25, 0.25, 0.28), 1.5)
	draw_circle(Vector2(-3, 0), 1.2, Color(0.05, 0.05, 0.06))    # pick holes
	draw_circle(Vector2(3, 0), 1.2, Color(0.05, 0.05, 0.06))

func _steam() -> void:
	var steam := CPUParticles2D.new()
	steam.amount = 7
	steam.lifetime = 2.2
	steam.local_coords = false
	steam.direction = Vector2(0, -1)
	steam.spread = 16.0
	steam.initial_velocity_min = 18.0
	steam.initial_velocity_max = 34.0
	steam.gravity = Vector2(6, -14)   # drifts up and slightly sideways
	steam.scale_amount_min = 3.0
	steam.scale_amount_max = 6.0
	steam.color = Color(0.85, 0.87, 0.9, 0.14)
	steam.preprocess = 2.0
	add_child(steam)

func _snow() -> void:
	var snow := CPUParticles2D.new()
	snow.amount = snow_amount
	snow.lifetime = 7.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = extents
	snow.direction = Vector2(0.25, 1)
	snow.spread = 20.0
	snow.initial_velocity_min = 30.0
	snow.initial_velocity_max = 70.0
	snow.gravity = Vector2(8, 22)
	snow.scale_amount_min = 1.2
	snow.scale_amount_max = 2.4
	snow.color = Color(0.95, 0.97, 1.0, 0.75)
	snow.preprocess = 7.0  # the storm is already falling when you arrive
	add_child(snow)
