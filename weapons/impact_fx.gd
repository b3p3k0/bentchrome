class_name ImpactFX
extends Node2D
## Tiny pooled, gameplay-free impact punctuation. Geometry is generated from
## the style and a position seed so sustained fire stays readable and clients
## render the same visual language without synchronizing particle state.

const LIFE := 0.24
const NONE := 0
const SPARK := 1
const MISSILE := 2
const SPATTER := 3

var style := NONE
var _age := 0.0
var _seed := 0

func setup(at: Vector2, impact_style: int) -> void:
	global_position = at
	style = impact_style
	_age = 0.0
	_seed = int(absf(at.x * 17.0 + at.y * 31.0))
	visible = style != NONE
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		_despawn()
	else:
		queue_redraw()

func _draw() -> void:
	if style == NONE:
		return
	var t := clampf(_age / LIFE, 0.0, 1.0)
	var fade := 1.0 - t
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + style * 7919
	match style:
		SPARK:
			for i in 4 + rng.randi_range(0, 2):
				var dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
				var reach := rng.randf_range(5.0, 13.0) * (0.35 + t)
				draw_line(dir * reach * 0.35, dir * reach,
					Color(1.0, 0.92, 0.58, fade * 0.55), 1.2)
		MISSILE:
			draw_circle(Vector2.ZERO, 5.0 * fade, Color(1.0, 0.78, 0.3, fade * 0.7))
			draw_arc(Vector2.ZERO, lerpf(4.0, 18.0, t), 0.0, TAU, 18,
				Color(1.0, 0.58, 0.18, fade * 0.7), 2.0 * fade)
			for i in 3:
				var dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
				draw_line(dir * 5.0, dir * lerpf(7.0, 14.0, t),
					Color(0.8, 0.55, 0.3, fade * 0.45), 1.0)
		SPATTER:
			for i in 3:
				var dir := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
				var at := dir * rng.randf_range(3.0, 9.0) * (0.5 + t)
				draw_circle(at, rng.randf_range(1.0, 1.8) * fade,
					Color(0.72, 0.03, 0.04, fade * 0.7))

func _despawn() -> void:
	var spawner := get_node_or_null(^"/root/Spawner")
	if spawner and spawner.has_method(&"release"):
		spawner.release(self)
	else:
		queue_free()

func pool_reset() -> void:
	style = NONE
	_age = 0.0
	_seed = 0
	visible = false
	queue_redraw()
