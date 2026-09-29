extends Control
## The robbery roulette: ten painted wedges under a fixed pointer. The
## landing is decided BEFORE the spin (game/robbery.gd rolls it and settles
## the bill); this only performs it — a few fast turns easing down onto the
## pre-rolled wedge, a tick for every wedge that passes the pointer, then
## `landed`. Pure presentation: faces come from Robbery.describe().
## PROCESS_MODE is inherited from the robbery screen (always) — the tree is
## frozen while the wheel turns.

signal landed(index: int)

const Robbery := preload("res://game/robbery.gd")

const RADIUS := 150.0
const HUB := 26.0
const RIM := Color(0.07, 0.07, 0.09)
const SPIN_TURNS := 4          # full turns before the wheel settles
const SPIN_SECONDS := 3.2
const ARC_STEPS := 10          # polygon points per wedge arc

var wheel: Array = []          # Robbery slices, wedge order
var target_index := -1
var spin_angle := 0.0:         # radians the wheel has turned (tweened)
	set(v):
		spin_angle = v
		_tick_check()
		queue_redraw()

var _spinning := false
var _done := false
var _last_wedge := -1
var _tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0 + 24.0, RADIUS * 2.0 + 40.0)

func setup(slices: Array, land_on: int) -> void:
	wheel = slices
	target_index = land_on
	queue_redraw()

func is_spinning() -> bool:
	return _spinning

## The wheel angle that parks wedge `index` dead under the pointer (12
## o'clock), after `turns` full rotations.
static func landing_angle(index: int, count: int, turns: int) -> float:
	if count <= 0:
		return 0.0
	var arc := TAU / float(count)
	return float(turns) * TAU - (float(index) + 0.5) * arc

## Which wedge sits under the pointer at a given wheel angle.
static func wedge_under_pointer(angle: float, count: int) -> int:
	if count <= 0:
		return -1
	var arc := TAU / float(count)
	return int(floor(fposmod(-angle, TAU) / arc)) % count

func spin() -> void:
	if _spinning or _done or wheel.is_empty() or target_index < 0:
		return
	_spinning = true
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "spin_angle",
		landing_angle(target_index, wheel.size(), SPIN_TURNS), SPIN_SECONDS) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_land, CONNECT_ONE_SHOT)

## Skip to the result (an impatient key, or a test).
func finish_now() -> void:
	if _done or wheel.is_empty() or target_index < 0:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	spin_angle = landing_angle(target_index, wheel.size(), SPIN_TURNS)
	_land()

func _land() -> void:
	if _done:
		return
	_done = true
	_spinning = false
	queue_redraw()
	landed.emit(target_index)

func _tick_check() -> void:
	if wheel.is_empty():
		return
	var under := wedge_under_pointer(spin_angle, wheel.size())
	if under != _last_wedge:
		var first := _last_wedge < 0
		_last_wedge = under
		if _spinning and not first:
			var audio := get_node_or_null(^"/root/AudioDirector")
			if audio:
				audio.play(&"ui_move")

func _draw() -> void:
	var center := Vector2(size.x * 0.5, 30.0 + RADIUS)
	draw_circle(center, RADIUS + 8.0, RIM)
	var count := wheel.size()
	if count == 0:
		return
	var arc := TAU / float(count)
	var font := ThemeDB.fallback_font
	for i in count:
		var face: Dictionary = Robbery.describe(wheel[i])
		var a0 := -PI * 0.5 + spin_angle + arc * float(i)
		var tone: Color = face["color"]
		if _done and i != target_index:
			tone = tone.darkened(0.6)
		var pts := PackedVector2Array([center])
		for s in ARC_STEPS + 1:
			pts.append(center + Vector2.RIGHT.rotated(a0 + arc * float(s) / float(ARC_STEPS)) * RADIUS)
		draw_colored_polygon(pts, tone)
		draw_line(center, center + Vector2.RIGHT.rotated(a0) * RADIUS, RIM, 3.0)
		# Label along the wedge's spoke, reading outward.
		var mid := a0 + arc * 0.5
		var label := String(face["label"])
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_set_transform(center + Vector2.RIGHT.rotated(mid) * (RADIUS - 12.0 - width), mid, Vector2.ONE)
		draw_string(font, Vector2(0.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.05, 0.05, 0.06) if not (_done and i != target_index) else Color(0.3, 0.3, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center, HUB, RIM)
	draw_circle(center, HUB - 6.0, Color(0.75, 0.2, 0.2))
	# The pointer: fixed at 12 o'clock, biting into the rim.
	var tip := center + Vector2(0.0, -RADIUS + 14.0)
	draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-13.0, -34.0), tip + Vector2(13.0, -34.0),
	]), Color(1.0, 0.85, 0.2))
	draw_polyline(PackedVector2Array([
		tip, tip + Vector2(-13.0, -34.0), tip + Vector2(13.0, -34.0), tip,
	]), RIM, 2.0)
