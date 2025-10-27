extends Area2D

@export var max_hits: int = 3
@export var collision_damage_override: Variant = null
var current_hits: int

func _ready():
	add_to_group("destructible")
	current_hits = max_hits
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func apply_damage(amount: int = 1) -> bool:
	if amount <= 0 or current_hits <= 0:
		return false

	current_hits -= amount
	if current_hits <= 0:
		print("DestructibleProp destroyed: ", name)
		queue_free()
		return true
	return false

func apply_collision_damage(amount: int = 1) -> bool:
	var damage = collision_damage_override if collision_damage_override != null else amount
	return apply_damage(damage)

func _on_body_entered(body):
	if body.is_in_group("destructible"):
		return
	apply_collision_damage()

func _on_area_entered(area):
	if area.is_in_group("destructible"):
		return
	apply_collision_damage()