class_name Projectile
extends Area2D
## A straight-line projectile. Damages the first Health-bearing body it hits —
## anyone except its own shooter. This is a free-for-all: there are no teams,
## so the only immunity is to your own fire. Despawns on hit, wall, or lifetime.

@export var lifetime := 1.2

var velocity := Vector2.ZERO
var damage := 2.0
var shooter: Node = null
var _age := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(p_pos: Vector2, p_dir: Vector2, p_speed: float, p_damage: float, p_shooter: Node) -> void:
	global_position = p_pos
	rotation = p_dir.angle()
	velocity = p_dir * p_speed
	damage = p_damage
	shooter = p_shooter

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	var health := _find_health(body)
	if health:
		health.take_damage(damage)
	queue_free()

func _find_health(body: Node) -> Health:
	for child in body.get_children():
		if child is Health:
			return child
	return null
