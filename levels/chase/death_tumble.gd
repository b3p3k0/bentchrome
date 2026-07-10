extends Node2D
## A wrecked Buzzard's last second: a dark hull silhouette that spins off with
## the victim's momentum, sheds speed hard, and fades — spawned by the
## director when a bird dies (the Vehicle's own death path stays untouched;
## arenas never see this). Frees itself.

const LIFE := 0.8

var velocity := Vector2.ZERO
var spin := 6.0
var _hull := Vector2(30.0, 16.0)
var _color := Color(0.12, 0.1, 0.09)
var _life := LIFE

func setup(pos: Vector2, vel: Vector2, hull: Vector2, tint: Color) -> void:
	global_position = pos
	velocity = vel
	_hull = hull
	_color = Color(tint.r * 0.35, tint.g * 0.32, tint.b * 0.3)
	spin = (6.0 if randf() < 0.5 else -6.0) * randf_range(0.7, 1.3)
	rotation = vel.angle()
	queue_redraw()

func _process(delta: float) -> void:
	global_position += velocity * delta
	velocity *= pow(0.04, delta)   # hard decel — a slide, not a glide
	rotation += spin * delta
	_life -= delta
	modulate.a = clampf(_life / LIFE, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-_hull, _hull * 2.0), _color)
	draw_rect(Rect2(Vector2(-_hull.x * 0.4, -_hull.y * 0.7),
		Vector2(_hull.x * 0.8, _hull.y * 1.4)), _color.darkened(0.3))
