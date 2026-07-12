class_name RepairBayFX
extends Node2D
## Procedural repair-bay lightning: four layered, low-frequency crackling bolts
## converge on the medical cross. Persistent station child; no spawn churn.

const CORNERS := [
	Vector2(-36, -36), Vector2(36, -36),
	Vector2(36, 36), Vector2(-36, 36),
]
const FLICKER_HZ := 12.0
const FLICKER_INTERVAL := 1.0 / FLICKER_HZ
const COMPLETION_SECONDS := 0.18
const GLOW_WIDTH := 5.0
const CORE_WIDTH := 2.0
const GLOW_COLOR := Color(0.18, 0.55, 1.0, 0.58)
const CORE_COLOR := Color(0.88, 0.96, 1.0, 0.96)

var _active := false
var _finishing := false
var _elapsed := 0.0
var _flicker_t := 0.0
var _finish_t := 0.0
var _frame := 0
var _paths: Array[PackedVector2Array] = []

func _ready() -> void:
	z_index = 6
	set_process(false)

func start() -> void:
	_active = true
	_finishing = false
	_elapsed = 0.0
	_flicker_t = 0.0
	_finish_t = 0.0
	_frame = 0
	_rebuild_paths()
	set_process(true)
	queue_redraw()

func finish(with_flash := true) -> void:
	if not _active and not _finishing:
		return
	_active = false
	_finishing = with_flash
	_finish_t = 0.0
	if not with_flash:
		_paths.clear()
		set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if _active:
		_elapsed += delta
		_flicker_t += delta
		while _flicker_t >= FLICKER_INTERVAL:
			_flicker_t -= FLICKER_INTERVAL
			_frame += 1
			_rebuild_paths()
		queue_redraw()
	elif _finishing:
		_finish_t += delta
		if _finish_t >= COMPLETION_SECONDS:
			_finishing = false
			_paths.clear()
			set_process(false)
		queue_redraw()

func _rebuild_paths() -> void:
	_paths.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB017 + _frame * 7919
	for corner_v in CORNERS:
		var corner: Vector2 = corner_v
		var points := PackedVector2Array()
		var tangent: Vector2 = -corner.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		for i in 7:
			var f := float(i) / 6.0
			var point: Vector2 = corner.lerp(Vector2.ZERO, f)
			if i > 0 and i < 6:
				point += normal * rng.randf_range(-6.0, 6.0) * sin(f * PI)
			points.append(point)
		_paths.append(points)

func _draw() -> void:
	if not _active and not _finishing:
		return
	var collapse := 0.0
	var alpha := 1.0
	if _finishing:
		collapse = clampf(_finish_t / COMPLETION_SECONDS, 0.0, 1.0)
		alpha = 1.0 - collapse
	for source in _paths:
		var points := source
		if collapse > 0.0:
			points = PackedVector2Array()
			for point in source:
				points.append(point.lerp(Vector2.ZERO, collapse))
		draw_polyline(points, Color(GLOW_COLOR, GLOW_COLOR.a * alpha), GLOW_WIDTH, true)
		draw_polyline(points, Color(CORE_COLOR, CORE_COLOR.a * alpha), CORE_WIDTH, true)
	if _active:
		var pulse := 0.72 + sin(_elapsed * TAU * 3.0) * 0.16
		draw_rect(Rect2(-5, -17, 10, 34), Color(1.0, 0.2, 0.25, pulse), true)
		draw_rect(Rect2(-17, -5, 34, 10), Color(1.0, 0.2, 0.25, pulse), true)
	else:
		var radius := lerpf(5.0, 34.0, collapse)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, alpha * 0.8), false, 3.0, true)
		draw_circle(Vector2.ZERO, maxf(1.0, 8.0 * (1.0 - collapse)),
			Color(1.0, 1.0, 1.0, alpha), true)

func is_effect_active() -> bool:
	return _active

func is_finishing() -> bool:
	return _finishing

func bolt_paths() -> Array[PackedVector2Array]:
	return _paths.duplicate(true)
