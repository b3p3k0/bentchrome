class_name WeaponMount
extends Node
## Fires projectiles at a fixed rate in a given direction. The machine gun uses
## one of these (low chip damage); specials reuse it with different data later.

@export var fire_rate := 12.0          # shots per second
@export var damage := 2.0              # chip damage — MG takes many hits to kill
@export var projectile_speed := 1100.0
@export var projectile_scene: PackedScene

var _cooldown := 0.0

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func try_fire(origin: Vector2, direction: Vector2, shooter: Node) -> void:
	if _cooldown > 0.0 or projectile_scene == null:
		return
	_cooldown = 1.0 / fire_rate
	var p := projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(p)
	p.setup(origin, direction, projectile_speed, damage, shooter)
