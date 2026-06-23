extends Area2D

@export var speed := 1200.0
@export var lifetime := 1.5

var direction: Vector2 = Vector2.UP

func _ready():
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_physics_process(true)

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		return

	_apply_bullet_damage(body)
	queue_free()

func _on_area_entered(area):
	if area.is_in_group("player"):
		return

	_apply_bullet_damage(area)
	queue_free()

func _apply_bullet_damage(target):
	# Use DAMAGE_PROFILE from PlayerCar for machine gun damage
	var machine_gun_damage = 8  # PlayerCar.DAMAGE_PROFILE.MACHINE_GUN

	if target.has_method("apply_damage"):
		print("Bullet hit target: %s for %d damage" % [target.name, machine_gun_damage])
		if target.is_in_group("vehicles"):
			target.apply_damage(machine_gun_damage, self)
		else:
			target.apply_damage(machine_gun_damage)
	else:
		print("Bullet hit non-damageable target: %s" % target.name)

func set_direction(new_direction: Vector2) -> void:
	if new_direction.length_squared() > 0.0:
		direction = new_direction.normalized()
