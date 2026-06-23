class_name WeaponMount
extends Node
## Fires projectiles at a fixed rate. Straight by default; set turn_rate_deg +
## acquisition_radius and it locks the nearest other vehicle so the projectile
## homes. The machine gun and every secondary weapon are the same mount with
## different numbers — a vehicle's "special" is just one of these too.

@export var fire_rate := 12.0          # shots per second
@export var damage := 2.0
@export var projectile_speed := 1100.0
@export var projectile_lifetime := 1.2
@export var turn_rate_deg := 0.0       # >0 = homing
@export var acquisition_radius := 0.0  # lock range for homing
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
	var tgt: Node2D = null
	if turn_rate_deg > 0.0 and acquisition_radius > 0.0:
		tgt = _acquire(origin, shooter)
	p.setup(origin, direction, projectile_speed, damage, projectile_lifetime, shooter, deg_to_rad(turn_rate_deg), tgt)

func _acquire(origin: Vector2, shooter: Node) -> Node2D:
	var best: Node2D = null
	var best_dist := acquisition_radius
	for v in get_tree().get_nodes_in_group(&"vehicles"):
		if v == shooter:
			continue
		var d: float = origin.distance_to(v.global_position)
		if d < best_dist:
			best_dist = d
			best = v
	return best
