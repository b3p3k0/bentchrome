extends Area2D

@export var max_hits: int = 3
@export var collision_damage_override: Variant = null
@export var blocker_collision_layer: int = 1
@export var blocker_collision_mask: int = 0

var current_hits: int
var blocker: StaticBody2D
var blocker_shape: CollisionShape2D

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready():
	add_to_group("destructible")
	current_hits = max_hits
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_ensure_blocker()

func _ensure_blocker():
	if has_node("Blocker"):
		blocker = get_node("Blocker")
	else:
		blocker = StaticBody2D.new()
		blocker.name = "Blocker"
		blocker.collision_layer = blocker_collision_layer
		blocker.collision_mask = blocker_collision_mask
		add_child(blocker, false, Node.INTERNAL_MODE_BACK)

	blocker_shape = blocker.get_node_or_null("CollisionShape2D")
	if blocker_shape == null:
		blocker_shape = CollisionShape2D.new()
		blocker_shape.name = "CollisionShape2D"
		blocker.add_child(blocker_shape)

	if collision_shape and blocker_shape:
		blocker_shape.shape = collision_shape.shape
		blocker_shape.position = collision_shape.position
		blocker_shape.rotation = collision_shape.rotation
		blocker_shape.disabled = false

func apply_damage(amount: int = 1) -> bool:
	if amount <= 0 or current_hits <= 0:
		return false

	current_hits -= amount
	if current_hits <= 0:
		_destroy()
		return true
	return false

func apply_collision_damage(amount: int = 1) -> bool:
	var damage = collision_damage_override if collision_damage_override != null else amount
	return apply_damage(damage)

func _destroy():
	if blocker_shape:
		blocker_shape.set_deferred("disabled", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("destructible"):
		return
	apply_collision_damage()

func _on_area_entered(area):
	if area.is_in_group("destructible"):
		return
	apply_collision_damage()
