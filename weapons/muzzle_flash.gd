extends Node2D
## One breath of light at the muzzle: a star quad + hot core that lives ~4
## frames and fades. Pooled through the Spawner like projectiles (pool_reset
## + release), because the MG asks for twelve of these a second per shooter.
## Duck-typed only — never names Vehicle.

const LIFE := 0.07

var _age := 0.0

func setup(pos: Vector2, dir: Vector2, big: bool) -> void:
	global_position = pos
	rotation = dir.angle()
	scale = Vector2.ONE * (1.7 if big else 1.0)
	_age = 0.0
	modulate = Color.WHITE
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	modulate.a = clampf(1.0 - _age / LIFE, 0.0, 1.0)
	if _age >= LIFE:
		_despawn()

func _draw() -> void:
	# Four-point star along the barrel + a hot core.
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, 0), Vector2(4, 3.5), Vector2(-3, 0), Vector2(4, -3.5),
	]), Color(1.0, 0.85, 0.4, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 7), Vector2(2, 2), Vector2(6, -7), Vector2(9, 0),
	]), Color(1.0, 0.7, 0.3, 0.6))
	draw_circle(Vector2(3, 0), 3.2, Color(1.0, 0.95, 0.75))

func _despawn() -> void:
	var spawner := get_node_or_null(^"/root/Spawner")
	if spawner and spawner.has_method(&"release"):
		spawner.release(self)
	else:
		queue_free()

func pool_reset() -> void:
	_age = 0.0
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
