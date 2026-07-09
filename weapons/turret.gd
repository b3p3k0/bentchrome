extends Node2D
## The living breach turret: an auto-aiming mount that tracks the PLAYER
## independently of the hull it rides — it sets its own global_rotation, so
## the parent Visual's 16-step heading quantization never staircases the
## barrel — and fires straight power-class shots on its own cooldown.
## Autonomous by design: it keeps firing through the driver's break-off
## breathers (a fighting retreat, not a ceasefire); aim lag (TRAVERSE) keeps
## it dodgeable by hard orbiting. Configured from a WeaponDef like any mount.
## Duck-typed only — NEVER names Vehicle (projectile-cluster hygiene).

const CarPaintScript := preload("res://vehicles/car_paint.gd")  # FLEET_SCALE only
const Floors := preload("res://game/floors.gd")

const RANGE := 1100.0
const TRAVERSE := deg_to_rad(120.0)  # barrel slew per second — the dodge window
const AIM_CONE := 0.12               # fire when the barrel is this close (rad)
const LOS_MASK := 2 | 4              # walls + cover deny the shot
const MUZZLE_OUT := 36.0             # barrel tip, in global px (28 local × fleet)
const STEEL := Color(0.16, 0.16, 0.18)
const STEEL_DARK := Color(0.1, 0.1, 0.12)

var _def: WeaponDef = null
var _cooldown := 0.0

func set_weapon(def: WeaponDef) -> void:
	_def = def
	queue_redraw()

func _ready() -> void:
	# Sibling of the CarPaint node, which self-scales — match it.
	scale = Vector2.ONE * CarPaintScript.FLEET_SCALE
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _def == null:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
	var target := get_tree().get_first_node_in_group(&"player") as Node2D
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > RANGE:
		return
	var want := (target.global_position - global_position).angle()
	var diff := wrapf(want - global_rotation, -PI, PI)
	var step := TRAVERSE * delta
	global_rotation += clampf(diff, -step, step)
	if absf(diff) > AIM_CONE or _cooldown > 0.0:
		return
	if not _los_clear(target):
		return
	_fire()

func _vehicle() -> Node:
	return get_parent().get_parent() if get_parent() else null  # Visual -> car body

func _los_clear(target: Node2D) -> bool:
	var body := _vehicle() as CollisionObject2D
	if body == null or not (target is CollisionObject2D):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, LOS_MASK)
	query.exclude = [body.get_rid(), (target as CollisionObject2D).get_rid()]
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _fire() -> void:
	var scene := get_tree().current_scene
	if scene == null or _def.projectile_scene == null:
		return  # headless fixtures may not set one — same guard as the mount
	_cooldown = _def.cooldown
	var dir := Vector2.RIGHT.rotated(global_rotation)
	var p := _def.projectile_scene.instantiate() as Projectile
	p.modulate = _def.projectile_tint
	p.hit_sfx = &"hit_weapon"
	var shooter := _vehicle()
	var shooter_floor := Floors.floor_of(shooter)
	if shooter_floor >= 1:
		p.collision_mask = Floors.projectile_mask(shooter_floor, false)
	scene.add_child(p)
	p.setup(global_position + dir * MUZZLE_OUT, dir, _def.projectile_speed,
		_def.damage, _def.projectile_lifetime, shooter, 0.0, null)

func _draw() -> void:
	# The barrel that used to be static hull paint — now it turns to face you.
	draw_circle(Vector2.ZERO, 6.0, STEEL_DARK)          # rotating cupola
	draw_rect(Rect2(2.0, -1.5, 24.0, 3.0), STEEL)       # breach cannon
	draw_rect(Rect2(24.0, -2.5, 4.0, 5.0), STEEL_DARK)  # muzzle brake
	draw_circle(Vector2(-1.0, 0.0), 2.5, STEEL)         # breech dome
